# Architecture and shared contracts

## Local catalog prototype

`backend/catalog/catalog.py` ingests a synthetic fixture feed into local
SQLite and serves a read-only API on loopback. It records stable product IDs,
changed fields, full versus partial runs, and stale/unavailable status. Discovery
Search now requests that API through an injected client service and shows loading,
empty, error, and retry states. Debug builds accept `-catalogAPIURL` for simulator
checks; release builds use the `CATALOG_API_BASE_URL` build setting. The demo
source uses `.example` URLs and does not fetch retailer pages or offer working
purchase links. Catalog products are separate from private `ClothingItem`
records. On October 12, 2026, the four catalog behavior tests and iOS Simulator
build passed; Discovery Search displayed all three fixture products on iOS
26.2, with category filtering and a no-match search state observed. On October 12,
the network client displayed three products from the loopback API, a server search
returned one sneaker, and stopping the server displayed the retry state. This
is still synthetic local data, not a hosted retailer integration. See
[`backend/catalog/README.md`](../backend/catalog/README.md) for commands.

## Local import prototype in progress

The current `main` working tree contains a local-only import prototype under
`dressed/Camera/ViewModels/PrototypeImportStore.swift`,
`dressed/Camera/Views/PrototypeImportView.swift`, and
`DressedShareExtension/ShareViewController.swift`. A share extension accepts one
supported image from file, data, or UIImage share representations, converts it
to a bounded JPEG, writes a user-bound draft into `group.gtiosclub.dressed`, and tells the
user to open Dressed. Camera and photo-library images enter the same review
screen. Apple's on-device Vision classifier may suggest a category for one
garment in the whole image; no-match and failure states allow manual details.
The user edits the name/category before confirming. Cancelling review keeps a
shared draft queued, with a Camera action to reopen it. Confirmed pieces are
stored as private on-device JPEG and JSON files for the signed-in user. My
Closet supports local search, category filtering, item details, edits, and deletion.

This is a prototype path, not the proposed S1 release flow. It does not extract
multiple separate garments, create an outfit, upload to Firebase Storage, sync
between devices, or enforce cloud ownership. Device signing requires the App
Group capability on both targets. On October 11, 2026, an iPhone 16 Pro iOS
18.6 simulator build passed; a synthetic image shared from Photos appeared in
the extension and then in Dressed's review. A reviewed piece was saved locally
and remained visible after relaunch. The synthetic drawing produced the manual
`other` fallback, so recognition quality on real garment photos is unverified.
On October 12, the integrated app and extension built for iOS Simulator and
the Camera screen opened on an iOS 26.2 iPhone 17 Pro simulator. The revised
closet detail, name edit, and category empty-result interaction were exercised
on an iOS 18.6 iPhone 16 Pro simulator with a synthetic saved shirt. The revised
photo review, share cancellation, and closet deletion interactions have not yet
been verified on a device or in a complete native UI walkthrough.
The six-field `ClothingItem` contract is unchanged; the local image path is a
prototype storage reference.

## Observed baseline

Issue #50 adds a session-aware shell: the root waits for Firebase Auth's initial
state, shows the existing sign-in screen when signed out, and shows My Closet,
Discovery, and Camera tabs when signed in. Discovery has Feed and Search
sections. These tabs contain honest empty/coming-soon states; closet, feed,
search, and import behavior still belong to their own tickets. Signing out
returns to authentication and discards the tab view's user-specific state.
The session service is injected, with local preview sessions for both states.
Debug builds can launch with `-mockSession` for a synthetic sign-in and
sign-out walkthrough without contacting Auth.

The original baseline below describes the project before #50:

As of commit `5c10212`:

- `dressed.xcodeproj` is at the repository root. Swift and assets live in `dressed/`.
- `dressed/DressedApp.swift` configures Firebase once at launch.
- `dressed/ContentView.swift` displays `Authentication` from `dressed/firebase/AuthPage.swift`.
- Email/password sign-in and account creation exist; success prints to the console. There is no authenticated tab shell yet.
- Firebase packages include Core, Auth, Storage, Firestore, Database, AI and AILogic. Linking a package does not mean its service is provisioned or used.
- The client Firebase plist is present and matches `gtiosclub.dressed`. Xcode 26.6 and an iOS 26.5 simulator built the project during setup.
- Closet models, persistence services, extraction, share extension, feed, search, avatars and recommendation logic are not implemented in this baseline.
- Firestore/Storage rules, indexes and a backend smoke flow have not been verified.

The current planning branch adds schema-only Codable types in `dressed/Common/Models` and JSON examples under `backend/schemas`; these do not implement persistence or features. The model definitions are the canonical field source, including the six required fields on ClothingItem.

