import Combine
import Foundation

extension DiscoveryPostSource {
    static var currentSavedPosts: any SavedPostFunctions {
        if isDemo { return DemoSavedPostFunctions() }
        return FirebaseSavedPostFunctions()
    }
}

/// Saved posts for one signed-in user, shared by the OOTD feed and the Saved screen. AppTabs creates
/// one per user, so signing out discards it, and a late write result can only reach its own instance.
@MainActor
final class SavedPostsViewModel: ObservableObject {
    @Published private(set) var state = SavedPostsState()
    private let ownerId: String
    private let saves: any SavedPostFunctions
    private let posts: any PostFunctions

    init(ownerId: String, saves: any SavedPostFunctions, posts: any PostFunctions) {
        self.ownerId = ownerId
        self.saves = saves
        self.posts = posts
    }

    /// True until saved posts first load or fail to load.
    var isLoading: Bool {
        !state.hasLoaded && !state.refreshFailed
    }

    func isSaved(_ postId: String) -> Bool {
        state.isSaved(postId)
    }

    /// A toggle also waits while saved posts first load, so it never shows Save for a saved post.
    func isWorking(_ postId: String) -> Bool {
        isLoading || state.isWorking(postId)
    }

    func errorMessage(for postId: String) -> String? {
        guard let write = state.failedWrite, write.postId == postId else { return nil }
        return write.save ? "Couldn't save. Try again." : "Couldn't remove. Try again."
    }

    /// Handles a toggle report. The post on screen lets a confirmed save show its card right away.
    func toggle(postId: String, save: Bool, post: Post? = nil) {
        guard !isLoading, let write = state.toggleReported(postId: postId, save: save, post: post) else {
            return
        }
        Task {
            do {
                if write.save {
                    try await saves.save(postId: postId, ownerId: ownerId)
                } else {
                    try await saves.remove(postId: postId, ownerId: ownerId)
                }
                state.writeFinished(write, succeeded: true)
            } catch {
                state.writeFinished(write, succeeded: false)
            }
        }
    }

    func loadIfNeeded() async {
        guard !state.hasLoaded else { return }
        await refresh()
    }

    /// Reloads from the server. The read runs in its own task so that leaving the screen, which
    /// cancels the caller, can't drop a result the feed also relies on.
    func refresh() async {
        let refresh = state.refreshStarted()
        await Task {
            do {
                let ids = try await saves.fetchSavedIds(ownerId: ownerId)
                let found = try await posts.fetchPosts(ids: ids)
                state.refreshFinished(refresh, savedIds: ids, posts: found)
            } catch {
                state.refreshDidFail(refresh)
            }
        }.value
    }
}

/// Synthetic saved posts for the signed-in simulator walkthrough. They stay in UserDefaults, so they
/// survive a relaunch, and never reach Firestore. Debug launch arguments:
/// `-resetSavedPosts` starts empty; `-seedSavedPosts` starts with two posts and one removed post;
/// `-failSavedPostReads 1,2` fails those numbered reads; `-failNextSavedPostWrite` fails one write.
final class DemoSavedPostFunctions: SavedPostFunctions {
    private let defaults: UserDefaults
    private var startingIds: [String]?
    private var failingReads: Set<Int> = []
    private var readCount = 0
    private var failNextWrite: Bool

    init(defaults: UserDefaults = .standard, arguments: [String] = ProcessInfo.processInfo.arguments) {
        self.defaults = defaults
        if arguments.contains("-seedSavedPosts") {
            startingIds = ["demo_post_1", "demo_post_2", "demo_post_removed"]
        } else if arguments.contains("-resetSavedPosts") {
            startingIds = []
        }
        if let marker = arguments.firstIndex(of: "-failSavedPostReads"), arguments.indices.contains(marker + 1) {
            failingReads = Set(arguments[marker + 1].split(separator: ",").compactMap { Int($0) })
        }
        failNextWrite = arguments.contains("-failNextSavedPostWrite")
    }

    func fetchSavedIds(ownerId: String) async throws -> [String] {
        try await Task.sleep(for: .milliseconds(250))
        readCount += 1
        if failingReads.contains(readCount) { throw DemoSavedPostError.simulatedFailure }
        return savedIds(ownerId: ownerId)
    }

    func save(postId: String, ownerId: String) async throws {
        try await finishWrite()
        store(Array(Set(savedIds(ownerId: ownerId) + [postId])), ownerId: ownerId)
    }

    func remove(postId: String, ownerId: String) async throws {
        try await finishWrite()
        store(savedIds(ownerId: ownerId).filter { $0 != postId }, ownerId: ownerId)
    }

    private func finishWrite() async throws {
        try await Task.sleep(for: .milliseconds(250))
        if failNextWrite {
            failNextWrite = false
            throw DemoSavedPostError.simulatedFailure
        }
    }

    private func savedIds(ownerId: String) -> [String] {
        if let startingIds {
            store(startingIds, ownerId: ownerId)
            self.startingIds = nil
        }
        return defaults.stringArray(forKey: key(ownerId: ownerId)) ?? []
    }

    private func store(_ ids: [String], ownerId: String) {
        defaults.set(ids, forKey: key(ownerId: ownerId))
    }

    private func key(ownerId: String) -> String {
        "demoSavedPosts.\(ownerId)"
    }
}

private enum DemoSavedPostError: Error {
    case simulatedFailure
}
