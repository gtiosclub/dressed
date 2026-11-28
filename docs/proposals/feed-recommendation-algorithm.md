# OOTD feed recommendation algorithm

Research date: November 16, 2026. Status: proposal for review; this does not authorize implementation, deployment, data collection, purchasing, or ticket assignment.

Implementation note: the `jayden-algorithm` branch now contains a pure Swift,
client-side ranking baseline and regression check. It accepts only supplied
public/aggregated inputs and falls back to chronology when they are absent. This
is an integration seam for evaluation, not the proposed production server
boundary or evidence that engagement collection is live.

## Key architecture points

- This proposal assumes “feed” means the **OOTD post feed**, not the separate Discovery catalog-idea grid. Today, `InfiniteDiscoveryFeed` displays the same bounded chronological `Post` results behind both “For You” and “Friends”; the labels are not separate ranking products.
- The current trustworthy input is an authorized public `Post` snapshot with published media and clothing categories. Likes are local UI state; preference and follow records are templates, not live data sources.
- Candidate retrieval and ranking should be separate. The backend first fetches a bounded, moderation-safe pool of recent public posts; a deterministic ranker then scores and diversifies it. The client must never read another user’s private closet to calculate relevance.
- Chronological order remains the cold-start, outage, and opt-out fallback. A recommendation response needs a ranking version and reason codes so results can be tested and explained without exposing another user’s behavior.
- The highest-impact constraint is data readiness, not model sophistication: Dressed has no durable impression, save, dismiss, follow, or publication pipeline sufficient to train or evaluate a learned feed ranker.

## Recommendation

Build a small in-house, server-side heuristic ranker after public post delivery and consented event collection exist. Keep the existing chronological feed until those gates pass; reconsider a hybrid model only after at least 10,000 eligible posts and 100,000 quality interaction events produce a measurable offline and online advantage.

## Decision context

The goal is a useful, diverse OOTD feed without weakening ownership or publication boundaries. Success means p95 ranking latency below 300 ms excluding images, no private paths, stable pagination, and at least a 10% relative lift in save-per-impression over chronological order in a sufficiently powered test. Estimates assume one engineer at $75/hour, 1,000 daily active users, 10 daily feed requests each, and 12 months. Labor is separate from cash. Visual similarity, ads, and training on captions or images are out of scope.

## Options and total cost

