import XCTest
@testable import dressed

@MainActor
final class SocialFeedAuditFixesTests: XCTestCase {
    private enum StubError: LocalizedError {
        case network

        var errorDescription: String? {
            "Network unavailable."
        }
    }

    private final class MockPostLikeService: PostLikeFunctions {
        var fetchResults: [Result<PostLikeSnapshot, Error>] = []
        var setResults: [Result<PostLikeSnapshot, Error>] = []
        private(set) var fetchCount = 0
        private(set) var setCount = 0
        private(set) var lastSetDesiredState: Bool?

        func fetch(postId: String, ownerId: String, knownCount: Int) async throws -> PostLikeSnapshot {
            fetchCount += 1
            if !fetchResults.isEmpty {
                return try fetchResults.removeFirst().get()
            }
            return PostLikeSnapshot(postId: postId, isLiked: false, likeCount: knownCount)
        }

        func set(postId: String, ownerId: String, isLiked: Bool) async throws -> PostLikeSnapshot {
            setCount += 1
            lastSetDesiredState = isLiked
            if !setResults.isEmpty {
                return try setResults.removeFirst().get()
            }
            return PostLikeSnapshot(postId: postId, isLiked: isLiked, likeCount: isLiked ? 1 : 0)
        }
    }

    private func makePost(
        id: String,
        createdAt: Date = Date(timeIntervalSince1970: 1_700_000_000),
        likeCount: Int? = 5
    ) -> Post {
        Post(
            id: id,
            schemaVersion: 1,
            authorId: "author_\(id)",
            caption: "Caption \(id)",
            outfitSnapshot: PublishedOutfitSnapshot(name: "Outfit \(id)", items: []),
            mediaPath: "posts/\(id).jpg",
            createdAt: createdAt,
            likeCount: likeCount
        )
    }

    private func waitUntil(
        timeoutNanoseconds: UInt64 = 1_000_000_000,
        condition: () -> Bool
    ) async {
        let start = DispatchTime.now().uptimeNanoseconds
        while !condition() {
            if DispatchTime.now().uptimeNanoseconds - start > timeoutNanoseconds {
                return
            }
            await Task.yield()
        }
    }

    func testPostLikesLoadFailureSetsErrorAndRetryRecovers() async {
        let service = MockPostLikeService()
        service.fetchResults = [
            .failure(StubError.network),
            .success(PostLikeSnapshot(postId: "p1", isLiked: true, likeCount: 8)),
        ]
        let viewModel = PostLikesViewModel(ownerId: "user_1", service: service)
        let post = makePost(id: "p1", likeCount: 7)

        await viewModel.loadIfNeeded(post: post)

        let failedState = viewModel.state(for: post)
        XCTAssertFalse(failedState.isLoaded)
        XCTAssertFalse(failedState.isPending)
        XCTAssertFalse(failedState.isRemoved)
        XCTAssertNotNil(failedState.errorMessage)

        viewModel.retry(post: post)
        await waitUntil { viewModel.state(for: post).isLoaded }

        let recovered = viewModel.state(for: post)
        XCTAssertTrue(recovered.isLoaded)
        XCTAssertFalse(recovered.isPending)
        XCTAssertTrue(recovered.isLiked)
        XCTAssertEqual(recovered.likeCount, 8)
        XCTAssertNil(recovered.errorMessage)
        XCTAssertEqual(service.fetchCount, 2)
    }

