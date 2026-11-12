# Issue 184 — Infinite scrolling in Discovery

Discovery opens directly to **For You** and **Friends**. For You has a two-column outfit grid and Search Styles. Friends uses large photo cards with the author, date, and caption. Both tabs use the same chronological sample feed until a source for friends' posts is available. The two designs considered were a Load More button with an upward pull gesture and automatic paging near the end of the feed. Automatic paging is the selected app flow. The manual option remains available in the Xcode canvas.

## Feed states

| State | Behavior |
| --- | --- |
| First load | Show a spinner while requesting the first page. |
| Empty | Show “No outfits yet” after a successful empty result with no next page. |
| Next page | Request more near the bottom, keep existing posts visible, and show a spinner while the request is active. |
| Failed load | Show Retry after a request fails. Keep any loaded posts and retry the same failed operation. Pause automatic paging until the error clears. |
| Refresh | Pull down to request the first page. Replace posts and reset the cursor on success. Keep the previous posts and cursor if refresh fails. |
| Removed post | Apply explicit removal IDs and merge overlapping pages by stable ID. Sort newest first, with ID as the date tie-breaker. |
| End of feed | Show “You're all caught up” when the source has no next page. |

## Handoff for published posts

The app currently supplies fixture pages and [bundled photos](demo-photo-sources.md). The feed takes a page loader and a post artwork renderer. A future service can supply the existing shared `Post` snapshots from user uploads, resolve published media from `Post.mediaPath`, and wire a separate Friends feed when audience filtering is available. Feed paging is independent of the Camera, closet, and upload flows.

The loader receives an optional cursor. A nil cursor requests the first page. A response contains the posts, an opaque cursor that advances to the next page (nil at the end), and any explicit removed post IDs. The service should paginate consistently with the model's date and ID ordering, report failed or timed-out requests to the model, and return snapshots whose media is safe for the signed-in audience. The fixture implementation adds no Firestore query, upload workflow, ranking, or access rules.

## Verification

- Run `sh scripts/tests/check-infinite-feed.sh` for cursor, retry, refresh, ordering, and removal checks.
- Run `InfiniteFeedUITests.testAutomaticPagingPausesOnFailureAndRetries` for the Discovery entry point, tabs, and scroll, failure, and retry flow. The test uses an isolated fixture that fails page two once.

Verified on iPhone 17 with iOS 26.5. The Debug build and model checks passed. Both layouts were inspected in the signed-in app. The targeted UI test passed with zero failures and captured the last page as a test attachment.