The access-rules work added Firestore and Storage rules with emulator tests for synthetic users. Firestore rules were published to `out-fitted` on September 28, 2026; live Rules Playground simulations confirmed owner and non-owner read decisions. Storage rules remain local because live Storage is unavailable. See [Firebase testing](officers/firebase-testing.md) before assigning live database work.

Everything below is a proposed contract. Confirm details in the lead planning tickets before implementation. Firestore plus Storage is the proposed primary persistence stack; do not build a parallel Realtime Database model merely because that dependency is linked.

## Source organization

Inspired by the shared-code and feature-based MVVM layout inspected in SideQuest. `Common/Models` holds the shared records. The first Camera and Closet view files and the clothing/outfit Firebase files were created for linked student tickets. `ImportCandidateRow` renders a candidate review row; `ClothingFunctions` and `OutfitFunctions` now include default owner-scoped Firestore save and fetch operations. These components do not constitute a complete import or closet flow. Create other feature folders when their tickets are implemented.

```text
dressed/
  DressedApp.swift
  ContentView.swift
  Common/
    Models/              shared Codable schema templates (present)
    Firebase/            clothing/outfit Firestore save/fetch (present); future session service
    Views/               future reusable cards and state views
  Closet/
    Views/               starter ClothingItemCard and CategorySelector (present)
    ViewModels/
  Camera/
    Views/               ChoosePhotoButton and ImportCandidateRow (present)
    ViewModels/
  Outfits/
    Views/
    ViewModels/
  Discovery/
    Views/
    ViewModels/
  Profile/
    Views/
    ViewModels/
  firebase/AuthPage.swift existing authentication, retained for now
backend/schemas/          JSON examples, contract map, validation harness
```

Use descriptive `View` and `ViewModel` suffixes consistently in new code. Existing filenames remain authoritative until explicitly moved. Views render state and emit actions; view models coordinate state; injected service adapters perform I/O. Previews use fixtures and do not access production Firebase. Team names are ownership labels, not duplicate model hierarchies. SideQuest's branch policy is not adopted by reference.

## Proposed data model

For the first closet milestone, `ClothingItem` has six fields and no schema version. Other proposed records currently have `schemaVersion: 1`; leads must decide their migration policy before those records are stored. Owned records have `ownerId` (posts use `authorId`). Write timestamps with server timestamps, decoding them to dates in domain models. Use Storage object paths as canonical media references instead of assuming a permanent download URL. Keep UI selection, loading, drag gestures and temporary errors out of persisted entities.

| Entity | Minimum fields beyond ID/version | Visibility |
| --- | --- | --- |
| UserProfile | username, displayName, avatarPath?, createdAt | Signed-in community profile; no email or measurements |
| ClothingItem | ownerId, name, category, imagePath, createdAt | Owner only |
| Outfit | ownerId, name?, placements, createdAt, updatedAt | Owner only |
| Post | authorId, caption, outfitSnapshot, mediaPath, createdAt | Signed-in community |
| SavedPost | ownerId, postId, createdAt | Owner only |
| ImportDraft | ownerId, payload kind, temporary media, candidates, status, importId | Local/private draft, not a published post |
| Avatar, later | ownerId, appearance parameters, optional measurements with units | Owner only |
| PreferenceEvent, later | ownerId, event type, target type/ID, occurredAt | Owner only |

`category`: `tops`, `pants`, `skirts`, `dresses`, `shoes`, `outerwear`, `accessories`, `other`.

Wishlist destinations and import-source metadata belong to later import work in `ImportSchema.swift`. They are not required to save a manual closet item.

`placements`: array of item ID, normalized center x/y, normalized width, rotation in degrees, and layer order. Store a placement schema version with the outfit. Render using aspect ratio; avoid saving device-specific point coordinates.

### Reference and deletion policy

Private outfits reference owned clothing IDs. If a clothing item is deleted, the editor shows a missing-item state and asks the user to remove or replace it before publishing. A published post contains a snapshot of the garment display metadata and separate publishable media. Saving a post creates a relationship, not a copy into the user's closet. If the author deletes a post, it disappears from saved-post results with a removed-content state.

Do not make private closet objects public to support feed images. Generate separate post media only with the user's publish action. Define media deletion and orphan cleanup before enabling post deletion. A public snapshot must not contain the original full-resolution capture, body measurements, email or other private metadata.

### Example serialized item

Illustrative JSON representation; production Firestore timestamps use its timestamp type.

```json
{
  "id": "item_001",
  "ownerId": "user_a",
  "name": "Blue shirt",
  "category": "tops",
  "imagePath": "users/user_a/items/item_001/original.jpg",
  "createdAt": "2026-09-28T19:00:00Z"
}
```

