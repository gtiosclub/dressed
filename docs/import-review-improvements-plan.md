# Import review improvements and catalog seeding plan

Status: proposal, November 27, 2026. Nothing here is implemented yet. It follows the
camera/upload piece review on `feature/camera-upload-piece-review` (Figma `777:6352`,
`1012:282`, `1253:449`).

## What is wrong today, and why

| Problem seen | Cause in the code |
| --- | --- |
| The beach photo (white blouse, red shorts, headscarf) finds only the top | `GarmentPoseRegions` needs a knee or ankle at 0.35 confidence for a lower piece. That photo scores 0.3 for the left knee and 0 for both ankles, so the shorts are dropped. Pose has no notion of hats, bags or jewelry, so the headscarf can never be found. |
| Matches look unrelated (sunflower jumper for a white blouse) | Catalog images are model/lifestyle photos, so a feature-print comparison mostly compares people and backgrounds. In the simulator Vision cannot run at all, so the "top 3" are the first three titles alphabetically. |
| Pieces saved with white patches and leftover background | The simulator cannot run Apple's foreground mask. The fallback flood fill only works on plain backgrounds and eats skin-coloured and white areas. Body-region boxes are rectangles, not garment shapes. |
| Close button small; search sheet uses a "Cancel" pill | Review uses a 30 pt close; the camera uses a 50 pt glass rounded square. The search sheet uses the default navigation-bar Cancel. |

More catalog products will not make detection better. Detection (finding the pieces in the
photo) depends on the vision model. The catalog only affects matching (which products are
offered for each piece). Plan 1 fixes detection and cutouts; plan 2 fixes matching.

## Plan 1: detection, cutouts and controls

### 1a. Controls (small, do first)
- Close button: reuse the camera's control (50 pt `.ds(.glass)` rounded square, `TablerX`
  24 pt, 9 pt from the left edge) on the piece step and the summary. On the piece step it
  sits over the photo's top-left corner, as in the camera frame.
- Search sheet: replace "Cancel" with the same X button at the top left, as in the closet
  search sheet (`DSSearchSheet`, `976:162`). Reuse `DSSearchSheet`'s pill field instead of
  the labeled form field.
- Test: UI test taps `sharedImport.close` and the search close by identifier; compare
  screenshots with the camera frame.

### 1b. Better detection (garment parsing instead of body boxes)
Replace body-pose rectangles with a clothing-parsing segmentation model. It labels every
pixel (hat, upper clothes, dress, skirt, pants, belt, bag, scarf, left/right shoe, plus
hair, face, arms, legs, background), so it finds the shorts and the headscarf directly and
gives each piece's exact shape.

- Candidate model: SegFormer trained for clothes parsing (for example the public
  `segformer_b2_clothes` weights, 18 labels), converted to Core ML with `coremltools`,
  int8 or palettized (~25–50 MB). B0 is the fallback if B2 is too slow on an iPhone 12.
- **Must check before shipping:** the weights' license and the training data's terms
  (ATR/LIP-style datasets are often research-only). If they do not allow commercial use,
  options are a commercially licensed model, a paid API (Google Vision Object Localization
  is already wired in `backend/recognition`), or training our own. This decision goes to
  the lead before any work starts.
- Pipeline: run the model once per photo; merge labels into pieces (`left/right shoe` →
  Shoes, `upper-clothes` → Top unless a `dress` dominates, drop regions under ~1.5% of the
  image); each piece gets a box (for the review frame) and a mask (for the cutout).
- Keep body pose as the fallback when the model is missing or fails, with two cheap fixes
  that help today: accept a knee at 0.25 confidence for shorts and skirts, and add a
  head-accessory region from the nose/eyes/ears when the classifier sees a hat or scarf.
- Simulator: the Mac bridge (`local_service.py --apple-vision`) runs the same Core ML model
  so development screens match devices.
- Tests: extend `backend/recognition/evaluate.py` with an annotated set of ~30 consented
  development photos (worn outfits, flat lays, single products, dark lighting, cropped).
  Gate: every visible top/bottom/dress found in ≥ 90% of photos; shoes and headwear tracked
  separately; no person/skin returned as a piece. Report per-label misses.

