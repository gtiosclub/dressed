# Firebase Functions (try-on scaffolding)

**Status:** template only — not deployed, not wired from the iOS client. Do not place
service-account keys or OpenAI secrets in this repository.

## Intended responsibilities

| Trigger | Purpose |
| --- | --- |
| `onClosetItemWritten` (Firestore `users/{uid}/closetItems/{itemId}` or Storage object finalize) | When a piece is added or updated, enqueue **bounded** outfit-composite regeneration for outfits that include that item (cap e.g. 20 combinations with the user’s current closet). |
| Callable `requestOutfitComposite` (optional) | Accept `{ wornItemIds[], avatarVersion }`; return or write `users/{uid}/outfitComposites/{hash}` metadata and a Storage PNG path. |

The **client-first** milestone uses lazy `refreshAlignedOutfitComposite` on wear (see
`docs/architecture.md`). This folder documents the optional **power-user batch** path.

## Layout (TODO for lead / backend)

```
backend/functions/
  README.md                 # this file
  onClosetItemWritten.template.mjs
```

Copy the template to your Firebase Functions project, set environment config for OpenAI
server-side only, and deploy from an authorized maintainer machine.

## Metadata contract (draft)

Document id: stable hash of sorted `wornItemIds` + `avatarVersion` + prompt/provider version.

Fields mirror `TryOnOutfit.compositeImagePath` semantics: `storagePath`, `bakedGarmentIDs`,
`processingVersion`, `updatedAt`, `status`.