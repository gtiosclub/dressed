import Foundation

// Fixtures and a stand-in for the screen, used by CheckSavedPostsState.swift. Outside the iOS app target.

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

    /// Whether a card shows one of the fixture posts, unchanged.
    static func isSupplied(_ post: Post) -> Bool {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let encoded = try? encoder.encode(post)
        return all.contains { (try? encoder.encode($0)) == encoded }
    }
}

struct FixtureReadFailure: Error {}

/// How the fixture store answers the next write.
enum FixtureWriteResult {
    case succeeds
    case rejected
    /// The store applies the write but the app sees a failure, like a reply lost on the network.
    case appliedButReportedFailed
}

/// Stands in for Firestore: saved documents at users/{ownerId}/savedPosts/{postId} and public posts.
final class FixtureStore {
    private var savedDocuments: [String: Set<String>] = [:]
    private var posts: [String: Post] = [:]
    var nextWriteResult = FixtureWriteResult.succeeds
    var nextReadFails = false

    init() {
        for post in Fixtures.all {
            posts[post.id] = post
        }
    }

    /// Returns whether the app sees the write succeed.
    @discardableResult
    func perform(_ write: SavedPostWrite, ownerId: String) -> Bool {
        let result = nextWriteResult
        nextWriteResult = .succeeds
        if result == .rejected { return false }
        if write.save {
            savedDocuments[ownerId, default: []].insert(write.postId)
        } else {
            savedDocuments[ownerId]?.remove(write.postId)
        }
        return result == .succeeds
    }

    func fetchSavedIds(ownerId: String) throws -> [String] {
        if nextReadFails {
            nextReadFails = false
            throw FixtureReadFailure()
        }
        return documentIds(ownerId: ownerId)
    }

    func lookUpPosts(ids: [String]) -> [Post] {
        ids.compactMap { posts[$0] }
    }

    func documentIds(ownerId: String) -> [String] {
        (savedDocuments[ownerId] ?? []).sorted()
    }

    func deletePost(_ postId: String) {
        posts[postId] = nil
    }
}

/// Plays the screen for one signed-in user and checks the rules after every step.
final class Parent {
    struct Read {
        let refresh: SavedPostsRefresh
        let result: (ids: [String], posts: [Post])?
    }

    let ownerId: String
    let store: FixtureStore
    private(set) var state = SavedPostsState()
    private(set) var writesSent: [SavedPostWrite] = []
    private(set) var problems: [String] = []

    init(ownerId: String = "user_a", store: FixtureStore = FixtureStore()) {
        self.ownerId = ownerId
        self.store = store
    }

    var gridIds: [String] { state.gridEntries.map(\.id) }

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
    func tap(_ postId: String, showing post: Post? = nil) -> SavedPostWrite? {
        guard !state.isWorking(postId) else { return nil }
        return report(postId, save: !state.isSaved(postId), showing: post)
    }

    /// Performs a write on the fixture store and hands the result to the state.
    func finish(_ write: SavedPostWrite?, _ result: FixtureWriteResult = .succeeds) {
        guard let write else {
            problems.append("a write was expected but none was sent")
            return
        }
        store.nextWriteResult = result
        deliver(write, succeeded: store.perform(write, ownerId: ownerId))
    }

    /// Hands a write result to the state without performing it, such as a result that arrives late.
    func deliver(_ write: SavedPostWrite, succeeded: Bool) {
        state.writeFinished(write, succeeded: succeeded)
        checkRules(after: "\(write.save ? "save" : "unsave") \(write.postId) finished")
    }

    func save(_ post: Post) {
        finish(tap(post.id, showing: post))
    }

    /// Reads now; apply(_:) hands the result to the state later. Passing posts or IDs replaces the
    /// lookup or the read, as a parent that merges overlapping pages would.
    func startRefresh(supplying posts: [Post]? = nil, ids suppliedIds: [String]? = nil) -> Read {
        let refresh = state.refreshStarted()
        guard let ids = suppliedIds ?? (try? store.fetchSavedIds(ownerId: ownerId)) else {
            return Read(refresh: refresh, result: nil)
        }
        return Read(refresh: refresh, result: (ids, posts ?? store.lookUpPosts(ids: ids)))
    }

    @discardableResult
    func apply(_ read: Read) -> Bool {
        defer { checkRules(after: "refresh") }
        guard let result = read.result else {
            state.refreshDidFail(read.refresh)
            return false
        }
        return state.refreshFinished(read.refresh, savedIds: result.ids, posts: result.posts)
    }

    func refresh(supplying posts: [Post]? = nil, ids suppliedIds: [String]? = nil) {
        apply(startRefresh(supplying: posts, ids: suppliedIds))
    }

    /// The app closes and reopens: everything held in memory is gone.
    func relaunch() {
        state = SavedPostsState()
    }

    func expect(_ condition: Bool, _ message: String) {
        if !condition { problems.append(message) }
    }

    /// The toggle and the grid agree for every post, no post has two entries, and every card shows
    /// a post that was supplied.
    private func checkRules(after step: String) {
        let entries = state.gridEntries
        var counts: [String: Int] = [:]
        for entry in entries {
            counts[entry.id, default: 0] += 1
        }
        for (postId, count) in counts.sorted(by: { $0.key < $1.key }) where count > 1 {
            problems.append("after \(step): \(postId) has \(count) grid entries")
        }
        let postIds = Set(counts.keys).union(state.savedIds).union(Fixtures.all.map(\.id))
        for postId in postIds.sorted() where state.isSaved(postId) != (counts[postId] != nil) {
            problems.append("after \(step): the toggle and the grid disagree about \(postId)")
        }
        for case .available(let post) in entries where !Fixtures.isSupplied(post) {
            problems.append("after \(step): the \(post.id) card is not a supplied post")
        }
    }
}
