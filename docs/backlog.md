# Feature backlog

20 scoped tickets organized into exactly three primary subteams: `viz`, `data`, `social`. Each GitHub issue receives exactly one team label plus `enhancement` (or `documentation` where relevant). Priority, phase and dependencies are recorded in the body. Area tags below are descriptive metadata, not additional team assignments. Individual assignees remain unset; Nicole is named as the proposed visual-retrieval contributor only.

The schema templates now exist, but services, mocks, rules and UI remain planned. P0.1 reviews and completes those contracts instead of recreating them. See [team boundaries](teams.md), [scope](product-scope.md), [architecture](architecture.md) and [GitHub mapping](github-issues.md).

P0 (3), P1 (5), P2 (5), P3 (3), P4 (4). P0-P2 is the first release. Start P0.1 and PS4.1 independently. P1 closes when persisted approved items appear in the closet after relaunch. GitHub is the live status source after publishing; local checklists describe acceptance, not completion.

## P0.1 - Foundation: Review schema templates and define service protocols

**Context.** Different teams need the same item, outfit and post semantics.

**Task.** Review the existing Codable templates in dressed/Common/Models and examples in backend/schemas. Finalize validation/versioning, then add service protocol signatures and deterministic mocks without connecting Firebase. Coordinate Outfit/Avatar with viz and Profile/Post with social.

**Acceptance criteria.**

- [ ] Sample item, outfit and post fixtures round-trip through Codable types.
- [ ] All three groups can identify the same ownership and category fields.
- [ ] Mocks cover success, empty and typed failure results.

Priority: High. Owner: data. Labels: data, contracts. Blocked by: none. Status: Planned.

## P0.2 - Foundation: Add the authenticated three-tab shell

**Context.** Authentication currently logs success without moving to an app shell.

**Task.** Observe Firebase auth state and route between Authentication and My Closet, Discovery, Camera using injected mock services.

**Acceptance criteria.**

- [ ] A signed-in user reaches all three tabs and returns with tab state preserved.
- [ ] Sign-out returns to authentication and clears private state.
- [ ] Launch while signed out and restored-session launch reach the correct destination.

Priority: High. Owner: viz. Labels: viz, navigation. Blocked by: P0.1. Status: Planned.

## P0.3 - Foundation: Verify owner-scoped persistence

**Context.** A compiling Firebase client does not prove private data is protected.

**Task.** Add versioned development rules/index configuration and a minimal item/media round-trip using Storage and Firestore. Record the selected development project and setup method.

**Acceptance criteria.**

- [ ] Account A writes and rereads its own fixture after restart.
- [ ] Account B cannot read A’s private item/media or write A’s records; unauthenticated access is denied.
- [ ] The same cases run against an emulator or explicitly designated development environment with reproducible instructions.

Priority: High. Owner: data. Labels: data, firebase. Blocked by: P0.1. Status: Planned.

## P1.1 - Ingestion: Add camera and library input adapters

**Context.** Users need one image input contract regardless of capture source.

**Task.** Return a normalized image draft from native camera or library selection; preserve orientation and support cancellation.

**Acceptance criteria.**

- [ ] Camera and library return the same draft type.
- [ ] Denied camera permission offers photo library and does not trap navigation.
- [ ] Cancel returns without creating an item or uploading media.

Priority: Medium. Owner: data. Labels: data, capture. Blocked by: P0.1. Status: Planned.

## P1.2 - Ingestion: Extract garment candidates with a fallback

**Context.** A full outfit photo must become separate reviewable pieces.

**Task.** Evaluate an available device/hosted approach on consented fixtures, implement the extraction protocol, and provide manual single-item cropping when detection is unavailable.

**Acceptance criteria.**

- [ ] One-garment, multi-garment and no-garment fixtures have recorded results.
- [ ] Candidates have stable IDs and crop/mask references suitable for selection.
- [ ] A failed/empty extraction offers retry and manual import without losing the input.

Priority: Medium. Owner: data. Labels: data, extraction. Blocked by: P0.1. Status: Planned.

## P1.3 - Ingestion: Add candidate verification

**Context.** Users need control over incorrect detections and metadata before saving.

**Task.** Build ExtractionPreview and ClothingDetailsForm against candidate fixtures, emitting only selected validated drafts.

**Acceptance criteria.**

- [ ] Users can deselect each candidate and edit name/category.
- [ ] Confirm is disabled when no valid candidate is selected.
- [ ] Retry and cancel are distinct actions; no repository writes happen inside these views.

Priority: Medium. Owner: data. Labels: data, review-ui. Blocked by: P0.1. Status: Planned.

