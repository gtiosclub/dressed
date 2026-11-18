import Foundation

/// Public, pre-aggregated inputs for OOTD ranking. Callers must not populate this
/// context from another user's private closet or media.
struct FeedRankingContext {
    var now: Date
    var categoryAffinity: [ClothingCategory: Double] = [:]
    var authorAffinity: [String: Double] = [:]
    var savedOutfitCategories: [Set<ClothingCategory>] = []
    var followedAuthorIDs: Set<String> = []
    var engagementByPostID: [String: FeedPostEngagement] = [:]
    var recentCategoryExposure: [ClothingCategory: Double] = [:]
    var postExposureCounts: [String: Int] = [:]
    var authorExposureCounts: [String: Int] = [:]
    var sessionCategoryIntent: [ClothingCategory: Double] = [:]
    var dismissalByCategory: [ClothingCategory: Double] = [:]
    var dismissedAuthorIDs: Set<String> = []

    static func chronological(now: Date = Date()) -> Self {
        Self(now: now)
    }
}

struct FeedPostEngagement {
    var impressions: Int
    var saves: Int
    var impressionsLast24Hours: Int
    var savesLast24Hours: Int
}

struct RankedFeedPost {
    let post: Post
    let candidateScore: Double
}

/// An explainable first-stage ranker for public OOTD snapshots.
struct FeedRanker {
    static let rankingVersion = "ootd-heuristic-v1"

    private enum Weight {
        static let recency = 0.20
        static let categoryAffinity = 0.16
        static let authorAffinity = 0.10
        static let similarSavedOutfits = 0.10
        static let followedAuthor = 0.08
        static let smoothedSaveRate = 0.10
        static let trendingVelocity = 0.08
        static let categoryNovelty = 0.06
        static let explorationValue = 0.05
        static let currentSessionIntent = 0.04
        static let postCompleteness = 0.03
        static let dismissalAffinity = 0.12
        static let repeatExposure = 0.08
    }

    /// Empty contexts intentionally preserve the service's chronological order.
    /// This is the cold-start and kill-switch behavior.
    func rank(_ posts: [Post], context: FeedRankingContext) -> [RankedFeedPost] {
        guard hasPersonalizationSignals(context) else {
            return posts.map { RankedFeedPost(post: $0, candidateScore: recency($0, now: context.now)) }
        }

        let candidates = posts.map { post in
            RankedFeedPost(post: post, candidateScore: candidateScore(for: post, context: context))
        }
        return diversityRerank(candidates)
    }

    private func candidateScore(for post: Post, context: FeedRankingContext) -> Double {
        let categories = Set(post.outfitSnapshot.items.map(\.category))
        var positiveTotal = 0.0
        var availableWeight = 0.0

        func add(_ value: Double?, weight: Double) {
            guard let value else { return }
            positiveTotal += clamp(value) * weight
            availableWeight += weight
        }

        add(recency(post, now: context.now), weight: Weight.recency)
        add(average(categories, values: context.categoryAffinity), weight: Weight.categoryAffinity)
        add(context.authorAffinity[post.authorId], weight: Weight.authorAffinity)
        add(savedOutfitSimilarity(categories, saved: context.savedOutfitCategories),
            weight: Weight.similarSavedOutfits)
        add(context.followedAuthorIDs.isEmpty ? nil : (context.followedAuthorIDs.contains(post.authorId) ? 1 : 0),
            weight: Weight.followedAuthor)

        let engagement = context.engagementByPostID[post.id]
        add(engagement.map(smoothedSaveRate), weight: Weight.smoothedSaveRate)
        add(engagement.map(trendingVelocity), weight: Weight.trendingVelocity)
        add(novelty(categories, exposure: context.recentCategoryExposure), weight: Weight.categoryNovelty)
        add(exploration(post, context: context), weight: Weight.explorationValue)
        add(average(categories, values: context.sessionCategoryIntent), weight: Weight.currentSessionIntent)
        add(completeness(post), weight: Weight.postCompleteness)

        let normalizedPositive = availableWeight > 0 ? positiveTotal / availableWeight : 0
        let dismissal = dismissalAffinity(post, categories: categories, context: context)
        let repeatPenalty = min(1, Double(context.postExposureCounts[post.id, default: 0]) / 3)
        return clamp(normalizedPositive
                     - Weight.dismissalAffinity * dismissal
                     - Weight.repeatExposure * repeatPenalty)
    }

    private func diversityRerank(_ candidates: [RankedFeedPost]) -> [RankedFeedPost] {
        var remaining = candidates
        var selected: [RankedFeedPost] = []

        while !remaining.isEmpty {
            let winner = remaining.indices.max { lhs, rhs in
                adjustedScore(remaining[lhs], selected: selected) <
                    adjustedScore(remaining[rhs], selected: selected)
            } ?? remaining.startIndex
            selected.append(remaining.remove(at: winner))
        }
        return selected
    }

