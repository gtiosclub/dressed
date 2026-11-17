# Discovery clothing ideas and OOTD posts: implementation plan

October 18 update: the designer's newer OOTD prototype supersedes the post-detail steps below. OOTD post cards stay in the feed; pins, Find items, comments and likes are direct controls. Find items opens a sheet of published pieces. The Debug create/share flow adds a local preview; backend publication and persistent engagement remain TBD.

Status: implementation in progress, October 18, 2026. This document retains the planned release gates; it does not authorize new GitHub tickets, backend services, or publication.

## Goal and working assumptions

- Discovery opens to **individual clothing ideas**: one garment per card, with its name, category, image or fallback, source, and an honest product link when available. A clothing idea is public inspiration, not an owned `ClothingItem` and not an outfit `Post`.
- **OOTD** is a distinct page for user-published outfit posts, their captions, author, published-piece breakdown, and saved-post state. Existing outfit posts remain `Post` records; the change does not migrate them into clothing records.
- Keep the agreed three top-level tabs (My Closet, Discovery, Camera). The supplied prototype places OOTD beside Discovery in a segmented control inside the Discovery tab; use that placement.
- Use the existing public `CatalogProduct` records as the first source of individual ideas. The current catalog is a local synthetic prototype, so a useful release feed depends on an approved live source. Whether users may publish *single-item ideas* is a separate product decision and would require a separate public contract and moderation path.
- Discovery has browse and search/filter for the **same item dataset**. Search for outfit posts, if retained, belongs within OOTD. Saving an idea to Wishlist or My Closet is outside this navigation change and must go through an explicit review/confirmation flow.

## Baseline before this change and remaining constraints

Before this change, `ContentView.swift` put a Feed/Search segmented switch inside Discovery. Feed used `DiscoveryFeedView`, `DiscoveryFeedViewModel`, `PostFunctions.fetchRecentPosts()`, and `DiscoveryPostDetailView`; Search used `PrototypeCatalogView`, `CatalogSearching`, and the local catalog API. `Post` and `PublishedClothingSnapshot` remain shared public outfit contracts; `CatalogProduct` remains a separate retailer offer contract. Public post media, publishing, and saved-post wiring are not connected.

## Implementation sequence

| Step | Work | Reviewable outcome |
| --- | --- | --- |
| 1. Settle product contract | With Neal, confirm OOTD's navigation entry, which catalog sources qualify as “ideas,” whether an idea is an offer or a curated editorial item, and whether users can submit standalone ideas. Define what tapping an idea does and whether the OOTD page needs search or saved posts in this milestone. | One approved screen map and sample idea/post records; unresolved choices remain TBD. |
| 2. Reshape navigation | In `ContentView.swift`, replace Feed/Search section state with a Discovery item-browse root and an explicit OOTD route. Keep profile, Camera, and My Closet navigation intact. Preserve a Debug route to the catalog fixture so simulator checks remain possible. | A signed-in user can reach Discovery ideas and OOTD, then return without losing tab state. |
| 3. Build the idea browse flow | Adapt the catalog search service and `PrototypeCatalogView` into an item-first browse grid/list with category and text filtering, an item detail or source-link action, image fallback, and loading/empty/error/retry states. Use injected service data and bounded pages; avoid labeling unavailable `.example` links as purchasable. | An individual garment, rather than an outfit post, occupies each Discovery result. Search and category filters operate on the same public item dataset. |
| 4. Move the post flow | Keep the `Post` contract, `PostFunctions`, synthetic fixtures and published-piece breakdown. Use in-feed controls and a Find items sheet; remove the post-detail route. Keep private closet paths out of public rendering. | OOTD shows outfit posts; only pin, Find items, comments and like controls respond to taps. Discovery no longer queries `fetchRecentPosts()`. |
| 5. Wire live data safely | Keep `CatalogProduct` and `Post` repositories separate. Approve a real item source, freshness and link behavior before live item browsing. Complete public post-media delivery, publication and saved-post rules before claiming OOTD is live. Do not infer a direct match between a visual idea and a retailer product. | Both pages have explicit source and failure behavior; no private item photo is exposed by browsing OOTD. |
| 6. Update tests and docs | Update accessibility IDs and Debug launch arguments after the route change. Add focused unit tests for item filtering/service state and one simulator UI path covering Discovery → idea and Discovery → OOTD → in-feed controls. Update product scope, architecture, social roadmap, backlog references, and screenshots once the product decisions and implementation land. | Simulator interaction and screenshots verify the visible flows; documentation states observed behavior separately from planned service work. |

## Acceptance checks

1. A signed-in user opens Discovery and sees individual garments, not multi-piece post tiles. Each idea shows a source and handles missing imagery or an unavailable link honestly.
2. Text and category controls filter ideas from the same dataset. Empty results, service failure, retry, and cancellation behave predictably.
3. The OOTD page shows outfit posts with author, caption and image fallback. The post card does not navigate. Find items opens the published-piece breakdown; comments and likes stay in the feed. Existing `Post` records and saved-post IDs keep their identity; no data migration is needed solely to move the UI.
4. Sign-out clears user-specific page state. No browse or save action silently adds an idea to a private closet or wishlist, and no post view resolves a private `ClothingItem.imagePath`.
5. Test the affected controls in an iOS simulator through normal sign-in, with an Xcode build and screenshot comparison. If backend rules or live feeds change, check both authorized and unauthorized access in an emulator or designated development project.

## Ownership and release gates

Navigation, shared contracts, data-source approval, security, and integration are `lead` work. A student-sized idea card/filter or OOTD view can be split after the screen map and sample input/output are approved, using the `social` ownership label and `frontend` work-type label; repository functions or shared contracts use `backend` as applicable. Do not publish dependent tickets or assign people until the product choices above are discussed with Neal. The synthetic catalog and post fixtures can support a UI milestone before live sources are ready, but that milestone must be labeled a prototype.
