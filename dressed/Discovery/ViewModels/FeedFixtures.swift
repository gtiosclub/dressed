//
//  FeedFixtures.swift
//  dressed
//
//  Created by Tiana Prem  on 11/3/26.
//
import Foundation

@MainActor
final class FeedFixtures {
    private var shouldFailNextPage = true

    enum FixtureError: LocalizedError {
        case unavailable
        case invalidCursor

        var errorDescription: String? {
            switch self {
            case .unavailable:
                return "Could not load more posts. Please retry."
            case .invalidCursor:
                return "Unknown fixture page."
            }
        }
    }

    func loadPage(cursor: String?) async throws -> FeedPage {
        // A short delay makes the loading indicator visible.
        try await Task.sleep(for: .milliseconds(600))

        switch cursor {
        case nil:
            return FeedPage(
                posts: [
                    Self.post("A", minutesAgo: 1),
                    Self.post("B", minutesAgo: 2),
                    Self.post("C", minutesAgo: 3)
                ],
                nextCursor: "page-2",
                removedPostIDs: []
            )

        case "page-2":
            // Fail once so we can demonstrate Retry.
            if shouldFailNextPage {
                shouldFailNextPage = false
                throw FixtureError.unavailable
            }

            return FeedPage(
                posts: [
                    Self.post("C", minutesAgo: 3),
                    Self.post("D", minutesAgo: 4)
                ],
                nextCursor: nil,
                removedPostIDs: ["demo_post_B"]
            )

        default:
            throw FixtureError.invalidCursor
        }
    }

    private static func post(
        _ letter: String,
        minutesAgo: Int
    ) -> Post {
        Post(
            id: "demo_post_\(letter)",
            schemaVersion: 1,
            authorId: "fixture_user",
            caption: "Sample post \(letter)",
            outfitSnapshot: PublishedOutfitSnapshot(
                name: "Outfit \(letter)",
                items: []
            ),
            mediaPath: "",
            createdAt: Date(timeIntervalSince1970: 1_792_000_000)
                .addingTimeInterval(-Double(minutesAgo) * 60)
        )
    }
}
