import Foundation

// SOCIAL-P03 (#186) proposal prototype. Not part of the app; see ../SOCIAL-P03-saved-post-behavior.md.
// SavedPostsState holds what the save toggle (#149) and the Saved grid (#124) show for one user.
// SavedPostsFixtureStore stands in for Firestore with in-memory saved relations and public posts.

/// One entry in the Saved grid.
enum SavedGridEntry {
    /// A saved post that the parent supplied.
    case available(Post)
    /// A saved ID with no supplied post, because the post was deleted or hidden. It is shown as a
    /// removed-content entry with an Unsave action, never as a post card.
    case unavailable(postId: String)

    var postId: String {
        switch self {
        case .available(let post): post.id
        case .unavailable(let postId): postId
        }
    }
}

/// The two ways of combining saved IDs with supplied public posts that the proposal compares.
enum SavedGridStrategy: CaseIterable {
    /// Keeps the supplied posts whose IDs are saved, using filterSavedPosts (#148).
    case postsFirst
    /// Builds one entry per saved ID and fills it with the supplied post when there is one.
    case idsFirst

    func entries(savedIds: [String], posts: [Post]) -> [SavedGridEntry] {
        switch self {
        case .postsFirst:
            return filterSavedPosts(posts, savedPostIds: Set(savedIds)).map { .available($0) }
        case .idsFirst:
            var postsById: [String: Post] = [:]
            for post in posts where postsById[post.id] == nil {
                postsById[post.id] = post
            }
            return savedIds.map { postId in
                postsById[postId].map { .available($0) } ?? .unavailable(postId: postId)
            }
        }
    }
}

/// A save or unsave that the parent performs with savePost or removeSavedPost.
struct SavedPostWrite: Equatable {
    let requestId = UUID()
    let postId: String
    let save: Bool
}

/// The most recent failure, for the parent's error message.
enum SavedPostsFailure: Equatable {
    case write(SavedPostWrite)
    case refresh
}

/// Issued when a refresh starts, so a result that arrives late can still be applied safely.
struct SavedPostsRefresh {
    fileprivate let sequence: Int
    fileprivate let confirmedWritesAtStart: Int
}

/// Client state for one signed-in user. The toggle and the grid both read the same saved IDs.
/// A write changes them only after it succeeds, matching SavePostToggle's working state (#149).
struct SavedPostsState {
    let strategy: SavedGridStrategy
    /// Confirmed saved IDs, unique and sorted like fetchSavedPostIds results, so a refresh never
    /// reorders the grid.
    private(set) var savedIds: [String] = []
    /// False until the first refresh succeeds; until then the parent shows loading or an error.
    private(set) var hasLoaded = false
    private(set) var lastFailure: SavedPostsFailure?
    /// Public posts the parent supplied: lookup results for saved IDs and posts shown with a save tap.
    private var posts: [Post] = []
    private var pending: [String: SavedPostWrite] = [:]
    /// Writes confirmed since the oldest refresh that can still be applied, numbered in order.
    private var confirmedWrites: [(number: Int, write: SavedPostWrite)] = []
    private var confirmedWriteCount = 0
    private var refreshesStarted = 0
    private var lastAppliedRefresh = 0

    init(strategy: SavedGridStrategy) {
        self.strategy = strategy
    }

    // MARK: - Toggle and grid inputs

    func isSaved(_ postId: String) -> Bool {
        savedIds.contains(postId)
    }

    func isWorking(_ postId: String) -> Bool {
        pending[postId] != nil
    }

    var gridEntries: [SavedGridEntry] {
        strategy.entries(savedIds: savedIds, posts: posts)
    }

    // MARK: - Writes

    /// Handles one toggle report and returns the write to perform. Returns nil when nothing should
    /// be sent: a write for this post is in flight, or the post is already in the requested state.
    /// Pass the post being shown so that a confirmed save appears in the grid before the next refresh.
    mutating func toggleReported(postId: String, save: Bool, post: Post? = nil) -> SavedPostWrite? {
        guard pending[postId] == nil, save != isSaved(postId) else { return nil }
        if let post, post.id == postId, !posts.contains(where: { $0.id == postId }) {
            posts.append(post)
        }
        let write = SavedPostWrite(postId: postId, save: save)
        pending[postId] = write
        return write
    }

    /// Applies the result of a write this state issued. Results for any other write, such as one
    /// issued before a sign-out or relaunch, are ignored.
    mutating func writeFinished(_ write: SavedPostWrite, succeeded: Bool) {
        guard pending[write.postId] == write else { return }
        pending[write.postId] = nil
        guard succeeded else {
            lastFailure = .write(write)
            return
        }
        lastFailure = nil
        apply(write)
        confirmedWriteCount += 1
        confirmedWrites.append((confirmedWriteCount, write))
    }

