import XCTest
@testable import dressed

@MainActor
final class SocialFullFeaturesTests: XCTestCase {
    private enum StubError: LocalizedError {
        case failed

        var errorDescription: String? {
            "Request failed."
        }
    }

    private final class MockUserProfileService: UserProfileFunctions {
        var stored: [String: UserProfile] = [:]
        private(set) var fetchedBatches: [[String]] = []
        private(set) var upsertedProfiles: [UserProfile] = []
        var upsertError: Error?

        func fetch(userId: String) async throws -> UserProfile? {
            stored[userId]
        }

        func fetch(userIds: [String]) async throws -> [String: UserProfile] {
            fetchedBatches.append(userIds.sorted())
            var result: [String: UserProfile] = [:]
            for id in userIds {
                if let profile = stored[id] {
                    result[id] = profile
                }
            }
            return result
        }

        func upsert(_ profile: UserProfile) async throws {
            if let upsertError { throw upsertError }
            upsertedProfiles.append(profile)
            stored[profile.id] = profile
        }
    }

    private final class MockFollowService: FollowFunctions {
        var following: Set<String> = []
        var followerCounts: [String: Int] = [:]
        var followingCounts: [String: Int] = [:]
        var setFollowingError: Error?
        private(set) var setCalls: [(ownerId: String, targetUserId: String, isFollowing: Bool)] = []

        func fetchFollowingIds(ownerId: String) async throws -> Set<String> {
            following
        }

        func fetchFollowerCount(userId: String) async throws -> Int {
            followerCounts[userId] ?? 0
        }

        func fetchFollowingCount(userId: String) async throws -> Int {
            followingCounts[userId] ?? 0
        }

        func setFollowing(ownerId: String, targetUserId: String, isFollowing: Bool) async throws {
            setCalls.append((ownerId, targetUserId, isFollowing))
            if let setFollowingError { throw setFollowingError }
            if isFollowing {
                following.insert(targetUserId)
            } else {
                following.remove(targetUserId)
            }
        }
    }

    private final class MockModerationService: ModerationFunctions {
        var blocked: Set<String> = []
        var setBlockedError: Error?
        var submitReportError: Error?
        private(set) var submittedReports: [(String, ReportTargetType, String, String?, String)] = []

        func fetchBlockedUserIds(ownerId: String) async throws -> Set<String> {
            blocked
        }

        func setBlocked(ownerId: String, targetUserId: String, isBlocked: Bool) async throws {
            if let setBlockedError { throw setBlockedError }
            if isBlocked {
                blocked.insert(targetUserId)
            } else {
                blocked.remove(targetUserId)
            }
        }

        func submitReport(
            reporterId: String,
            targetType: ReportTargetType,
            targetId: String,
            postId: String?,
            reason: String
        ) async throws {
            if let submitReportError { throw submitReportError }
            submittedReports.append((reporterId, targetType, targetId, postId, reason))
        }
    }

    @MainActor
    private final class MockCommentService: CommentService {
        var currentUserId: String? = "owner_1"
        let isDemo = true
        var comments: [PostComment] = []
        var deleteError: Error?
        private(set) var deletedIds: [(postId: String, commentId: String)] = []

        func fetch(postId: String) async throws -> [PostComment] {
            comments
        }

        func submit(postId: String, id: String, text: String) async throws {
            comments.insert(PostComment(id: id, authorId: currentUserId ?? "anon", text: text, createdAt: .now), at: 0)
        }

        func delete(postId: String, commentId: String) async throws {
            deletedIds.append((postId, commentId))
            if let deleteError { throw deleteError }
            comments.removeAll { $0.id == commentId }
        }
    }

    // MARK: - UserProfileStore

    func testUserProfileStoreLoadIfNeededCachesAndSkipsInvalidOrCachedIds() async {
        let service = MockUserProfileService()
        let now = Date(timeIntervalSince1970: 1_790_000_000)
        service.stored["u1"] = UserProfile(
            id: "u1",
            schemaVersion: 1,
            username: "jane.doe",
            displayName: "Jane Doe",
            avatarPath: nil,
            createdAt: now,
            updatedAt: now
        )
        let store = UserProfileStore(service: service)

        XCTAssertEqual(store.handle(for: "u1"), "@u1")
        XCTAssertEqual(store.displayName(for: "u1"), "u1")

        await store.loadIfNeeded(userIds: ["u1", "u1", "", "bad/id", "missing"])
        XCTAssertEqual(service.fetchedBatches, [["missing", "u1"]])
        XCTAssertEqual(store.handle(for: "u1"), "@jane.doe")
        XCTAssertEqual(store.displayName(for: "u1"), "Jane Doe")
        XCTAssertNil(store.profile(for: "missing"))

        await store.loadIfNeeded(userIds: ["u1"])
        XCTAssertEqual(service.fetchedBatches.count, 1)
    }

