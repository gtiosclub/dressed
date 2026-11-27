import Combine
import FirebaseFirestore
import Foundation

enum FollowFunctionsError: LocalizedError, Equatable {
    case invalidIdentifier
    case cannotFollowSelf

    var errorDescription: String? {
        switch self {
        case .invalidIdentifier:
            "Invalid user identifier."
        case .cannotFollowSelf:
            "You cannot follow yourself."
        }
    }
}

protocol FollowFunctions {
    func fetchFollowingIds(ownerId: String) async throws -> Set<String>
    func fetchFollowerCount(userId: String) async throws -> Int
    func fetchFollowingCount(userId: String) async throws -> Int
    func setFollowing(ownerId: String, targetUserId: String, isFollowing: Bool) async throws
}

struct FirebaseFollowFunctions: FollowFunctions {
    private let db = Firestore.firestore()

    func fetchFollowingIds(ownerId: String) async throws -> Set<String> {
        guard isValidFirestoreDocumentId(ownerId) else {
            throw FollowFunctionsError.invalidIdentifier
        }
        let snapshot = try await db
            .collection("users")
            .document(ownerId)
            .collection("following")
            .getDocuments(source: .server)
        return Set(snapshot.documents.map(\.documentID))
    }

    func fetchFollowerCount(userId: String) async throws -> Int {
        guard isValidFirestoreDocumentId(userId) else {
            throw FollowFunctionsError.invalidIdentifier
        }
        let snapshot = try await db
            .collection("users")
            .document(userId)
            .collection("followers")
            .count
            .getAggregation(source: .server)
        return max(Int(truncating: snapshot.count), 0)
    }

    func fetchFollowingCount(userId: String) async throws -> Int {
        guard isValidFirestoreDocumentId(userId) else {
            throw FollowFunctionsError.invalidIdentifier
        }
        let snapshot = try await db
            .collection("users")
            .document(userId)
            .collection("following")
            .count
            .getAggregation(source: .server)
        return max(Int(truncating: snapshot.count), 0)
    }

    func setFollowing(ownerId: String, targetUserId: String, isFollowing: Bool) async throws {
        guard isValidFirestoreDocumentId(ownerId), isValidFirestoreDocumentId(targetUserId) else {
            throw FollowFunctionsError.invalidIdentifier
        }
        guard ownerId != targetUserId else {
            throw FollowFunctionsError.cannotFollowSelf
        }

        let followingRef = db
            .collection("users")
            .document(ownerId)
            .collection("following")
            .document(targetUserId)
        let followerRef = db
            .collection("users")
            .document(targetUserId)
            .collection("followers")
            .document(ownerId)

        let batch = db.batch()
        if isFollowing {
            let timestamp = FieldValue.serverTimestamp()
            batch.setData([
                "id": targetUserId,
                "schemaVersion": 1,
                "ownerId": ownerId,
                "targetUserId": targetUserId,
                "createdAt": timestamp
            ], forDocument: followingRef)
            batch.setData([
                "id": ownerId,
                "schemaVersion": 1,
                "ownerId": ownerId,
                "targetUserId": targetUserId,
                "createdAt": timestamp
            ], forDocument: followerRef)
        } else {
            batch.deleteDocument(followingRef)
            batch.deleteDocument(followerRef)
        }
        try await batch.commit()
    }
}

final class DemoFollowFunctions: FollowFunctions {
    private let defaults: UserDefaults
    private static let seededOwnerId = "preview_user"
    private static let seededFollowing = ["jane", "alex", "riley"]

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        seedIfNeeded()
    }

    func fetchFollowingIds(ownerId: String) async throws -> Set<String> {
        try Task.checkCancellation()
        guard isValidFirestoreDocumentId(ownerId) else {
            throw FollowFunctionsError.invalidIdentifier
        }
        seedIfNeeded()
        return loadSet(forKey: followingKey(ownerId: ownerId))
    }

    func fetchFollowerCount(userId: String) async throws -> Int {
        try Task.checkCancellation()
        guard isValidFirestoreDocumentId(userId) else {
            throw FollowFunctionsError.invalidIdentifier
        }
        seedIfNeeded()
        return loadSet(forKey: followersKey(userId: userId)).count
    }

    func fetchFollowingCount(userId: String) async throws -> Int {
        try Task.checkCancellation()
        guard isValidFirestoreDocumentId(userId) else {
            throw FollowFunctionsError.invalidIdentifier
        }
        seedIfNeeded()
        return loadSet(forKey: followingKey(ownerId: userId)).count
    }

    func setFollowing(ownerId: String, targetUserId: String, isFollowing: Bool) async throws {
        try Task.checkCancellation()
        guard isValidFirestoreDocumentId(ownerId), isValidFirestoreDocumentId(targetUserId) else {
            throw FollowFunctionsError.invalidIdentifier
        }
        guard ownerId != targetUserId else {
            throw FollowFunctionsError.cannotFollowSelf
        }
        seedIfNeeded()

        var following = loadSet(forKey: followingKey(ownerId: ownerId))
        var followers = loadSet(forKey: followersKey(userId: targetUserId))
        if isFollowing {
            following.insert(targetUserId)
            followers.insert(ownerId)
        } else {
            following.remove(targetUserId)
            followers.remove(ownerId)
        }
        saveSet(following, forKey: followingKey(ownerId: ownerId))
        saveSet(followers, forKey: followersKey(userId: targetUserId))
    }

    private func seedIfNeeded() {
        let seededKey = "demoFollows.seeded.v1"
        guard !defaults.bool(forKey: seededKey) else { return }
        defaults.set(true, forKey: seededKey)
        saveSet(Set(Self.seededFollowing), forKey: followingKey(ownerId: Self.seededOwnerId))
        for target in Self.seededFollowing {
            var followers = loadSet(forKey: followersKey(userId: target))
            followers.insert(Self.seededOwnerId)
            saveSet(followers, forKey: followersKey(userId: target))
        }
    }

    private func followingKey(ownerId: String) -> String {
        "demoFollows.following.\(ownerId)"
    }

    private func followersKey(userId: String) -> String {
        "demoFollows.followers.\(userId)"
    }

    private func loadSet(forKey key: String) -> Set<String> {
        Set(defaults.stringArray(forKey: key) ?? [])
    }

    private func saveSet(_ set: Set<String>, forKey key: String) {
        defaults.set(Array(set).sorted(), forKey: key)
    }
}

