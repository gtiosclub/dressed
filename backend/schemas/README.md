# Backend schema templates

These are contract templates, not deployed collections, security rules, services or migrations. The canonical field definitions are the Foundation-only Codable structs in [`dressed/Common/Models`](../../dressed/Common/Models). All three teams share them. Do not create separate client/backend copies of the same model.

`examples.json` contains synthetic version-1 examples. Dates are ISO-8601 JSON strings; future Firestore adapters must explicitly map Date to/from Timestamp, use server timestamps for writes, and handle pending timestamps. Codable itself does not enforce auth, reference ownership, schema migrations, numeric ranges or URL safety. Those checks belong to the remaining tickets.

| Record | Proposed location | Primary contract owner | Access intent |
| --- | --- | --- | --- |
| UserProfile | users/{uid} | social | Signed-in community; owner writes |
| ClothingItem | users/{uid}/items/{id} | data | Owner only |
| ImportDraft | App Group/local draft store | data | Auth-bound, expires, never published |
| Outfit | users/{uid}/outfits/{id} | viz | Owner only; data implements persistence |
| Avatar | users/{uid}/private/avatar | viz | Owner only, later phase |
| Post | posts/{id} | social | Signed-in community; author publishes |
| SavedPost | users/{uid}/savedPosts/{postId} | social | Owner only |
| Follow | users/{uid}/following/{targetUid} | social | Owner write; read audience to be decided |
| PreferenceEvent | users/{uid}/preferenceEvents/{id} | data | Owner only; later phase |
| UserPreferences | users/{uid}/private/preferences | data | Owner only; later phase |
| AppNotification | users/{uid}/notifications/{id} | social | Recipient read; trusted creation, later phase |
| Challenge | challenges/{id} | social | Community read; organizer write, later phase |
| ChallengeSubmission | challenges/{id}/submissions/{uid} | social | Owner submission of owned published post |
| OutfitRecommendation, SimilarItemResult | Service responses | data | Not stored by this template |

`schemaVersion` is explicitly required for persisted records. Reject unsupported versions until an explicit migration is implemented. ID fields must agree with document IDs; owner/author IDs are immutable. Timestamps, category/source enums and private/public media boundaries must be validated before use. Avatar measurements use centimeters and remain private.

Storage paths: private originals/cut-outs under `users/{uid}/items/{id}/`; published copies under `posts/{uid}/{postId}/`. Notifications must not be arbitrarily created by a recipient pretending another user acted. Challenge submissions require ownership checks. No rules or indexes are deployed by adding these files.

Templates cover the currently named entities, including deferred follows, preferences, avatars and engagement. Optional future features such as comments/likes, AR or body scans still need approved contracts before implementation. No functioning feature or server is implied by a schema file.

## Validate the JSON contracts locally

From the repository root, using the installed Xcode Swift toolchain:

```sh
xcrun swiftc dressed/Common/Models/*.swift backend/schemas/ValidateSchemas.swift -o /private/tmp/dressed-schema-check
/private/tmp/dressed-schema-check backend/schemas/examples.json
```

The harness checks every top-level example for lossless Codable round-trip and rejects an unknown clothing category and a missing owner. It does not test Firestore access rules, migrations or business validation, which remain separate work.

## Starter templates

Use the [template kit](../../templates/README.md) for copyable schema, repository, view, view-model and ticket starters. Keep placeholders out of compiled targets and fill only the scope of the chosen ticket.