    func testUserProfileStoreEnsureOwnProfileCreatesDefaultWhenMissingAndPreservesExisting() async {
        let service = MockUserProfileService()
        let store = UserProfileStore(service: service)

        await store.ensureOwnProfile(userId: "uid_123", accountName: "Alex Rivera!")
        let created = store.profile(for: "uid_123")
        XCTAssertNotNil(created)
        XCTAssertEqual(created?.username, "alex_rivera")
        XCTAssertEqual(created?.displayName, "Alex Rivera!")
        XCTAssertEqual(service.upsertedProfiles.count, 1)

        await store.ensureOwnProfile(userId: "uid_123", accountName: "Different Name")
        XCTAssertEqual(store.profile(for: "uid_123")?.displayName, "Alex Rivera!")
        XCTAssertEqual(service.upsertedProfiles.count, 1)
    }

    func testUserProfileStoreSaveOwnProfileValidatesAndUpdatesCache() async throws {
        let service = MockUserProfileService()
        let store = UserProfileStore(service: service)

        do {
            try await store.saveOwnProfile(userId: "u1", username: "a", displayName: "Valid")
            XCTFail("Expected invalidUsername error")
        } catch let error as UserProfileError {
            XCTAssertEqual(error, .invalidUsername)
        }

        do {
            try await store.saveOwnProfile(userId: "u1", username: "bad name!", displayName: "Valid")
            XCTFail("Expected invalidUsername error")
        } catch let error as UserProfileError {
            XCTAssertEqual(error, .invalidUsername)
        }

        do {
            try await store.saveOwnProfile(userId: "u1", username: "valid_name", displayName: "   ")
            XCTFail("Expected invalidDisplayName error")
        } catch let error as UserProfileError {
            XCTAssertEqual(error, .invalidDisplayName)
        }

        try await store.saveOwnProfile(userId: "u1", username: "  Jane_99.ok ", displayName: "  Jane  ")
        XCTAssertEqual(store.profile(for: "u1")?.username, "jane_99.ok")
        XCTAssertEqual(store.profile(for: "u1")?.displayName, "Jane")
        XCTAssertEqual(store.handle(for: "u1"), "@jane_99.ok")
    }

    func testDemoUserProfileFunctionsSeedsAndPersistsEdits() async throws {
        let suiteName = "SocialFullFeaturesTests.UserProfile.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let service = DemoUserProfileFunctions(defaults: defaults)
        let jane = try await service.fetch(userId: "jane")
        XCTAssertEqual(jane?.username, "jane")

        let now = Date()
        let updated = UserProfile(
            id: "preview_user",
            schemaVersion: 1,
            username: "preview.custom",
            displayName: "Custom Preview",
            avatarPath: nil,
            createdAt: now,
            updatedAt: now
        )
        try await service.upsert(updated)
        let reloaded = try await service.fetch(userId: "preview_user")
        XCTAssertEqual(reloaded?.username, "preview.custom")
        XCTAssertEqual(reloaded?.displayName, "Custom Preview")
    }

    // MARK: - FollowViewModel