## P1.4 - Ingestion: Persist confirmed imports

**Context.** Approved drafts must survive relaunch without duplicates after failures.

**Task.** Connect capture, extraction and review to the closet/storage services using stable import IDs and recoverable draft state.

**Acceptance criteria.**

- [ ] Only selected candidates appear in the signed-in owner’s closet after relaunch.
- [ ] A simulated failure after upload retains a retryable draft and cleans up unused media.
- [ ] Retrying the same import produces one record per approved candidate, not duplicates.

Priority: High. Owner: data. Labels: data, integration. Blocked by: P0.2, P0.3, P1.1, P1.2, P1.3. Status: Planned.

## P1.5 - Visualization: Add the categorized closet browser

**Context.** Users need to find and inspect the pieces they imported.

**Task.** Compose reusable ClothingItemCard, CategorySelector and ClosetItemGrid with a separate filtering function and item-detail/delete actions.

**Acceptance criteria.**

- [ ] Tops, Pants and Skirts filter separately while All shows every supplied item.
- [ ] Empty, failed and loading states render with fixtures; retry emits an action.
- [ ] A confirmed delete removes the owned item through the repository and refreshes the grid; failure remains visible.

Priority: Medium. Owner: viz. Labels: viz, closet-ui. Blocked by: P0.1. Status: Planned.

## P2.0 - Data: Implement private outfit persistence

**Context.** The viz canvas needs one adapter for saving owned item placements.

**Task.** Implement OutfitRepository using the shared Outfit schema; keep rendering in viz.

**Acceptance criteria.**

- [ ] Owner-scoped save/list survives relaunch with normalized placement fields intact.
- [ ] A foreign item reference is rejected; a missing/deleted item returns a typed recoverable error.
- [ ] Pagination uses stable cursors and write retries reuse the outfit ID.

Priority: Medium. Owner: data. Labels: data, persistence. Blocked by: P0.3. Status: Planned.

## P2.1 - Visualization: Save a two-dimensional outfit composition

**Context.** Users need reusable outfits assembled from their own pieces.

**Task.** Build item tray and canvas with add/remove, movement and layer ordering; persist normalized placements through OutfitRepository.

**Acceptance criteria.**

- [ ] Reloading a saved outfit preserves item positions, scale and layer order across two canvas sizes.
- [ ] A missing source item is shown as missing and must be removed or replaced before publish.
- [ ] Another user’s item cannot be added through the persistence adapter.

Priority: Medium. Owner: viz. Labels: viz, outfits. Blocked by: P1.5, P2.0. Status: Planned.

## P2.2 - Social: Publish an OOTD snapshot

**Context.** Posts need stable garment breakdowns without exposing private closet media.

**Task.** Create PostRepository.publish for an owned outfit, caption and separate published composite/item media.

**Acceptance criteria.**

- [ ] A successful publish returns a post with author, timestamp and garment display snapshots.
- [ ] Deleting a private source item does not break the published snapshot.
- [ ] A failed upload/write leaves a retryable state and no visible partial post; non-owned outfits are rejected.

Priority: Medium. Owner: social. Labels: social, publishing. Blocked by: P0.3, P2.1. Status: Planned.

## P2.3 - Social: Display the chronological Discovery feed

**Context.** Peers need a predictable way to browse shared outfits and inspect pieces.

**Task.** Compose OutfitPostCard, FeedList and PostClothingBreakdown using a cursor-paginated service.

**Acceptance criteria.**

- [ ] The feed is newest-first with stable tie ordering and pages of at most 20.
- [ ] Loading the next page does not repeat posts.
- [ ] Item breakdown renders published media; empty and retry states are observable with mocks.

Priority: Medium. Owner: social. Labels: social, feed-ui. Blocked by: P0.2, P2.2. Status: Planned.

## P2.4 - Social: Persist saved-post state

**Context.** Users need to keep discovered outfits without importing them as owned garments.

**Task.** Add idempotent save/unsave operations and a saved-post child destination. Run the two-account core demo once integrated.

**Acceptance criteria.**

- [ ] Repeated save creates one owner-private relation; repeated unsave remains successful.
- [ ] Saved state survives relaunch and is isolated between two accounts.
- [ ] Deleted source posts show a removed-content state rather than broken private-media requests.
- [ ] The full import-to-publish-to-save demo in product-scope.md passes with two development accounts.

Priority: Medium. Owner: social. Labels: social, saved-posts. Blocked by: P2.3. Status: Planned.

## P3.1 - Ingestion: Queue Share to Dressed payloads

**Context.** An external share should enter the same reviewed import flow as an in-app photo.