    func testPostLikesToggleFailureRevertsStateSetsErrorAndRetryRecovers() async {
        let service = MockPostLikeService()
        service.fetchResults = [
            .success(PostLikeSnapshot(postId: "p2", isLiked: false, likeCount: 3)),
        ]
        service.setResults = [
            .failure(StubError.network),
            .success(PostLikeSnapshot(postId: "p2", isLiked: true, likeCount: 4)),
        ]
        let viewModel = PostLikesViewModel(ownerId: "user_1", service: service)
        let post = makePost(id: "p2", likeCount: 3)

        await viewModel.loadIfNeeded(post: post)
        viewModel.toggle(post: post)
        await waitUntil { viewModel.state(for: post).errorMessage != nil }

        let failedState = viewModel.state(for: post)
        XCTAssertTrue(failedState.isLoaded)
        XCTAssertFalse(failedState.isPending)
        XCTAssertFalse(failedState.isLiked)
        XCTAssertEqual(failedState.likeCount, 3)
        XCTAssertEqual(failedState.errorMessage, StubError.network.localizedDescription)

        viewModel.retry(post: post)
        await waitUntil { viewModel.state(for: post).isLiked }

        let recovered = viewModel.state(for: post)
        XCTAssertTrue(recovered.isLoaded)
        XCTAssertFalse(recovered.isPending)
        XCTAssertTrue(recovered.isLiked)
        XCTAssertEqual(recovered.likeCount, 4)
        XCTAssertNil(recovered.errorMessage)
        XCTAssertEqual(service.setCount, 2)
        XCTAssertEqual(service.lastSetDesiredState, true)
    }

    func testPostLikesPostRemovedOnFetchMarksRemovedAndBlocksRetry() async {
        let service = MockPostLikeService()
        service.fetchResults = [.failure(PostLikeFunctionsError.postRemoved)]
        let viewModel = PostLikesViewModel(ownerId: "user_1", service: service)
        let post = makePost(id: "p3", likeCount: 2)

        await viewModel.loadIfNeeded(post: post)

        let state = viewModel.state(for: post)
        XCTAssertTrue(state.isRemoved)
        XCTAssertFalse(state.isLoaded)
        XCTAssertFalse(state.isPending)
        XCTAssertEqual(state.errorMessage, PostLikeFunctionsError.postRemoved.localizedDescription)

        viewModel.retry(post: post)
        await Task.yield()
        XCTAssertEqual(service.fetchCount, 1)
    }

    func testPostLikesPostRemovedOnToggleMarksRemoved() async {
        let service = MockPostLikeService()
        service.fetchResults = [
            .success(PostLikeSnapshot(postId: "p4", isLiked: false, likeCount: 2)),
        ]
        service.setResults = [.failure(PostLikeFunctionsError.postRemoved)]
        let viewModel = PostLikesViewModel(ownerId: "user_1", service: service)
        let post = makePost(id: "p4", likeCount: 2)

        await viewModel.loadIfNeeded(post: post)
        viewModel.toggle(post: post)
        await waitUntil { viewModel.state(for: post).isRemoved }

        let state = viewModel.state(for: post)
        XCTAssertTrue(state.isRemoved)
        XCTAssertFalse(state.isLoaded)
        XCTAssertFalse(state.isPending)
        XCTAssertEqual(state.errorMessage, PostLikeFunctionsError.postRemoved.localizedDescription)
    }

    func testPostLikesResetClearsCachedStatesForRefresh() async {
        let service = MockPostLikeService()
        service.fetchResults = [
            .success(PostLikeSnapshot(postId: "p5", isLiked: false, likeCount: 5)),
            .success(PostLikeSnapshot(postId: "p5", isLiked: true, likeCount: 11)),
        ]
        let viewModel = PostLikesViewModel(ownerId: "user_1", service: service)
        let post = makePost(id: "p5", likeCount: 5)

        await viewModel.loadIfNeeded(post: post)
        XCTAssertEqual(viewModel.state(for: post).likeCount, 5)

        viewModel.reset()
        XCTAssertTrue(viewModel.states.isEmpty)
        XCTAssertFalse(viewModel.state(for: post).isLoaded)

        await viewModel.loadIfNeeded(post: post)
        let refreshed = viewModel.state(for: post)
        XCTAssertTrue(refreshed.isLoaded)
        XCTAssertTrue(refreshed.isLiked)
        XCTAssertEqual(refreshed.likeCount, 11)
        XCTAssertEqual(service.fetchCount, 2)
    }