extension DiscoveryPostSource {
    static var currentFollows: any FollowFunctions {
        if isDemo { return DemoFollowFunctions() }
        return FirebaseFollowFunctions()
    }
}

@MainActor
final class FollowViewModel: ObservableObject {
    @Published private(set) var followingIds: Set<String> = []
    @Published private(set) var followerCounts: [String: Int] = [:]
    @Published private(set) var followingCounts: [String: Int] = [:]
    @Published private(set) var pendingTargetIds: Set<String> = []
    @Published private(set) var hasLoadedFollowing = false
    @Published private(set) var errorMessage: String?

    private let ownerId: String
    private let service: any FollowFunctions

    init(ownerId: String, service: any FollowFunctions) {
        self.ownerId = ownerId
        self.service = service
    }

    func isFollowing(_ targetUserId: String) -> Bool {
        followingIds.contains(targetUserId)
    }

    func loadFollowing() async {
        errorMessage = nil
        do {
            let ids = try await service.fetchFollowingIds(ownerId: ownerId)
            guard !Task.isCancelled else { return }
            followingIds = ids
            followingCounts[ownerId] = ids.count
            hasLoadedFollowing = true
        } catch {
            guard !Task.isCancelled, !(error is CancellationError) else { return }
            errorMessage = error.localizedDescription
        }
    }

    func loadCounts(for userId: String) async {
        errorMessage = nil
        do {
            async let followers = service.fetchFollowerCount(userId: userId)
            async let following = service.fetchFollowingCount(userId: userId)
            let (followerCount, followingCount) = try await (followers, following)
            guard !Task.isCancelled else { return }
            followerCounts[userId] = followerCount
            followingCounts[userId] = followingCount
        } catch {
            guard !Task.isCancelled, !(error is CancellationError) else { return }
            errorMessage = error.localizedDescription
        }
    }

    func toggleFollow(targetUserId: String) async {
        guard targetUserId != ownerId,
              isValidFirestoreDocumentId(targetUserId),
              !pendingTargetIds.contains(targetUserId) else { return }

        let wasFollowing = followingIds.contains(targetUserId)
        let desired = !wasFollowing
        let previousFollowerCount = followerCounts[targetUserId]
        let previousFollowingCount = followingCounts[ownerId]

        pendingTargetIds.insert(targetUserId)
        errorMessage = nil
        if desired {
            followingIds.insert(targetUserId)
        } else {
            followingIds.remove(targetUserId)
        }
        if let previousFollowerCount {
            followerCounts[targetUserId] = max(0, previousFollowerCount + (desired ? 1 : -1))
        }
        if let previousFollowingCount {
            followingCounts[ownerId] = max(0, previousFollowingCount + (desired ? 1 : -1))
        }

        defer { pendingTargetIds.remove(targetUserId) }

        do {
            try await service.setFollowing(
                ownerId: ownerId,
                targetUserId: targetUserId,
                isFollowing: desired
            )
        } catch {
            if wasFollowing {
                followingIds.insert(targetUserId)
            } else {
                followingIds.remove(targetUserId)
            }
            if let previousFollowerCount {
                followerCounts[targetUserId] = previousFollowerCount
            }
            if let previousFollowingCount {
                followingCounts[ownerId] = previousFollowingCount
            }
            guard !Task.isCancelled, !(error is CancellationError) else { return }
            errorMessage = error.localizedDescription
        }
    }
}