    func testFollowViewModelLoadsFollowsCountsAndTogglesWithRevertOnError() async {
        let service = MockFollowService()
        service.following = ["jane"]
        service.followerCounts["alex"] = 4
        service.followingCounts["alex"] = 2

        let viewModel = FollowViewModel(ownerId: "me", service: service)
        await viewModel.loadFollowing()
        XCTAssertTrue(viewModel.hasLoadedFollowing)
        XCTAssertTrue(viewModel.isFollowing("jane"))
        XCTAssertFalse(viewModel.isFollowing("alex"))
        XCTAssertEqual(viewModel.followingCounts["me"], 1)

        await viewModel.loadCounts(for: "alex")
        XCTAssertEqual(viewModel.followerCounts["alex"], 4)
        XCTAssertEqual(viewModel.followingCounts["alex"], 2)

        await viewModel.toggleFollow(targetUserId: "me")
        XCTAssertTrue(service.setCalls.isEmpty)

        await viewModel.toggleFollow(targetUserId: "alex")
        XCTAssertTrue(viewModel.isFollowing("alex"))
        XCTAssertEqual(viewModel.followerCounts["alex"], 5)
        XCTAssertEqual(viewModel.followingCounts["me"], 2)
        XCTAssertTrue(viewModel.pendingTargetIds.isEmpty)

        service.setFollowingError = StubError.failed
        await viewModel.toggleFollow(targetUserId: "alex")
        XCTAssertTrue(viewModel.isFollowing("alex"))
        XCTAssertEqual(viewModel.followerCounts["alex"], 5)
        XCTAssertEqual(viewModel.followingCounts["me"], 2)
        XCTAssertEqual(viewModel.errorMessage, StubError.failed.localizedDescription)
    }

    func testDemoFollowFunctionsSeedsPreviewUserAndPersistsChanges() async throws {
        let suiteName = "SocialFullFeaturesTests.Follows.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let service = DemoFollowFunctions(defaults: defaults)
        let initial = try await service.fetchFollowingIds(ownerId: "preview_user")
        XCTAssertEqual(initial, Set(["jane", "alex", "riley"]))

        let janeFollowers = try await service.fetchFollowerCount(userId: "jane")
        XCTAssertEqual(janeFollowers, 1)

        try await service.setFollowing(ownerId: "preview_user", targetUserId: "jane", isFollowing: false)
        let afterUnfollow = try await service.fetchFollowingIds(ownerId: "preview_user")
        XCTAssertEqual(afterUnfollow, Set(["alex", "riley"]))
        let janeFollowersAfter = try await service.fetchFollowerCount(userId: "jane")
        XCTAssertEqual(janeFollowersAfter, 0)
    }

    // MARK: - ModerationViewModel

    func testModerationViewModelBlockUnblockAndReport() async {
        let service = MockModerationService()
        service.blocked = ["spammer"]
        let viewModel = ModerationViewModel(ownerId: "me", service: service)

        await viewModel.loadBlockedUsers()
        XCTAssertTrue(viewModel.isBlocked("spammer"))

        await viewModel.block(userId: "me")
        XCTAssertFalse(viewModel.isBlocked("me"))

        await viewModel.block(userId: "troll")
        XCTAssertTrue(viewModel.isBlocked("troll"))

        await viewModel.unblock(userId: "spammer")
        XCTAssertFalse(viewModel.isBlocked("spammer"))

        let reported = await viewModel.report(
            targetType: .comment,
            targetId: "c1",
            postId: "p1",
            reason: "Harassment"
        )
        XCTAssertTrue(reported)
        XCTAssertEqual(service.submittedReports.count, 1)

        service.submitReportError = StubError.failed
        let failedReport = await viewModel.report(targetType: .post, targetId: "p2", reason: "Spam")
        XCTAssertFalse(failedReport)
        XCTAssertEqual(viewModel.errorMessage, StubError.failed.localizedDescription)
    }

    // MARK: - CommentsViewModel.delete

    func testCommentsViewModelDeleteRemovesOnSuccessAndSurfacesErrorOnFailure() async {
        let service = MockCommentService()
        service.comments = [
            PostComment(id: "c1", authorId: "owner_1", text: "First", createdAt: .now),
            PostComment(id: "c2", authorId: "owner_1", text: "Second", createdAt: .now)
        ]
        let viewModel = CommentsViewModel(postId: "post_1", service: service)
        await viewModel.load()
        XCTAssertEqual(viewModel.comments.map(\.id), ["c1", "c2"])

        await viewModel.delete(commentId: "c1")
        XCTAssertEqual(viewModel.comments.map(\.id), ["c2"])
        XCTAssertNil(viewModel.errorMessage)

        service.deleteError = StubError.failed
        await viewModel.delete(commentId: "c2")
        XCTAssertEqual(viewModel.comments.map(\.id), ["c2"])
        XCTAssertEqual(viewModel.errorMessage, StubError.failed.localizedDescription)
    }
}