    // MARK: - Refresh

    /// Call when the parent starts reading saved IDs and looking up their posts.
    mutating func refreshStarted() -> SavedPostsRefresh {
        refreshesStarted += 1
        return SavedPostsRefresh(sequence: refreshesStarted, confirmedWritesAtStart: confirmedWriteCount)
    }

    /// Applies a completed read: fetchSavedPostIds results and the posts found for those IDs.
    /// Writes confirmed after the read started are replayed on top of it. A result older than the
    /// last applied refresh is ignored and returns false.
    @discardableResult
    mutating func refreshFinished(
        _ refresh: SavedPostsRefresh, savedIds newIds: [String], posts newPosts: [Post]
    ) -> Bool {
        guard refresh.sequence > lastAppliedRefresh else { return false }
        lastAppliedRefresh = refresh.sequence
        let previousPosts = posts
        savedIds = Array(Set(newIds)).sorted()
        posts = newPosts

        let lateWrites = confirmedWrites.filter { $0.number > refresh.confirmedWritesAtStart }.map(\.write)
        lateWrites.forEach { apply($0) }
        confirmedWrites.removeAll { $0.number <= refresh.confirmedWritesAtStart }

        // Keep posts this lookup could not include yet: saves confirmed during it or still in flight.
        let keptIds = Set((lateWrites + pending.values).filter(\.save).map(\.postId))
        for post in previousPosts where keptIds.contains(post.id) && !posts.contains(where: { $0.id == post.id }) {
            posts.append(post)
        }
        hasLoaded = true
        lastFailure = nil
        return true
    }

    /// A failed read keeps what the user already sees instead of showing an empty list.
    mutating func refreshFailed(_ refresh: SavedPostsRefresh) {
        guard refresh.sequence > lastAppliedRefresh else { return }
        lastFailure = .refresh
    }

    private mutating func apply(_ write: SavedPostWrite) {
        if write.save {
            if !savedIds.contains(write.postId) {
                savedIds.append(write.postId)
                savedIds.sort()
            }
        } else {
            savedIds.removeAll { $0 == write.postId }
        }
    }
}

// MARK: - In-memory fixture store

/// How the fixture store answers the next write.
enum FixtureWriteResult {
    case succeeds
    case rejected
    /// The store applies the write but the app sees a failure, like a reply lost on the network.
    case appliedButReportedFailed
}

struct FixtureReadFailure: Error {}

/// In-memory stand-in for Firestore. Saved relations live at users/{ownerId}/savedPosts/{postId},
/// where savePost and removeSavedPost write them. It does not model access rules; those are #94.
final class SavedPostsFixtureStore {
    private var savedPosts: [String: [String: SavedPost]] = [:]
    private var posts: [String: Post] = [:]
    /// How the next write is answered. It resets to .succeeds after each write.
    var nextWriteResult = FixtureWriteResult.succeeds
    /// Makes the next fetchSavedPostIds call fail.
    var nextReadFails = false

    init(posts: [Post]) {
        for post in posts {
            self.posts[post.id] = post
        }
    }

    /// Mirrors savePost (setData at the post's document ID) and removeSavedPost (delete). Returns
    /// whether the app sees the write succeed.
    @discardableResult
    func perform(_ write: SavedPostWrite, ownerId: String, at date: Date) -> Bool {
        let result = nextWriteResult
        nextWriteResult = .succeeds
        if result == .rejected { return false }
        if write.save {
            savedPosts[ownerId, default: [:]][write.postId] = SavedPost(
                id: write.postId, schemaVersion: 1, ownerId: ownerId, postId: write.postId, createdAt: date)
        } else {
            savedPosts[ownerId]?[write.postId] = nil
        }
        return result == .succeeds
    }

    /// Mirrors fetchSavedPostIds: the owner's saved post IDs in document-ID order.
    func fetchSavedPostIds(ownerId: String) throws -> [String] {
        if nextReadFails {
            nextReadFails = false
            throw FixtureReadFailure()
        }
        return documentIds(ownerId: ownerId)
    }

    /// Looks up public posts by ID. Only posts that still exist come back, in document-ID order.
    func lookUpPosts(ids: [String]) -> [Post] {
        ids.compactMap { posts[$0] }.sorted { $0.id < $1.id }
    }

    /// The owner's saved document IDs, for checks.
    func documentIds(ownerId: String) -> [String] {
        (savedPosts[ownerId] ?? [:]).keys.sorted()
    }

    /// The author deletes a public post. Saved relations that point at it remain, as in Firestore.
    func deletePost(_ postId: String) {
        posts[postId] = nil
    }
}
