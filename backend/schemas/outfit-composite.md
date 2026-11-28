# Aligned outfit composite cache

Full-body try-on composites (all visible worn items on the current avatar) are generated
lazily via `refreshAlignedOutfitComposite`. The same combination should not call OpenAI twice
when a valid cache entry exists locally or in Firebase.

## Cache key (stable)

Document id, Storage object name, and local filename all use the same **cache key**:

```
SHA256( sortedGarmentIds.join(",") + "|av:" + avatarVersion + "|pv:" + alignedOutfitProcessing )
```

- `sortedGarmentIds`: unique visible worn closet item ids, lexicographically sorted.
- `avatarVersion`: `TryOnAvatar.version` for the figure used in the render.
- `alignedOutfitProcessing`: `TryOnVersions.alignedOutfitProcessing` (bump when the key inputs change).

Hex-encoded SHA-256 (64 lowercase hex characters).

## Local cache (L1)

- Path: `Application Support/PrototypeCloset/{ownerId}/tryon/outfits/{cacheKey}.png`
- Referenced from `TryOnOutfit.compositeImagePath` when the aligned outfit path is active.

## Firestore metadata (L2 index row)

`users/{ownerId}/outfitComposites/{cacheKey}`

| Field | Type | Notes |
| --- | --- | --- |
| id | string | Same as `cacheKey` |
| cacheKey | string | Stable hash |
| ownerId | string | Closet owner |
| garmentIds | array\<string\> | Sorted ids baked into the PNG |
| avatarId | string? | Avatar record id |
| avatarVersion | int | Must match key input |
| processingVersion | int | `alignedOutfitProcessing` |
| storagePath | string? | Firebase Storage path |
| status | string | `TryOnJobStatus` (e.g. `ready`) |
| createdAt | timestamp | Server on create |
| updatedAt | timestamp | Server on write |

## Cache set (L2 index)

`users/{ownerId}/outfitCacheIndex/index`

| Field | Type | Notes |
| --- | --- | --- |
| id | string | Always `index` |
| schemaVersion | int | `1` |
| ownerId | string | |
| cachedKeys | array\<string\> | `arrayUnion` on each successful upload |
| updatedAt | timestamp | |

## Storage (L2 bytes)

`users/{ownerId}/outfits/{cacheKey}.png` — PNG, ≤ 12 MB, owner read/write.

## Client read order

1. Local L1 file for `cacheKey`
2. If signed in: Firestore metadata + Storage download; validate `garmentIds`, `avatarVersion`, `processingVersion`
3. On miss: OpenAI `composeAlignedOutfit`, then write L1, Storage, Firestore, and index `cachedKeys`

Per-item body-region layers remain under `garmentBodyParts` / `body-part.png`; this contract
is only for **combination** composites.