### 1c. Clean cutouts everywhere
- Saved pieces: cut out with the piece's parsing mask (edge feathered 1–2 px, cropped to
  the piece, transparent PNG). Fallback order: parsing mask → Apple foreground mask
  intersected with the piece box → rectangle with no flood fill (a clean rectangle is
  better than a speckled cutout).
- Review step, accepted-piece previews (footer), summary collage, summary rows and closet
  tiles all render that same cutout PNG on the grey tile, `scaledToFit` with padding, so
  they look like the catalog packshots in the frames.
- Product match rows use the catalog cutout from plan 2.
- Tests: unit test that a cutout PNG has transparent corners and a non-empty alpha
  bounding box; screenshot check of the footer preview and closet tile.

### Order and size
1a (half a day) → pose quick fixes (half a day) → license decision → 1b model + pipeline
(3–5 days) → 1c (1–2 days) → device check on an iPhone for speed and memory.

## Plan 2: seed the catalog so matching works

### What "more pieces" should mean
Matching needs (1) clean product images, (2) enough coverage per category, and (3) a
precomputed index so the app compares against thousands of products instead of the first
24 it downloads.

### 2a. Clean product images at ingest
- Extend `backend/catalog/seed_retail_catalog.py`: for each product, pick the packshot from
  its image gallery (the photo with no person; Apple's human detector or the parsing model
  decides), falling back to the first photo.
- Cut it out once on the backend (same mask code as 1c, or a background-removal model),
  store the PNG in Cloud Storage, and add `cutoutImageURL` to `RetailCatalogRecord` and the
  `backend/schemas` example. The app shows `cutoutImageURL` when present.
- Image rights: the current Shopify sources (Princess Polly, tentree, Allbirds, Lucy & Yak)
  publish public product feeds, but storing and showing edited copies needs each source's
  terms reviewed (see `docs/retailer-import-implementation.md`). Livostyle (MIT) and any
  consenting merchant feed are the safe starting set.

### 2b. Coverage
- Target per category for the demo: 150–300 products each for tops, pants, skirts,
  dresses, outerwear and shoes; 100 for accessories (hats, bags, jewelry); about 1,500
  total. Balance colors (black, white, denim, neutrals, brights) so a white blouse has
  white blouses to match.
- Sources in order: Livostyle snapshot → the four Shopify feeds already in
  `seed_retail_catalog.py` (raise `per_category`) → eBay Browse once production access and
  terms allow.
- Load with `upload_catalog_seed.py` into `catalogProducts` in the development Firebase
  project only; production needs lead approval.

### 2c. Matching index
- At ingest, compute an image embedding for each cutout and store it with the product.
  Use one model on both ends so vectors are comparable: either Apple's feature print (the
  app already uses it; run it in the Mac/Swift ingest tool) or a small Core ML CLIP image
  encoder, which also allows text search ("white peasant blouse").
- Ship the index as a small file (1,500 × 512 floats ≈ 3 MB, or 768 bytes each with int8)
  downloaded and cached by the app, or serve it from a Firestore vector-search query. Start
  with the cached file; it needs no new backend.
- In the app, `CatalogVisualMatcher` embeds the piece's cutout (not the rectangle), filters
  by the detected category, and takes the nearest 3. This replaces downloading 24 images
  per piece and stops the alphabetical fallback.
- Simulator: the Mac bridge computes the piece embedding, as it does for detection.
- Tests: for 50 held-out catalog products, photograph-like crops (the product's second
  image) should rank the product itself in the top 3 at least 70% of the time; report
  top-1/top-3 per category.

### Order and size
Livostyle + one Shopify source with packshot selection and cutouts (2 days) → schema and
app change to show `cutoutImageURL` (half a day) → embeddings and cached index (2–3 days) →
scale to ~1,500 products and measure.

## Open decisions (lead)
1. Clothes-parsing model: license OK for the app, or buy/use a hosted service?
2. Which catalog sources may we store edited (cut-out) images from?
3. Ship the matching index in the app (simple, slightly stale) or serve it from the backend?
