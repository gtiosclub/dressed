---
title: Persistent OOTD like contract
date: 2026-11-17
status: implemented-locally
tags: [dressed, ootd, likes, firestore]
issue: https://github.com/gtiosclub/dressed/issues/214
---

# Keep like identity private and publish only the count

> Implementation update (November 17, 2026): the user authorized this contract. The iOS client,
> owner-private relationship, atomic count rules, demo persistence, and emulator tests now exist in
> the working tree. The live `out-fitted` rules have **not** been deployed; production remains closed
> until an authorized lead performs or explicitly approves that access-control change.

## Key architecture points

- **Observed:** `OOTDFeedView` stores liked post IDs in a local SwiftUI `Set` and adds one to synthetic counts. Relaunch loses the state; there is no persisted like record, count, function, or approved rule.
- **Proposed boundary:** one authenticated user may set their desired like state for one existing public post. Other viewers receive only a nonnegative count; they cannot list who liked it.
- Use a deterministic relationship key `(uid, postId)` so repeated likes and retries are idempotent. The client sends desired state (`true` or `false`), never an increment/decrement.
- The UI keeps confirmed state separate from pending intent. While one write is pending, another tap sends no request. A failed write restores the last confirmed state and offers retry.
- This is a recommendation for [#214](https://github.com/gtiosclub/dressed/issues/214), not an approved contract or authorization to connect Firebase, change rules, deploy functions, or create student tickets.

## Recommendation

For lead review, prefer an owner-only `users/{uid}/postLikes/{postId}` relationship plus a trusted `setPostLike(postId, desiredState)` operation that transactionally creates/deletes the relationship and updates a public `likeCount`. Choose direct public like documents with read-time `count()` only if Neal and the lead explicitly decide that liker identities may be queryable.

## Decision context

Success means User A can like `post_001`, relaunch, and recover a filled heart while User B sees the updated count without reading A's relationship. Like and unlike must be safe to retry, a pending control must not emit duplicate writes, failed writes must not become confirmed UI, and a removed post must not remain actionable. Assumptions: authenticated users only, synthetic users/posts for evaluation, modest pilot traffic, and public posts supplied by the still-proposed publication work in [#59](https://github.com/gtiosclub/dressed/issues/59). Feed refresh remains owned by [#184](https://github.com/gtiosclub/dressed/issues/184). Non-goals are notifications, liker lists, ranking, offline mutation queues, distributed counters, and production rollout.

## Options and total cost

Estimates assume one iOS/backend engineer, the existing Firebase stack, a 12-month pilot below Firestore's free daily quotas, and exclude general post/feed work. Firebase currently includes 50,000 document reads and 20,000 writes/deletes per day in the free quota; beyond that, usage is region-priced. A `count()` is billed by index entries scanned, in batches of up to 1,000. ([Firestore billing](https://firebase.google.com/docs/firestore/pricing), checked 2026-11-17.)

| Approach | Duplicate taps, retries, access | First useful slice | Launch and 12-month cost | Decisive tradeoff |
| --- | --- | --- | --- | --- |
| **A. Direct like record + read-time count:** `posts/{postId}/likes/{uid}`; client sets/deletes its deterministic document and calls `count()` | Same-state `set` is idempotent; deleting a missing record is harmless. Rules can limit writes to the signed-in UID. However, aggregation queries use the same authorization as document queries, so allowing B to count also permits the matching records to be queried; the UID in the document path reveals identity. `count()` has no offline cache or realtime listener. ([Aggregation queries](https://firebase.google.com/docs/firestore/query-data/aggregation-queries)) | **1–2 person-days:** contract, repository methods, UI state tests, rules/emulator tests | **$0 expected launch cash**; **$0/year within free quota**, otherwise Firestore reads/writes/deletes. Maintenance: about **0.25 day/month**. | Smallest implementation and exact count, but cannot provide “public count, private liker identity” with client rules alone. Count cost/latency grows with likes. |
| **B. Owner-only relationship + trusted write-time count:** `users/{uid}/postLikes/{postId}` and public `posts/{postId}.likeCount`; one authenticated operation applies the desired state in a transaction | Deterministic relationship plus desired state makes duplicate calls/retries no-ops. Clients read only their own relationship; everyone allowed to read the post can see `likeCount`. Trusted code, not clients, changes the count. | **3–5 person-days:** contract, authenticated mutation, transaction, cleanup behavior, UI state tests, rules/emulator tests | **$0 expected launch cash** at pilot usage, but deployment requires the pay-as-you-go Blaze plan and a linked billing account. The 12-month formula is Firestore operations + function invocations/compute/build/container storage beyond included quotas. Maintenance: about **0.5 day/month**. Exact bill is unknown until region, runtime, and traffic are chosen. ([Functions pricing](https://firebase.google.com/docs/functions/faq-and-troubleshooting#pricing)) | Preserves identity privacy and gives feed-friendly counts, at the cost of trusted backend code and counter contention at higher traffic. |

No separate open-source or paid product is credible for this two-boolean relationship: the Firebase SDK is already in the app, and adding another datastore would increase authentication, synchronization, and rule surface. A sharded open-source-style counter pattern is intentionally deferred; Firebase recommends it only when a single counter becomes write-contentious, and extra shards make reads slower and more expensive. ([Distributed counters](https://firebase.google.com/docs/firestore/solutions/counters))

## Proposed state contract and synthetic walkthrough

| State | Confirmed data | Heart/count shown | Tap or refresh behavior |
| --- | --- | --- | --- |
| **Unliked** | No `user_a/postLikes/post_001`; public count `24` | Outline, `24` | Tap sends exactly `setPostLike(post_001, true)` and enters pending. |
| **Pending like/unlike** | Last server-confirmed state retained | Requested heart may be shown with spinner and “Updating”; count remains confirmed | Disable the control. A repeat tap sends **no** second request. Cancellation/navigation does not invent success. |
| **Liked** | A's relationship exists; public count `25` | Filled, `25` | A later, non-pending tap sends exactly `setPostLike(post_001, false)`. Relaunch reads A's owner-only relationship and the public count. |
| **Failed** | Last confirmed relationship/count unchanged | Revert to confirmed heart/count; show retry | Retry resends the same desired state. A timeout may hide a committed write, so refresh reconciles before or after retry; idempotency prevents double count. |
| **Removed post** | Post missing/marked removed; an orphan relationship may temporarily remain | Remove card or show unavailable; no heart/count action | Mutation returns `notFound` and sends no count change. Refresh drops the card and its transient state. Trusted post-removal work later cleans relationships; clients must not recursively delete other users' data. |

Example: A taps like on `post_001`; the app sends one `desiredState=true` request. A's second tap while it is pending is ignored because the control is disabled. If the transaction succeeds, refresh or relaunch reads A's private relationship and shows filled/25. B reads `post_001.likeCount == 25` but cannot query A's relationship. If the response is lost, A may still momentarily see the old state; refresh reconciles it, and retrying `true` is a no-op rather than a second increment.

## Technical implementation after approval

Keep the public `Post` snapshot and private relationship separate. The proposed trusted transaction authenticates the caller, validates `postId`, reads the public post and caller's relationship, then performs only the transition that is actually needed: absent→present writes the relationship and increments; present→absent deletes it and decrements without going below zero; same→same returns the current result without changing data. A callable/HTTPS mutation is preferable to an asynchronous Firestore trigger because trigger ordering is not guaranteed and events are delivered at least once, which would require extra idempotency bookkeeping. ([Firestore trigger guarantees](https://firebase.google.com/docs/functions/firestore-events)) At pilot scale, a single count field is simpler than shards; measure contention before changing it.

The smallest separable work, **only after approval**, is:

1. **Lead/backend contract:** `setPostLike(postId, desiredState) -> { postId, isLiked, likeCount }`, authenticated UID derivation, transaction invariants, removed-post behavior, and emulator tests. This is `lead` + `backend`, not a basic student ticket.
2. **Small backend client function:** `fetchMyLikeStates(postIds) -> Set<Post.ID>` for the current bounded feed page, owner-only and injected behind a protocol. This can become a `social` + `backend` student function once rules and examples exist.
3. **Small UI state/control:** inputs `postId`, confirmed `likeCount`, confirmed `isLiked`, write state (`idle/pending/failed/removed`), and a desired-state callback. This can become a `social` + `frontend` student view/state ticket using synthetic data. Screenshots of the component are preferred in the PR.

Rollout would start with synthetic repository tests, then the Firestore emulator, then a development project behind an explicit feature flag. Rollback hides/disables the control while preserving relationship records; do not reset counts from clients. A reconciliation job or admin script may later compare relationships and counts, but is not part of the first slice.

## Decision gates and handoff

1. **Neal + lead — milestone and visibility:** Are persistent likes in the next milestone, and are counts visible to every signed-in user, post authors only, or nobody yet? If liker identity must stay private, reject Option A.
2. **Lead — counter boundary:** Confirm expected peak likes per post. Start with one transactionally maintained count only for a modest pilot; revisit sharding if emulator/load evidence shows sustained contention or transaction failures. Firestore documents the security, offline, latency, and write-rate limitations of client/write-time aggregation. ([Write-time aggregation](https://firebase.google.com/docs/firestore/solutions/aggregation))
3. **Lead — rule/emulator exit checks:** signed-out users cannot like or read owner relationships; A can read only A's relationship; B cannot get/list A's; neither client can write `likeCount`; invalid/missing post IDs fail; duplicate like/unlike and retry do not change the count twice; count never goes negative; concurrent A/B writes converge; failed/aborted transactions preserve both records; removed posts reject writes; post removal leaves no public private-data path; public-count visibility matches gate 1.

**Decision requested:** approve or reject Option B's privacy boundary, decide milestone/count audience, and assign the trusted mutation and rule design to lead review before any student tickets are published.
