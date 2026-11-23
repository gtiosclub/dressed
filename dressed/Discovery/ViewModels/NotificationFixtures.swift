import Foundation

/// In-memory notifications for the SOCIAL-P09 prototype. No Firebase, no push.
/// The viewer is `user_a`; every user and post is synthetic.
///
/// | Fixture   | Event                                   | Covers                    |
/// | n_001–003 | 3 likes on post_002, maya last; unread  | like, unread, repeated    |
/// | n_004     | jordan comments on removed post_001     | comment, removed post     |
/// | n_005     | maya follows; read                      | follow, read              |
/// | n_006     | deleted user_x follows; unread          | unavailable profile       |
/// | n_007     | sam likes post_003; removed after load  | stale destination         |
@MainActor
final class NotificationFixtures: NotificationService {
    enum FixtureError: LocalizedError {
        case unavailable

        var errorDescription: String? { "Couldn't load notifications. Check your connection and try again." }
    }

    static let viewerId = "user_a"

    private(set) var fetchCount = 0
    private(set) var readIds: [String] = []
    private(set) var postLookups: [String] = []

    private let records: [AppNotification]
    private let failingFetches: Set<Int>
    private let delay: Duration
    private let names = ["user_b": "maya", "user_c": "jordan", "user_d": "sam"] // user_x was deleted.
    private let thumbnails = [
        "post_001": "DemoOutfitPhoto1", "post_002": "DemoOutfitPhoto2", "post_003": "DemoOutfitPhoto3"
    ]
    private var removedPosts: Set<String> = ["post_001"]
    /// Available for the first lookup only, so the post disappears between a refresh and a tap.
    private let removedAfterFirstLookup: Set<String> = ["post_003"]

    /// - Parameters:
    ///   - failingFetches: 1-based fetch numbers that throw once. `[2]` fails the first refresh.
    init(
        now: Date = .now,
        empty: Bool = false,
        failingFetches: Set<Int> = [],
        delay: Duration = .milliseconds(400)
    ) {
        self.failingFetches = failingFetches
        self.delay = delay
        records = empty ? [] : Self.records(now: now)
    }

    func fetchNotifications() async throws -> [AppNotification] {
        fetchCount += 1
        try await Task.sleep(for: delay)
        if failingFetches.contains(fetchCount) {
            throw FixtureError.unavailable
        }
        return records.map { record in
            var record = record
            if readIds.contains(record.id) { record.readAt = record.readAt ?? .now }
            return record
        }
    }

    func actorName(for userId: String) async -> String? {
        names[userId]
    }

    func postLookup(for postId: String) async -> NotificationPostLookup {
        let isRepeat = postLookups.contains(postId)
        postLookups.append(postId)
        if isRepeat && removedAfterFirstLookup.contains(postId) {
            removedPosts.insert(postId)
        }
        guard thumbnails[postId] != nil, !removedPosts.contains(postId) else { return .removed }
        return .available(thumbnail: thumbnails[postId])
    }

    func markRead(_ notificationIds: [String], at date: Date) async {
        readIds.append(contentsOf: notificationIds.filter { !readIds.contains($0) })
    }

    /// The viewer's own post, for opening `post_002` in the post-detail screen.
    /// `post_002` is never removed in these fixtures.
    static func post(id: String) -> Post? {
        guard id == "post_002" else { return nil }
        return Post(
            id: id, schemaVersion: 1, authorId: Self.viewerId,
            caption: "Weekend denim",
            outfitSnapshot: PublishedOutfitSnapshot(name: "Weekend denim", items: [
                PublishedClothingSnapshot(sourceItemId: "fixture_jacket", name: "Denim jacket",
                                          category: .outerwear, mediaPath: "", productURL: nil),
                PublishedClothingSnapshot(sourceItemId: "fixture_jeans", name: "Straight jeans",
                                          category: .pants, mediaPath: "", productURL: nil)
            ]),
            mediaPath: "",
            createdAt: Date(timeIntervalSince1970: 1_794_225_600)
        )
    }

    static func records(now: Date) -> [AppNotification] {
        func record(
            _ id: String, _ kind: AppNotification.Kind, actor: String, post: String? = nil,
            minutesAgo: Double, read: Bool
        ) -> AppNotification {
            let createdAt = now.addingTimeInterval(-minutesAgo * 60)
            return AppNotification(
                id: id, schemaVersion: 1, ownerId: viewerId, kind: kind,
                actorId: actor, postId: post, challengeId: nil, recommendationId: nil,
                createdAt: createdAt, readAt: read ? createdAt.addingTimeInterval(60) : nil
            )
        }
        return [
            record("n_001", .like, actor: "user_c", post: "post_002", minutesAgo: 20, read: false),
            record("n_002", .like, actor: "user_d", post: "post_002", minutesAgo: 10, read: false),
            record("n_003", .like, actor: "user_b", post: "post_002", minutesAgo: 2, read: false),
            record("n_004", .comment, actor: "user_c", post: "post_001", minutesAgo: 15, read: false),
            record("n_005", .follow, actor: "user_b", minutesAgo: 2 * 24 * 60, read: true),
            record("n_006", .follow, actor: "user_x", minutesAgo: 60, read: false),
            record("n_007", .like, actor: "user_d", post: "post_003", minutesAgo: 3 * 24 * 60, read: true)
        ]
    }
}
