# Garment body-part cache

Each closet item with a mappable `TryOnBodySlot` can store one AI-generated **body-region layer**:
a 1024×1536 PNG showing only that slot (torso+top, legs+bottom, feet+shoes, head+accessory) in the
canonical avatar illustration style. Pixels outside the slot are transparent.

## Local cache (implemented)

- Index: `Application Support/PrototypeCloset/{ownerId}/body-parts/index.json`
- Image: `body-parts/images/{itemId}.png`
- Try-on copy: `PrototypeCloset/{ownerId}/tryon/garments/{itemId}/body-part.png` (referenced from `TryOnGarmentAsset.bodyPartImagePath`)

Version fields on `GarmentBodyPartRecord`: `generationVersion`, `promptVersion`, `providerVersion`
(mirrored on the garment asset as `bodyPartGenerationVersion`).

## Firestore

`users/{ownerId}/garmentBodyParts/{itemId}` — metadata for re-download; document id equals closet item id.

## Storage

`users/{ownerId}/items/{itemId}/body-part.png` — PNG bytes (≤ 12 MB). Rules are in-repo; **not deployed** with this change unless separately published.

## Backfill triggers

1. After `PrototypeClosetStore.save` (new or replaced piece).
2. On closet `reload()` when cached layers are missing or version-stale.
3. On Avatar Studio `.task` after the try-on editor attaches (full closet backfill with photos).

## Outfit composites (not per-item factorial)

Full **outfit** images (all worn slots aligned on the avatar) are **not** generated for every
closet upload on device. The client calls `refreshAlignedOutfitComposite` lazily when the user
wears a combination (cache key: sorted worn IDs + avatar version).

Optional server batch: Firebase Function `onClosetItemWritten` (template in
`backend/functions/`) may regenerate up to **N** outfits involving a new piece — a separate
lead milestone. Aligned outfit combination cache is specified in [outfit-composite.md](outfit-composite.md).