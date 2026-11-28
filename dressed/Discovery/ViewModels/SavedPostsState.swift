import Foundation

// SOCIAL-P03 (#186): what the save toggle (#149) and the Saved grid (#124) show for one user.
// The saved IDs are the source of truth, so the toggle and the grid always agree, and a saved post
// that can't be found stays listed as unavailable instead of disappearing or getting a fake card.
// Foundation-only so dressedStateChecks can test it without building the app.

/// One entry in the Saved grid.
enum SavedGridEntry: Identifiable {
    /// A saved post that was found.
    case available(Post)
    /// A saved ID with no post, because the post was deleted or hidden. It can still be unsaved.
    case unavailable(postId: String)

    var id: String {
        switch self {
        case .available(let post): post.id
        case .unavailable(let postId): postId
        }
    }
}

/// A save or unsave for the parent to perform.
struct SavedPostWrite: Equatable {
    let requestId = UUID()
    let postId: String
    let save: Bool
}

/// Issued when a refresh starts, so a result that arrives late can still be applied safely.
struct SavedPostsRefresh {
    fileprivate let sequence: Int
    fileprivate let confirmedWritesAtStart: Int
}

/// Saved-post state for one signed-in user. A write changes it only after the write succeeds,
/// matching SavePostToggle's working state.
struct SavedPostsState {
    /// Confirmed saved IDs, unique and sorted, so a refresh never reorders the grid.
    private(set) var savedIds: [String] = []
    /// False until the first refresh succeeds; until then the parent shows loading or an error.
    private(set) var hasLoaded = false
    private(set) var refreshFailed = false
    private(set) var failedWrite: SavedPostWrite?
    private var postsById: [String: Post] = [:]
    private var pending: [String: SavedPostWrite] = [:]
    /// Writes confirmed since the oldest refresh that can still be applied, numbered in order.
    private var confirmedWrites: [(number: Int, write: SavedPostWrite)] = []
    private var confirmedWriteCount = 0
    private var refreshesStarted = 0
    private var lastAppliedRefresh = 0

    // MARK: - Toggle and grid inputs

    func isSaved(_ postId: String) -> Bool {
        savedIds.contains(postId)
    }

    func isWorking(_ postId: String) -> Bool {
        pending[postId] != nil
    }

    var gridEntries: [SavedGridEntry] {
        savedIds.map { postId in
            postsById[postId].map { .available($0) } ?? .unavailable(postId: postId)
        }
    }

    // MARK: - Writes

    /// Handles one toggle report and returns the write to perform. Returns nil when nothing should
    /// be sent: a write for this post is in flight, or the post is already in the requested state.
    /// Pass the post on screen so that a confirmed save shows its card before the next refresh.
    mutating func toggleReported(postId: String, save: Bool, post: Post? = nil) -> SavedPostWrite? {
        guard pending[postId] == nil, save != isSaved(postId) else { return nil }
        if let post, post.id == postId {
            postsById[postId] = post
        }
        let write = SavedPostWrite(postId: postId, save: save)
        pending[postId] = write
        failedWrite = nil
        return write
    }

    /// Applies the result of a write this state issued. Results for any other write are ignored.
    mutating func writeFinished(_ write: SavedPostWrite, succeeded: Bool) {
        guard pending[write.postId] == write else { return }
        pending[write.postId] = nil
        guard succeeded else {
            failedWrite = write
            return
        }
        apply(write)
        confirmedWriteCount += 1
        confirmedWrites.append((confirmedWriteCount, write))
    }

    // MARK: - Refresh

    /// Call when the parent starts reading saved IDs and looking up their posts.
    mutating func refreshStarted() -> SavedPostsRefresh {
        refreshesStarted += 1
        refreshFailed = false
        return SavedPostsRefresh(sequence: refreshesStarted, confirmedWritesAtStart: confirmedWriteCount)
    }

    /// Applies a completed read: the saved IDs and the posts found for them. Writes confirmed after
    /// the read started are replayed on top of it. A result older than the last applied refresh is
    /// ignored and returns false.
    @discardableResult
    mutating func refreshFinished(
        _ refresh: SavedPostsRefresh, savedIds newIds: [String], posts newPosts: [Post]
    ) -> Bool {
        guard refresh.sequence > lastAppliedRefresh else { return false }
        lastAppliedRefresh = refresh.sequence
        savedIds = Array(Set(newIds)).sorted()

        let lateWrites = confirmedWrites.filter { $0.number > refresh.confirmedWritesAtStart }.map(\.write)
        lateWrites.forEach { apply($0) }
        confirmedWrites.removeAll { $0.number <= refresh.confirmedWritesAtStart }

        var found: [String: Post] = [:]
        for post in newPosts where found[post.id] == nil {
            found[post.id] = post
        }
        // Keep posts this lookup could not include yet: saves confirmed during it or still in flight.
        for write in lateWrites + pending.values where write.save && found[write.postId] == nil {
            found[write.postId] = postsById[write.postId]
        }
        postsById = found

        hasLoaded = true
        refreshFailed = false
        failedWrite = nil
        return true
    }

    /// A failed read keeps what the user already sees instead of showing an empty list.
    mutating func refreshDidFail(_ refresh: SavedPostsRefresh) {
        guard refresh.sequence > lastAppliedRefresh else { return }
        refreshFailed = true
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
