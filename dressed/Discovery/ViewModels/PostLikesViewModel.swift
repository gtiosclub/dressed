import Combine
import Foundation

extension DiscoveryPostSource {
    static var currentPostLikes: any PostLikeFunctions {
        if isDemo { return DemoPostLikeFunctions() }
        return FirebasePostLikeFunctions()
    }
}

@MainActor
final class PostLikesViewModel: ObservableObject {
    struct State: Equatable {
        var isLiked = false
        var likeCount = 0
        var isLoaded = false
        var isPending = false
        var isRemoved = false
        var errorMessage: String?
    }

    @Published private(set) var states: [String: State] = [:]
    private let ownerId: String
    private let service: any PostLikeFunctions
    private var generation = 0

    init(ownerId: String, service: any PostLikeFunctions) {
        self.ownerId = ownerId
        self.service = service
    }

    func state(for post: Post) -> State {
        states[post.id] ?? State(likeCount: max(post.likeCount ?? 0, 0))
    }

    func loadIfNeeded(post: Post) async {
        guard states[post.id]?.isLoaded != true,
              states[post.id]?.isPending != true,
              states[post.id]?.isRemoved != true else { return }
        let requestGeneration = generation
        var state = state(for: post)
        state.isPending = true
        state.errorMessage = nil
        states[post.id] = state
        do {
            let snapshot = try await service.fetch(
                postId: post.id, ownerId: ownerId, knownCount: max(post.likeCount ?? 0, 0)
            )
            guard generation == requestGeneration else { return }
            states[post.id] = State(
                isLiked: snapshot.isLiked, likeCount: snapshot.likeCount, isLoaded: true
            )
        } catch PostLikeFunctionsError.postRemoved {
            guard generation == requestGeneration else { return }
            state.isPending = false
            state.isLoaded = false
            state.isRemoved = true
            state.errorMessage = PostLikeFunctionsError.postRemoved.localizedDescription
            states[post.id] = state
        } catch {
            guard generation == requestGeneration else { return }
            if error is CancellationError || Task.isCancelled {
                if !state.isLoaded {
                    states.removeValue(forKey: post.id)
                } else {
                    state.isPending = false
                    states[post.id] = state
                }
                return
            }
            state.isPending = false
            state.errorMessage = "Couldn't load like. Pull to refresh."
            states[post.id] = state
        }
    }

    func toggle(post: Post) {
        let confirmed = state(for: post)
        guard confirmed.isLoaded, !confirmed.isPending, !confirmed.isRemoved else { return }
        let requestGeneration = generation
        let desiredState = !confirmed.isLiked
        var pending = confirmed
        pending.isPending = true
        pending.errorMessage = nil
        states[post.id] = pending
        Task {
            do {
                let snapshot = try await service.set(
                    postId: post.id, ownerId: ownerId, isLiked: desiredState
                )
                guard generation == requestGeneration else { return }
                states[post.id] = State(
                    isLiked: snapshot.isLiked, likeCount: snapshot.likeCount, isLoaded: true
                )
            } catch PostLikeFunctionsError.postRemoved {
                guard generation == requestGeneration else { return }
                var removed = confirmed
                removed.isRemoved = true
                removed.isLoaded = false
                removed.isPending = false
                removed.errorMessage = PostLikeFunctionsError.postRemoved.localizedDescription
                states[post.id] = removed
            } catch {
                guard generation == requestGeneration else { return }
                var failed = confirmed
                failed.isPending = false
                failed.errorMessage = error.localizedDescription
                states[post.id] = failed
            }
        }
    }

    func retry(post: Post) {
        let current = state(for: post)
        guard !current.isRemoved, !current.isPending else { return }
        if !current.isLoaded {
            Task { await loadIfNeeded(post: post) }
        } else if current.errorMessage != nil {
            toggle(post: post)
        }
    }

    func reset() {
        generation += 1
        states = [:]
    }
}

final class DemoPostLikeFunctions: PostLikeFunctions {
    private let defaults: UserDefaults
    private let delay: Duration

    init(defaults: UserDefaults = .standard, delay: Duration = .milliseconds(200)) {
        self.defaults = defaults
        self.delay = delay
    }

    func fetch(postId: String, ownerId: String, knownCount: Int) async throws -> PostLikeSnapshot {
        if delay > .zero {
            try await Task.sleep(for: delay)
        }
        let liked = defaults.bool(forKey: key(ownerId: ownerId, postId: postId))
        let countStorageKey = countKey(postId: postId)
        let count: Int
        if defaults.object(forKey: countStorageKey) == nil {
            count = max(knownCount, 0) + (liked ? 1 : 0)
            defaults.set(count, forKey: countStorageKey)
        } else {
            count = max(defaults.integer(forKey: countStorageKey), 0)
        }
        return PostLikeSnapshot(postId: postId, isLiked: liked, likeCount: count)
    }

    func set(postId: String, ownerId: String, isLiked: Bool) async throws -> PostLikeSnapshot {
        if delay > .zero {
            try await Task.sleep(for: delay)
        }
        let storageKey = key(ownerId: ownerId, postId: postId)
        let wasLiked = defaults.bool(forKey: storageKey)
        defaults.set(isLiked, forKey: storageKey)
        let countStorageKey = countKey(postId: postId)
        let currentCount = defaults.integer(forKey: countStorageKey)
        let nextCount = max(0, currentCount + (isLiked == wasLiked ? 0 : (isLiked ? 1 : -1)))
        defaults.set(nextCount, forKey: countStorageKey)
        return PostLikeSnapshot(postId: postId, isLiked: isLiked, likeCount: nextCount)
    }

    private func key(ownerId: String, postId: String) -> String {
        "demoPostLike.\(ownerId).\(postId)"
    }

    private func countKey(postId: String) -> String {
        "demoPostLikeCount.\(postId)"
    }
}
