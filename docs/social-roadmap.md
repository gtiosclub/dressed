# Social roadmap and feature spec

October 18 navigation update: outfit posts now belong on the OOTD section inside the Discovery tab, while the Discovery section shows individual clothing ideas. The tracks below describe the post and catalog contracts; references to a “Discovery Feed” are earlier planning language and should be read as OOTD Feed. See [the implementation plan](discovery-ootd-implementation-plan.md). Live publication and public post media remain lead work.

The `social` team owns small Discovery views and basic post/save operations. It does not publish private closet photos or decide the public snapshot contract. This roadmap follows the shared [product scope](product-scope.md) and complements the [data roadmap](data-roadmap.md): an outfit becomes social content only through an explicit publish action after private closet and outfit flows work. GitHub issues and the social board remain the source of truth for assignment and status.

## Product outcome and sequence

| Release slice | User-visible result | Handoff |
| --- | --- | --- |
| D1. Feed components | Discovery Feed can render supplied OOTD post cards and loading/empty/error states. | Lead supplies safe public `Post` snapshots and feed state. |
| D2. Inspect a post | A post opens its outfit breakdown and author profile header. | Lead defines safe author display data and publication media. |
| D3. Save a post | A user saves/unsaves a post and sees a saved-post list after relaunch. | Lead supplies owner-only rules and handles removed posts. |
| D4. Search entry | Discovery Search queries the public catalog of selected retailer products. | Lead approves the first retailer source and supported matching behavior. |

The October 19 local import/recognition prototype stays private in My Closet. It does not create an OOTD post or unblock publication.

## Track D: Discovery Feed

### D1. Feed cards and status

**User flow:** The Discovery tab switches between individual clothing ideas and OOTD posts. OOTD shows a recent post card with publishable outfit image, caption and author display. Its pin, Find items, comments and like buttons act in the feed; the card itself has no detail route. Find items opens a published-piece sheet. Loading, no-posts, retryable error and removed-content states are distinct. Backend engagement and saved-post persistence remain lead work.

**Inputs and outputs:** Cards accept supplied `Post` display data and callbacks. The recent-post function reads a bounded page of public post records; the lead defines cursor ordering, indexes, and the safe DTO. Do not use private `ClothingItem.imagePath` in a feed card.

