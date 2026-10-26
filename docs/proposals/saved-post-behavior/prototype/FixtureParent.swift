import Foundation

// SOCIAL-P03 (#186): fixtures and a stand-in for the parent view model, used by CheckSavedPosts.swift.
// Not part of the app; see ../SOCIAL-P03-saved-post-behavior.md.

enum Fixtures {
    static let date = Date(timeIntervalSince1970: 1_790_000_000)
    static let post001 = post("post_001", caption: "Monday outfit")
    static let post002 = post("post_002", caption: "Rainy day layers")
    static let post003 = post("post_003", caption: "Weekend fit")
    static let all = [post001, post002, post003]

    static func post(_ postId: String, caption: String) -> Post {
        Post(id: postId, schemaVersion: 1, authorId: "user_b", caption: caption,
             outfitSnapshot: PublishedOutfitSnapshot(name: caption, items: []),
             mediaPath: "posts/user_b/\(postId)/composite.jpg", createdAt: date)
    }

    /// Whether a card shows one of the supplied fixture posts, unchanged.
    static func isSupplied(_ post: Post) -> Bool {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let encoded = try? encoder.encode(post)
        return all.contains { (try? encoder.encode($0)) == encoded }
    }
}

/// Plays the parent view model for one signed-in user. It turns toggle taps into writes, refreshes
/// from the fixture store, and checks the proposal's rules after every step.
final class FixtureParent {
    struct Read {
        let refresh: SavedPostsRefresh
        let result: (ids: [String], posts: [Post])?
    }

    let ownerId: String
    let store: SavedPostsFixtureStore
    private(set) var state: SavedPostsState
    private(set) var writesSent: [SavedPostWrite] = []
    private(set) var problems: [String] = []

    init(ownerId: String, store: SavedPostsFixtureStore, strategy: SavedGridStrategy) {
        self.ownerId = ownerId
        self.store = store
        state = SavedPostsState(strategy: strategy)
    }

    var gridIds: [String] { state.gridEntries.map(\.postId) }

    var availableIds: [String] {
        state.gridEntries.compactMap { entry -> String? in
            guard case .available(let post) = entry else { return nil }
            return post.id
        }
    }

    var unavailableIds: [String] {
        state.gridEntries.compactMap { entry -> String? in
            guard case .unavailable(let postId) = entry else { return nil }
            return postId
        }
    }

    /// Reports a post ID and desired state, as SavePostToggle does.
    @discardableResult
    func report(_ postId: String, save: Bool, showing post: Post? = nil) -> SavedPostWrite? {
        let write = state.toggleReported(postId: postId, save: save, post: post)
        if let write { writesSent.append(write) }
        checkRules(after: "report \(postId)")
        return write
    }

    /// A tap on a toggle: it reports the opposite of isSaved, and nothing while working.
    @discardableResult
    func tapToggle(_ postId: String, showing post: Post? = nil) -> SavedPostWrite? {
        guard !state.isWorking(postId) else { return nil }
        return report(postId, save: !state.isSaved(postId), showing: post)
    }

    /// A tap on the toggle inside the post's Saved-grid entry.
    func tapGridEntry(_ postId: String) -> SavedPostWrite? {
        guard gridIds.contains(postId) else {
            problems.append("the Saved grid has no entry for \(postId), so it cannot be unsaved there")
            return nil
        }
        return tapToggle(postId)
    }

    /// Performs a write on the fixture store and hands the result to the state.
    func finish(_ write: SavedPostWrite?, _ result: FixtureWriteResult = .succeeds) {
        guard let write else {
            problems.append("a write was expected but none was sent")
            return
        }
        store.nextWriteResult = result
        deliver(write, succeeded: store.perform(write, ownerId: ownerId, at: Fixtures.date))
    }

    /// Hands a write result to the state without performing it, such as a result that arrives late.
    func deliver(_ write: SavedPostWrite, succeeded: Bool) {
        state.writeFinished(write, succeeded: succeeded)
        checkRules(after: "\(write.save ? "save" : "unsave") \(write.postId) finished")
    }

    func save(_ post: Post) {
        finish(tapToggle(post.id, showing: post))
    }

    /// Reads saved IDs and looks up their posts now; apply(_:) hands the result to the state later.
    /// Passing posts replaces the lookup, as a parent that supplies feed pages would; passing IDs
    /// replaces the read, as a parent that merges pages of saved IDs would.
    func startRefresh(supplying posts: [Post]? = nil, ids suppliedIds: [String]? = nil) -> Read {
        let refresh = state.refreshStarted()
        guard let ids = suppliedIds ?? (try? store.fetchSavedPostIds(ownerId: ownerId)) else {
            return Read(refresh: refresh, result: nil)
        }
        return Read(refresh: refresh, result: (ids, posts ?? store.lookUpPosts(ids: ids)))
    }

    @discardableResult
    func apply(_ read: Read) -> Bool {
        defer { checkRules(after: "refresh") }
        guard let result = read.result else {
            state.refreshFailed(read.refresh)
            return false
        }
        return state.refreshFinished(read.refresh, savedIds: result.ids, posts: result.posts)
    }

    func refresh(supplying posts: [Post]? = nil, ids suppliedIds: [String]? = nil) {
        apply(startRefresh(supplying: posts, ids: suppliedIds))
    }

    /// The app closes and reopens: everything held in memory is gone.
    func relaunch() {
        state = SavedPostsState(strategy: state.strategy)
    }

    func expect(_ condition: Bool, _ message: String) {
        if !condition { problems.append(message) }
    }

    /// The toggle and the grid agree for every post, no post has two entries, and every card shows
    /// a post the parent supplied.
    private func checkRules(after step: String) {
        let entries = state.gridEntries
        var entryCounts: [String: Int] = [:]
        for entry in entries {
            entryCounts[entry.postId, default: 0] += 1
        }
        for (postId, count) in entryCounts.sorted(by: { $0.key < $1.key }) where count > 1 {
            problems.append("after \(step): \(postId) has \(count) grid entries")
        }
        let postIds = Set(entryCounts.keys).union(state.savedIds).union(Fixtures.all.map(\.id))
        for postId in postIds.sorted() where state.isSaved(postId) != (entryCounts[postId] != nil) {
            let toggle = state.isSaved(postId) ? "Saved" : "Save"
            let grid = entryCounts[postId] == nil ? "has no entry for it" : "shows it"
            problems.append("after \(step): \(postId) toggle shows \(toggle) but the grid \(grid)")
        }
        for case .available(let post) in entries where !Fixtures.isSupplied(post) {
            problems.append("after \(step): the \(post.id) card is not a post the parent supplied")
        }
    }
}

func parentForUserA(_ strategy: SavedGridStrategy) -> FixtureParent {
    FixtureParent(ownerId: "user_a", store: SavedPostsFixtureStore(posts: Fixtures.all), strategy: strategy)
}
