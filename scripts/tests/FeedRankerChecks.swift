import Foundation

@main struct FeedRankerChecks {
    static func main() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let posts = [
            post("new-shoes", author: "alex", category: .shoes, ageHours: 1, now: now),
            post("saved-style", author: "sam", category: .outerwear, ageHours: 24, now: now),
            post("repeat-author", author: "sam", category: .outerwear, ageHours: 25, now: now),
            post("dismissed", author: "blocked-by-preference", category: .tops, ageHours: 2, now: now)
        ]
        let ranker = FeedRanker()

        let fallback = ranker.rank(posts, context: .chronological(now: now))
        precondition(fallback.map(\.post.id) == posts.map(\.id), "Cold start must preserve chronology")

        var context = FeedRankingContext(now: now)
        context.categoryAffinity = [.outerwear: 1, .shoes: 0.1]
        context.savedOutfitCategories = [[.outerwear, .shoes]]
        context.followedAuthorIDs = ["sam"]
        context.engagementByPostID = [
            "saved-style": FeedPostEngagement(
                impressions: 100, saves: 40, impressionsLast24Hours: 20, savesLast24Hours: 10
            )
        ]
        context.dismissedAuthorIDs = ["blocked-by-preference"]
        context.postExposureCounts = ["repeat-author": 3]
        context.authorExposureCounts = ["sam": 1]

        let ranked = ranker.rank(posts, context: context)
        precondition(ranked.first?.post.id == "saved-style", "Strong relevant signals should beat recency")
        precondition(ranked.dropFirst().first?.post.authorId != ranked.first?.post.authorId,
                     "Diversity reranking should separate repeated authors when scores are close")
        precondition(ranked.last?.post.id == "dismissed", "Dismissed affinity should be penalized")
        precondition(Set(ranked.map(\.post.id)).count == posts.count, "Ranking must not duplicate posts")
        precondition(ranked.allSatisfy { (0...1).contains($0.candidateScore) }, "Scores must be normalized")

        print("PASS: chronological fallback, weighted relevance, penalties, diversity, deduplication, normalized scores")
    }

    private static func post(
        _ id: String,
        author: String,
        category: ClothingCategory,
        ageHours: Double,
        now: Date
    ) -> Post {
        Post(
            id: id,
            schemaVersion: 1,
            authorId: author,
            caption: id,
            outfitSnapshot: PublishedOutfitSnapshot(
                name: id,
                items: [PublishedClothingSnapshot(
                    sourceItemId: "item-\(id)",
                    name: id,
                    category: category,
                    mediaPath: "posts/\(author)/\(id)/item.png",
                    productURL: nil
                )]
            ),
            mediaPath: "posts/\(author)/\(id)/cover.png",
            createdAt: now.addingTimeInterval(-ageHours * 3_600)
        )
    }
}