    func testDemoPostLikeFunctionsReconcilesKnownCountAcrossFetchAndSet() async throws {
        let suiteName = "SocialFeedAuditFixesTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let service = DemoPostLikeFunctions(defaults: defaults, delay: .zero)

        let initial = try await service.fetch(postId: "demo_1", ownerId: "u1", knownCount: 12)
        XCTAssertFalse(initial.isLiked)
        XCTAssertEqual(initial.likeCount, 12)

        let liked = try await service.set(postId: "demo_1", ownerId: "u1", isLiked: true)
        XCTAssertTrue(liked.isLiked)
        XCTAssertEqual(liked.likeCount, 13)

        let fetchedAfterLike = try await service.fetch(postId: "demo_1", ownerId: "u1", knownCount: 12)
        XCTAssertTrue(fetchedAfterLike.isLiked)
        XCTAssertEqual(fetchedAfterLike.likeCount, 13)

        let unliked = try await service.set(postId: "demo_1", ownerId: "u1", isLiked: false)
        XCTAssertFalse(unliked.isLiked)
        XCTAssertEqual(unliked.likeCount, 12)

        let fetchedAfterUnlike = try await service.fetch(postId: "demo_1", ownerId: "u1", knownCount: 12)
        XCTAssertFalse(fetchedAfterUnlike.isLiked)
        XCTAssertEqual(fetchedAfterUnlike.likeCount, 12)
    }

    func testChronologicalFeedPaginationAndDeduplication() async {
        let p1 = makePost(id: "post_1", createdAt: Date(timeIntervalSince1970: 300))
        let p2 = makePost(id: "post_2", createdAt: Date(timeIntervalSince1970: 200))
        let p2Updated = Post(
            id: "post_2",
            schemaVersion: 1,
            authorId: "author_post_2",
            caption: "Updated caption",
            outfitSnapshot: PublishedOutfitSnapshot(name: "Outfit post_2", items: []),
            mediaPath: "posts/post_2.jpg",
            createdAt: Date(timeIntervalSince1970: 200),
            likeCount: 9
        )
        let p3 = makePost(id: "post_3", createdAt: Date(timeIntervalSince1970: 100))

        var requestedCursors: [String?] = []
        let model = ChronologicalFeedModel { cursor in
            requestedCursors.append(cursor)
            if cursor == nil {
                return FeedPage(posts: [p2, p1], nextCursor: "cursor_2", removedPostIDs: [])
            }
            return FeedPage(posts: [p2Updated, p3], nextCursor: nil, removedPostIDs: [])
        }

        await model.loadInitial()
        XCTAssertTrue(model.hasLoaded)
        XCTAssertTrue(model.hasMore)
        XCTAssertEqual(model.posts.map(\.id), ["post_1", "post_2"])

        await model.loadMore()
        XCTAssertFalse(model.hasMore)
        XCTAssertEqual(requestedCursors, [nil, "cursor_2"])
        XCTAssertEqual(model.posts.map(\.id), ["post_1", "post_2", "post_3"])
        XCTAssertEqual(model.posts.first(where: { $0.id == "post_2" })?.caption, "Updated caption")
    }

    func testChronologicalFeedRetryAfterInitialAndNextPageFailure() async {
        let p1 = makePost(id: "post_1", createdAt: Date(timeIntervalSince1970: 200))
        let p2 = makePost(id: "post_2", createdAt: Date(timeIntervalSince1970: 100))

        var attempt = 0
        let model = ChronologicalFeedModel { cursor in
            attempt += 1
            if cursor == nil {
                if attempt == 1 { throw StubError.network }
                return FeedPage(posts: [p1], nextCursor: "cursor_2", removedPostIDs: [])
            } else {
                if attempt == 3 { throw StubError.network }
                return FeedPage(posts: [p2], nextCursor: nil, removedPostIDs: [])
            }
        }

        await model.loadInitial()
        XCTAssertFalse(model.hasLoaded)
        XCTAssertNotNil(model.errorMessage)

        await model.retry()
        XCTAssertTrue(model.hasLoaded)
        XCTAssertNil(model.errorMessage)
        XCTAssertEqual(model.posts.map(\.id), ["post_1"])

        await model.loadMore()
        XCTAssertNotNil(model.errorMessage)
        XCTAssertEqual(model.posts.map(\.id), ["post_1"])

        await model.retry()
        XCTAssertNil(model.errorMessage)
        XCTAssertFalse(model.hasMore)
        XCTAssertEqual(model.posts.map(\.id), ["post_1", "post_2"])
    }
}