### Example published snapshot

```json
{
  "id": "post_001",
  "schemaVersion": 1,
  "authorId": "user_a",
  "caption": "Today's outfit",
  "mediaPath": "posts/user_a/post_001/composite.jpg",
  "outfitSnapshot": {
    "name": "Monday",
    "items": [{"sourceItemId": "item_001", "name": "Blue shirt", "category": "tops", "mediaPath": "posts/user_a/post_001/item_001.png"}]
  },
  "createdAt": "2026-09-28T19:10:00Z"
}
```

## Proposed backend paths

- `users/{uid}`: community-safe profile fields only.
- `users/{uid}/items/{itemId}` and `users/{uid}/outfits/{outfitId}`: private ownership-scoped records.
- `users/{uid}/savedPosts/{postId}`: deterministic IDs for idempotent save/unsave.
- `posts/{postId}`: publishable snapshots readable by signed-in users, author-writable.
- Storage `users/{uid}/items/{itemId}/...`: private item media.
- Storage `posts/{uid}/{postId}/...`: separately published media under author ownership.

Rules must check auth, ownership, immutable owner IDs, allowed fields and media ownership. Client filtering is not authorization. Cross-user read/write tests, reference validation, storage MIME/size limits and cleanup behavior are foundation deliverables, not assumptions. Storage and Firestore writes are not one atomic operation; retry with stable import/item IDs and compensate for failed metadata writes.

Feed query: order by createdAt descending with document ID as a tie breaker, limit 20, cursor pagination. Declare and version any indexes the chosen queries require. Search starts with a documented constrained query contract; arbitrary substring/full-text search is not assumed to be provided by the database.

## Proposed service boundaries

Every I/O operation is `async throws`. Authentication comes from the session; a caller-supplied owner ID never grants authorization. Return typed domain errors such as unauthenticated, forbidden, invalidInput, unsupportedSource, noDetection, offline and unavailable. Cancellation must stop UI work and avoid publishing partial results.

| Service | Operations and outputs | Contract |
| --- | --- | --- |
| SessionStore | observe user, sign in/out | Clear cached private data when user changes |
| ClosetRepository | list(category?, cursor) -> page; save(draft, importId) -> item; delete(id) | Owner scope; stable IDs make retries safe |
| ExtractionService | extract(image) -> candidates | Candidate IDs, crop/mask, suggested category/tags; empty result recoverable |
| StorageService | upload(image, ownedPath) -> media reference; delete(reference) | Typed media validation and cleanup |
| OutfitRepository | save(placements, name?) -> outfit; list(cursor) -> page | Validate item ownership and missing references |
| PostRepository | publish(outfitId, caption) -> post; feed(cursor) -> page; delete(id) | Create authorized snapshot; no private media references |
| SavedPostRepository | setSaved(postId, Bool); list(cursor) -> page | Idempotent relation; handle deleted post |
| UserRepository | getProfile(id); updateOwnProfile(draft) | Separate profile from auth credentials |
| ImportCoordinator, next | accept(payload) -> draft; confirm(selectedDrafts) -> items | Share, camera and library reuse confirmation/persistence |
| SearchService, next | search(query, filters, cursor) -> result page | Explicit dataset and supported matching semantics |
| RecommendationService, later | similar(item/image, limit) -> scored candidates | Corpus IDs, score, provenance, and optional verified product URL |

Provide mock success, empty, delayed, no-detection and failed responses before connecting views to Firebase. Review the provided Swift schema templates, optional fields and date handling in lead issue #49. The clothing and outfit function protocols include default Firestore save/fetch implementations. Dependency-injected mocks and the broader import and closet flows remain to be implemented.

## Ingestion state machine

`source selection -> draft received -> processing -> review -> saving -> saved`

Processing can transition to retry or manual crop. Review allows item-level select/deselect and metadata correction. Cancel discards temporary assets. Saving failures retain the draft and selected IDs. Only confirmed items are persisted. The share extension queues an authenticated-user-bound payload in an App Group; it must not assume arbitrary control over the containing app's launch behavior. Expiration, sign-out/user changes and duplicate deliveries must be handled before release.

## Assigning this work

This document explains the broader system, not the expected size of a student task. Leads own unresolved choices and multi-step integrations. Students use the [small-ticket backlog](backlog.md). Follow [officer guidance](officers/README.md) before turning any proposed service into an assignment.

## Approved first implementation path

Photo-library selection and manual name/category entry come first. Views display supplied values and report interactions; view models hold screen state and call functions; Firebase functions perform individual reads/writes; Common/Models defines records. Leads connect these into the first closet flow. Later extraction can supply suggestions to that same form. See [the roadmap](delivery-plan.md).