**Task.** Add a share extension for supported image/URL payloads and an App Group queue with draft deduplication, expiry and user-bound consumption.

**Acceptance criteria.**

- [ ] Sharing a supported image creates one reviewable draft in the containing app.
- [ ] Cancel or deselect-all creates no closet item; repeated delivery does not duplicate the draft.
- [ ] Unsupported payloads explain the limitation; a signed-out/user-switched state cannot import into the wrong account.
- [ ] A share-sheet flow is exercised on a simulator or device with a documented supporting source app.

Priority: Medium. Owner: data. Labels: data, share-extension. Blocked by: P1.4. Status: Planned.

## P3.2 - Ingestion: Add product-link and wishlist imports

**Context.** Saved inspiration may be a product link for something the user does not own.

**Task.** Resolve supported public URLs into partial editable drafts and add an explicit closet/wishlist destination. Reuse the confirmation coordinator.

**Acceptance criteria.**

- [ ] A supported fixture yields available name/image/brand and retains its source URL.
- [ ] Unsupported, private and unavailable URLs offer manual input without inventing metadata.
- [ ] Confirmed wishlist imports do not appear in the owned-closet filter.

Priority: Medium. Owner: data. Labels: data, url-import. Blocked by: P1.4. Status: Planned.

## P3.3 - Discovery: Add constrained clothing search

**Context.** Users want to locate published pieces by text/category before visual search is ready.

**Task.** Choose a documented public-content query/index strategy, then add SearchField and results that reuse existing cards.

**Acceptance criteria.**

- [ ] A fixture corpus returns expected results for a supported text query and category filter.
- [ ] Private closet items are never returned for another user.
- [ ] Empty query, no match, pagination and failed lookup have explicit states; product links appear only when present in source data.

Priority: Medium. Owner: social. Labels: social, search. Blocked by: P2.3. Status: Planned.

## PS4.1 - Discovery: Evaluate visual-similarity retrieval

**Context.** Similar-item recommendations need a known corpus and measured quality before product claims.

**Task.** Nicole was named for this work in the team notes; GitHub assignee remains unconfirmed. Timebox to two working days. Use a consented labeled fixture set to compare a visual-embedding baseline with tag matching and propose RecommendationService integration.

**Acceptance criteria.**

- [ ] Report corpus size, provenance, query count, Recall@5, query latency and failure examples for both baselines.
- [ ] Record device/hosted constraints and estimated service cost assumptions.
- [ ] Deliver a go/no-go recommendation and a proposed acceptance threshold for a later implementation ticket; do not claim exact product identification.

Priority: Medium. Owner: data. Labels: data, spike, recommendations. Blocked by: none. Status: Planned.

## P4.2 - Ingestion: Suggest editable category tags

**Context.** Suggested labels can reduce manual input but must remain correctable.

**Task.** Add optional AI/tagging behind a protocol; separate suggestions from user-authored tags and retain manual editing on failure.

**Acceptance criteria.**

- [ ] Suggested categories/tags are visibly editable before persistence.
- [ ] Rejecting a suggestion does not erase user-authored tags.
- [ ] Unavailable tagging leaves a usable manual form; no inference service secret is embedded in the client.

Priority: Low. Owner: data. Labels: data, tagging. Blocked by: P1.4. Status: Planned.

## P4.3 - Visualization: Prototype a two-dimensional avatar canvas

**Context.** The team needs to test movable cut-outs on an avatar before committing to realistic try-on.

**Task.** Add a selectable 2D mannequin/avatar backdrop to the existing outfit canvas and document its limitations.

**Acceptance criteria.**

- [ ] At least two cut-out items can be moved, scaled and layered on the backdrop.
- [ ] Placements round-trip through the existing outfit contract.
- [ ] The demo clearly describes composition rather than sizing/fit prediction; no body scanning or 3D simulation is required.

Priority: Low. Owner: viz. Labels: viz, prototype, avatar. Blocked by: P2.1. Status: Planned.

## P4.4 - Data: Define private tag-preference updates

**Context.** Personalized ranking needs a deliberate event and weighting contract.

**Task.** Review PreferenceEvent and UserPreferences templates and propose explicit event retention, opt-out/reset behavior and deterministic weight updates before integrating tracking.

**Acceptance criteria.**

- [ ] A fixture sequence produces documented bounded tag weights reproducibly.
- [ ] Duplicate events do not double-count; reset removes the user’s derived weights.
- [ ] Collection is off until the product decision is documented; private events never enter public profile records.

Priority: Low. Owner: data. Labels: data, preferences. Blocked by: P0.1, PS4.1. Status: Planned.
