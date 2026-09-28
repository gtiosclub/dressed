# Architecture and shared contracts

## Observed baseline

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

Everything below is a proposed contract. Confirm details in the lead planning tickets before implementation. Firestore plus Storage is the proposed primary persistence stack; do not build a parallel Realtime Database model merely because that dependency is linked.

## Source organization

Inspired by the shared-code and feature-based MVVM layout inspected in SideQuest. Only Common/Models is added now. Create each feature's Views and ViewModels when its ticket is implemented; no placeholder screens or service implementations are implied.

```text
dressed/
  DressedApp.swift
  ContentView.swift
  Common/
    Models/              shared Codable schema templates (present)
    Firebase/            future Firebase adapters and session service
    Views/               future reusable cards and state views
  Closet/
    Views/
    ViewModels/
  Camera/
    Views/
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

Provide mock success, empty, delayed, no-detection and failed responses before connecting views to Firebase. Review the provided Swift schema templates, optional fields and date handling in lead issue #49. Protocols and mocks remain to be implemented.

## Ingestion state machine

`source selection -> draft received -> processing -> review -> saving -> saved`

Processing can transition to retry or manual crop. Review allows item-level select/deselect and metadata correction. Cancel discards temporary assets. Saving failures retain the draft and selected IDs. Only confirmed items are persisted. The share extension queues an authenticated-user-bound payload in an App Group; it must not assume arbitrary control over the containing app's launch behavior. Expiration, sign-out/user changes and duplicate deliveries must be handled before release.

## Assigning this work

This document explains the broader system, not the expected size of a student task. Leads own unresolved choices and multi-step integrations. Students use the [small-ticket backlog](backlog.md). Follow [officer guidance](officers/README.md) before turning any proposed service into an assignment.

## Approved first implementation path

Photo-library selection and manual name/category entry come first. Views display supplied values and report interactions; view models hold screen state and call functions; Firebase functions perform individual reads/writes; Common/Models defines records. Leads connect these into the first closet flow. Later extraction can supply suggestions to that same form. See [the roadmap](delivery-plan.md).
