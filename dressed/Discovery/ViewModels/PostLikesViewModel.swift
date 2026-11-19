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
    struct State {
        var isLiked = false
        var likeCount = 0
        var isLoaded = false
        var isPending = false
        var errorMessage: String?
    }

    @Published private(set) var states: [String: State] = [:]
    private let ownerId: String
    private let service: any PostLikeFunctions

    init(ownerId: String, service: any PostLikeFunctions) {
        self.ownerId = ownerId
        self.service = service
    }

    func state(for post: Post) -> State {
        states[post.id] ?? State(likeCount: max(post.likeCount ?? 0, 0))
    }

    func loadIfNeeded(post: Post) async {
        guard states[post.id]?.isLoaded != true, states[post.id]?.isPending != true else { return }
        var state = state(for: post)
        state.isPending = true
        states[post.id] = state
        do {
            let snapshot = try await service.fetch(
                postId: post.id, ownerId: ownerId, knownCount: max(post.likeCount ?? 0, 0)
            )
            states[post.id] = State(
                isLiked: snapshot.isLiked, likeCount: snapshot.likeCount, isLoaded: true
            )
        } catch {
            state.isPending = false
            state.errorMessage = "Couldn't load like. Pull to refresh."
            states[post.id] = state
        }
    }

    func toggle(post: Post) {
        let confirmed = state(for: post)
        guard confirmed.isLoaded, !confirmed.isPending else { return }
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
                states[post.id] = State(
                    isLiked: snapshot.isLiked, likeCount: snapshot.likeCount, isLoaded: true
                )
            } catch {
                var failed = confirmed
                failed.errorMessage = error.localizedDescription
                states[post.id] = failed
            }
        }
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
        try await Task.sleep(for: delay)
        let liked = defaults.bool(forKey: key(ownerId: ownerId, postId: postId))
        return PostLikeSnapshot(postId: postId, isLiked: liked, likeCount: knownCount + (liked ? 1 : 0))
    }

    func set(postId: String, ownerId: String, isLiked: Bool) async throws -> PostLikeSnapshot {
        try await Task.sleep(for: delay)
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