| Option | First useful slice | Launch cash | Ongoing cash and maintenance | 12-month cash | Decisive tradeoff |
| --- | ---: | ---: | ---: | ---: | --- |
| **In-house weighted ranker on Firebase** | 5–8 person-days ($3,000–$4,800 labor) | $0 expected | Estimated $0–$25/month plus 2–4 engineer-hours/month. Firestore bills document/index reads and has daily no-cost quotas; Functions includes 2M invocations/month ([Firebase pricing](https://firebase.google.com/pricing), [Firestore billing](https://firebase.google.com/docs/firestore/pricing)). | **$0–$300**, plus labor | Best cold-start behavior and easiest rollback; weights are hand-tuned. |
| **Self-hosted LightFM** | 10–15 person-days ($6,000–$9,000 labor) | $0 license; $0–$50 setup estimate | Estimated $5–$30/month plus 4–8 engineer-hours/month. LightFM handles implicit feedback and metadata under Apache-2.0 ([project](https://github.com/lyst/lightfm)); Dressed owns hosting and pipelines. | **$60–$410**, plus labor | More expressive with dense interactions, but adds training and artifact operations. |
| **Google AI Commerce Recommendations** | 12–20 person-days ($7,200–$12,000 labor) | $0 setup assumption; billing required | 300,000 predictions/month cost $81. Assuming 30 training node-hours at $2.50 makes about $156/month; actual training is unknown ([pricing](https://cloud.google.com/products/retail/pricing)). | **About $1,872** under that assumption | Managed serving, but commerce-oriented, locked-in, and disproportionate now. |

Cash excludes shared media delivery, taxes, and support. Region, document size, rule reads, retries, and training cadence can change totals; the managed estimate is a scenario, not a quote.

## Technical implementation

1. **Settle the contract.** Confirm with Neal that this applies to OOTD posts. Define an eligible public candidate as a non-removed, signed-in-readable `Post` whose separately published media is available. Keep Discovery `CatalogProduct` ranking outside this service.
2. **Establish the baseline.** Extend the proposed `PostRepository.feed(cursor)` boundary with opaque pagination over `(createdAt, postId)`. Measure latency, duplicates, and save-per-impression. Define an impression by visible duration, not page fetch.
3. **Add minimal, consented signals.** Version impression, save, dismiss, and follow events only after behavior and retention are approved. Derive actor ownership server-side. Exclude private closet items, email, body data, and raw photos.
4. **Generate and rank candidates.** Retrieve a bounded recent pool and exclude removed, blocked, self-hidden, already-dismissed, or unavailable posts. Normalize each available feature to `0...1`, then calculate:

   ```text
   relevance =
       0.20 × recency
     + 0.16 × categoryAffinity
     + 0.10 × authorAffinity
     + 0.10 × similarSavedOutfits
     + 0.08 × followedAuthor
     + 0.10 × smoothedSaveRate
     + 0.08 × trendingVelocity
     + 0.06 × categoryNovelty
     + 0.05 × explorationValue
     + 0.04 × currentSessionIntent
     + 0.03 × postCompleteness
     - 0.12 × dismissalAffinity
     - 0.08 × repeatExposure

   candidateScore = clamp(relevance, 0, 1)
   ```

   The positive weights sum to 1.0. `recency` uses exponential time decay. Category and author affinity come from prior durable saves, not private closet contents. `similarSavedOutfits` compares only published category/style metadata. `smoothedSaveRate` uses a prior so tiny samples do not appear perfect; `trendingVelocity` measures recent rather than lifetime activity. Novelty and exploration give new categories, posts, and creators controlled exposure. Session intent decays after the session. Completeness checks only whether the public snapshot can render; it does not judge fashion quality. Dismissal and repeat exposure are penalties.

   Several inputs—impressions, dismissals, follows, durable saves, session intent, and style metadata—are proposed, not currently implemented. Until each signal is approved and trustworthy, omit it and renormalize the remaining positive weights. Do not silently interpret a missing value as dislike.

   After candidate scoring, build the final page with a diversity-aware reranker:

   ```text
   nextPostScore =
       candidateScore
     - 0.12 × similarityToAlreadySelectedPosts
     - 0.08 × repeatedAuthorPenalty
     - 0.05 × saturatedCategoryPenalty
   ```

   Select the highest adjusted candidate for each next position. This keeps individually relevant posts while preventing one author, category combination, or visual pattern from dominating the page. Reserve roughly 10% of eligible positions for safe exploration, subject to the same authorization and moderation filters.
5. **Serve stable pages.** Return post IDs, scores, reason codes, `rankingVersion`, and an opaque snapshot cursor. Recheck visibility before response. On ranker failure, return chronology; a kill switch restores it without an app release.
6. **Validate before rollout.** Unit-test scoring, ties, exclusions, diversity, cursors, cancellation, and fallback. Use fixtures, then authorization emulator tests. Shadow-score first, inspect category/author exposure, then run an opt-in A/B test. Promote only if the success threshold improves without harming hide/report rate, latency, or exposure concentration.

## Decision gates

1. **Corpus owner — Neal/TBD:** confirm OOTD posts versus Discovery ideas before any schema or service work. Requested decision: approve OOTD as the sole scope of this proposal.
2. **Data and trust — lead:** approve event definitions, consent/retention, block/report behavior, and public-post eligibility. Gate: no personalized rollout until durable saves or equivalent high-quality feedback and cross-user authorization tests exist.
3. **Model gate — lead/data:** remain on the heuristic until there are at least 10,000 eligible posts and 100,000 retained quality interactions, then compare it with LightFM using a time-based holdout. Adopt ML only if it beats the heuristic by at least 5% on NDCG@20 and passes the online safety/latency gates.

**Decision requested:** approve the staged in-house ranker and chronological fallback as the feed recommendation plan, subject to the three gates above.