    private func adjustedScore(_ candidate: RankedFeedPost, selected: [RankedFeedPost]) -> Double {
        guard !selected.isEmpty else { return candidate.candidateScore }
        let categories = Set(candidate.post.outfitSnapshot.items.map(\.category))
        let maximumSimilarity = selected.map {
            jaccard(categories, Set($0.post.outfitSnapshot.items.map(\.category)))
        }.max() ?? 0
        let repeatedAuthor = selected.last?.post.authorId == candidate.post.authorId ? 1.0 : 0
        let saturatedCategory = categories.map { category in
            Double(selected.filter {
                $0.post.outfitSnapshot.items.contains { $0.category == category }
            }.count) / Double(selected.count)
        }.max() ?? 0

        return candidate.candidateScore
            - 0.12 * maximumSimilarity
            - 0.08 * repeatedAuthor
            - 0.05 * saturatedCategory
    }

    private func hasPersonalizationSignals(_ context: FeedRankingContext) -> Bool {
        !context.categoryAffinity.isEmpty ||
            !context.authorAffinity.isEmpty ||
            !context.savedOutfitCategories.isEmpty ||
            !context.followedAuthorIDs.isEmpty ||
            !context.engagementByPostID.isEmpty ||
            !context.recentCategoryExposure.isEmpty ||
            !context.postExposureCounts.isEmpty ||
            !context.authorExposureCounts.isEmpty ||
            !context.sessionCategoryIntent.isEmpty ||
            !context.dismissalByCategory.isEmpty ||
            !context.dismissedAuthorIDs.isEmpty
    }

    private func recency(_ post: Post, now: Date) -> Double {
        let ageHours = max(0, now.timeIntervalSince(post.createdAt) / 3_600)
        return exp(-ageHours / 72)
    }

    private func average(
        _ categories: Set<ClothingCategory>,
        values: [ClothingCategory: Double]
    ) -> Double? {
        guard !categories.isEmpty, !values.isEmpty else { return nil }
        return categories.reduce(0) { $0 + values[$1, default: 0] } / Double(categories.count)
    }

    private func savedOutfitSimilarity(
        _ categories: Set<ClothingCategory>,
        saved: [Set<ClothingCategory>]
    ) -> Double? {
        guard !categories.isEmpty, !saved.isEmpty else { return nil }
        return saved.map { jaccard(categories, $0) }.max()
    }

    private func smoothedSaveRate(_ engagement: FeedPostEngagement) -> Double {
        // A 20% prior over ten virtual impressions avoids rewarding tiny samples.
        clamp((Double(max(0, engagement.saves)) + 2) /
              (Double(max(0, engagement.impressions)) + 10))
    }

    private func trendingVelocity(_ engagement: FeedPostEngagement) -> Double {
        let rate = (Double(max(0, engagement.savesLast24Hours)) + 1) /
            (Double(max(0, engagement.impressionsLast24Hours)) + 10)
        return clamp(rate * 3)
    }

    private func novelty(
        _ categories: Set<ClothingCategory>,
        exposure: [ClothingCategory: Double]
    ) -> Double? {
        guard let saturation = average(categories, values: exposure) else { return nil }
        return 1 - clamp(saturation)
    }

    private func exploration(_ post: Post, context: FeedRankingContext) -> Double? {
        guard !context.postExposureCounts.isEmpty || !context.authorExposureCounts.isEmpty else { return nil }
        let postValue = 1 / Double(context.postExposureCounts[post.id, default: 0] + 1)
        let authorValue = 1 / Double(context.authorExposureCounts[post.authorId, default: 0] + 1)
        return (postValue + authorValue) / 2
    }

    private func completeness(_ post: Post) -> Double {
        var score = post.mediaPath.isEmpty ? 0 : 0.5
        if !post.outfitSnapshot.items.isEmpty { score += 0.3 }
        if !post.outfitSnapshot.items.isEmpty &&
            post.outfitSnapshot.items.allSatisfy({ !$0.mediaPath.isEmpty }) {
            score += 0.2
        }
        return score
    }

    private func dismissalAffinity(
        _ post: Post,
        categories: Set<ClothingCategory>,
        context: FeedRankingContext
    ) -> Double {
        if context.dismissedAuthorIDs.contains(post.authorId) { return 1 }
        return average(categories, values: context.dismissalByCategory) ?? 0
    }

    private func jaccard(
        _ lhs: Set<ClothingCategory>,
        _ rhs: Set<ClothingCategory>
    ) -> Double {
        let union = lhs.union(rhs)
        guard !union.isEmpty else { return 0 }
        return Double(lhs.intersection(rhs).count) / Double(union.count)
    }

    private func clamp(_ value: Double) -> Double {
        min(1, max(0, value.isFinite ? value : 0))
    }
}
