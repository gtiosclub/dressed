import Foundation

/// Separate, bounded sample pages for comparing automatic and manual paging.
@MainActor
final class InfiniteFeedFixtures {
    private var failSecondPage: Bool
    private(set) var requestedCursors: [String?] = []

    init(failSecondPage: Bool = false) {
        self.failSecondPage = failSecondPage
    }

    func loadPage(cursor: String?) async throws -> FeedPage {
        requestedCursors.append(cursor)
        try await Task.sleep(for: .milliseconds(600))
        let page: Int
        if let cursor {
            guard let number = Int(cursor), (1...3).contains(number) else {
                throw FeedFixtures.FixtureError.invalidCursor
            }
            page = number
        } else {
            page = 0
        }
        if page == 1 && failSecondPage {
            failSecondPage = false
            throw FeedFixtures.FixtureError.unavailable
        }
        // Each later page repeats the preceding page's final ID.
        let start = page == 0 ? 0 : page * 12 - 1
        return FeedPage(
            posts: (start..<(page + 1) * 12).map(Self.post),
            nextCursor: page < 3 ? String(page + 1) : nil,
            removedPostIDs: page == 1 ? ["infinite_2"] : []
        )
    }

    static func post(_ index: Int) -> Post {
        let names = ["Soft layers", "City essentials", "Weekend denim", "Coffee run",
                     "Neutral tones", "A little color", "Vintage mood", "Everyday classics"]
        let authors = ["jane", "alex", "riley", "sam", "jordan", "lee"]
        let categories: [ClothingCategory] = [.outerwear, .tops, .pants, .dresses, .skirts, .shoes]
        return Post(
            id: "infinite_\(index)", schemaVersion: 1,
            authorId: authors[index % authors.count],
            caption: names[index % names.count],
            outfitSnapshot: PublishedOutfitSnapshot(name: names[index % names.count], items: [
                PublishedClothingSnapshot(sourceItemId: "fixture_\(index)",
                                          name: names[index % names.count],
                                          category: categories[index % categories.count],
                                          mediaPath: "", productURL: nil)
            ]),
            mediaPath: "",
            createdAt: Date(timeIntervalSince1970: 1_794_225_600 - Double(index * 3600))
        )
    }
}