**Tickets:** [#60 post card](https://github.com/gtiosclub/dressed/issues/60), [#80 recent posts](https://github.com/gtiosclub/dressed/issues/80), [#125 feed status views](https://github.com/gtiosclub/dressed/issues/125), and [#151 expandable caption](https://github.com/gtiosclub/dressed/issues/151). [Lead #59](https://github.com/gtiosclub/dressed/issues/59) owns publication, public media, and feed wiring.

**Acceptance checks:** Supplied recent posts appear in stable newest-first order; card controls report the intended post ID without opening a detail page; empty and failed requests show different messages; retry calls the supplied action once; private closet paths never appear in public post data.

### D2. Outfit breakdown and profile header

**User flow:** Opening an OOTD shows its caption and the separate pieces included in the published snapshot. A profile header shows approved public display fields. Missing or removed snapshot media shows a clear fallback. Browsing a post does not save its clothing into the viewer's closet.

**Inputs and outputs:** The breakdown row receives publishable item names/categories and public media references from the post snapshot. The profile header receives a community-safe display name and avatar reference supplied by the lead. Auth email, private item paths, measurements, and source photos are not display inputs.

**Tickets:** [#79 clothing breakdown row](https://github.com/gtiosclub/dressed/issues/79), [#150 breakdown list](https://github.com/gtiosclub/dressed/issues/150), [#78 profile header](https://github.com/gtiosclub/dressed/issues/78), [#162 filter supplied posts by author](https://github.com/gtiosclub/dressed/issues/162), and [#167 published-post image fallback](https://github.com/gtiosclub/dressed/issues/167). Lead #49 must settle author display examples and [#59](https://github.com/gtiosclub/dressed/issues/59) must create a separate publishable snapshot.

**Acceptance checks:** A two-piece fixture shows two distinct rows; a missing image retains its label; the profile displays only supplied public fields; no post action exposes a private owner path or silently imports a piece.

## Track B: Saved posts

**User flow:** The save control adds or removes a relationship between the signed-in user and a post. The Saved view shows post cards for still-available posts and a removed-content state for posts that were deleted. Saving is idempotent: repeated taps or retries do not create duplicate saved records.

**Inputs and outputs:** The save/unsave functions receive a post ID and derive the owner from the current session. The list function returns saved IDs or a bounded page; the lead joins them with available public posts and clears user-specific state after sign-out. A save never copies a post into the private closet.

**Tickets:** [#61 save post](https://github.com/gtiosclub/dressed/issues/61), [#121 remove saved post](https://github.com/gtiosclub/dressed/issues/121), [#122 fetch saved IDs](https://github.com/gtiosclub/dressed/issues/122), [#124 saved-post grid](https://github.com/gtiosclub/dressed/issues/124), [#149 save toggle](https://github.com/gtiosclub/dressed/issues/149), and [#148 filter saved posts](https://github.com/gtiosclub/dressed/issues/148). [Lead #94](https://github.com/gtiosclub/dressed/issues/94) owns the owner-only Firestore rules before live writes.

**Acceptance checks:** Account A can save, relaunch, and still see the state; a second save creates no duplicate; Account B cannot read or alter A's saved relation; unsaving removes only A's relation; a deleted post gives a removed-content state.

## Track S: Search and composing a post

**Search:** [#161 Feed/Search switch](https://github.com/gtiosclub/dressed/issues/161) reports the selected Discovery section to its parent. [#64 search field](https://github.com/gtiosclub/dressed/issues/64) accepts text and reports query changes or submit events. The first dataset is selected retailer products, represented by the separate public `CatalogProduct` contract. The lead still must approve the first live retailer source and matching behavior. The fixture-backed API and network client in PR #144 demonstrate search wiring; they do not provide live retailer data. [#147 catalog-product row](https://github.com/gtiosclub/dressed/issues/147) starts after that PR merges. A field alone is not a search service; arbitrary substring search must not be assumed from Firestore.

**Compose:** [#123 caption field](https://github.com/gtiosclub/dressed/issues/123) receives text and enforces the agreed local length display. The lead owns explicit publication from a saved outfit, author permissions, a safe snapshot, separate public media, and failure cleanup. Camera recognition and Share to Dressed remain private import steps until the user separately publishes an OOTD.

**Acceptance checks:** Search reports the current query without mutating posts; an unsupported query gives a clear state. A caption is editable before publishing; canceling compose creates no post; publication uses only the explicitly selected outfit and public snapshot.

## Delivery gates and proposed three-sprint sequence

| Sprint | Social work | Observable review |
| --- | --- | --- |
| 1. Feed fixtures | Post card, breakdown row, profile header, and feed status views from approved synthetic input. | Navigate a two-piece sample post through empty and error states. |
| 2. Save state | Save/unsave functions, saved IDs, saved-post grid, and owner-only emulator checks. | Two synthetic accounts prove private saved relations and persistence after relaunch. |
| 3. Integration | Connect real feed results, removed-post behavior, search field, and caption field as lead contracts land. | A published synthetic outfit appears in Feed and can be saved by another account. |

Students should receive exact sample input/output values and callbacks before starting a small ticket. Lead publication and moderation decisions are separate gates. For native UI changes, build and exercise the affected flow in a simulator or device; for backend changes, check authorized and unauthorized emulator access. This roadmap does not assign students or change GitHub status.

## Decisions for Neal and leads

1. Define the public post snapshot and media lifetime without exposing private originals.
2. Approve the first live retailer source and matching behavior for the selected-product Search dataset.
3. Decide author display data, deleted-post behavior, and the report/block/moderation path before wider release.

See the [architecture](architecture.md), [delivery plan](delivery-plan.md), and [ticket index](github-issues.md) for shared contracts and dependencies.
