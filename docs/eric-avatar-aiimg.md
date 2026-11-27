# Avatar: AI-generated try-on image (plan)

Status: phases 1–2 implemented on `eric-avatar-exp` (uncommitted as of 2026-11-27). Phase 3 not started.
Owner: Eric (`lead` work).

## Implementation status (2026-11-27)

| Piece | Where |
| --- | --- |
| Reference photo, cache, generator protocol, model | `dressed/Avatar/ViewModels/` (`AvatarMediaStore`, `AvatarImageGenerator`, `AvatarTryOnModel`) |
| Avatar tab, settings sheet, generating/reveal views | `dressed/Avatar/Views/` |
| Mac bridge | `backend/avatar/` (see its README) |
| Wiring | `ContentView`: Try On Outfit sets `studio.worn`, switches to the Avatar tab and calls `avatar.generate` |

Decisions taken (the open questions below, answered with the proposed defaults, then revised by Eric):
1. The shirt button opens the bottom piece picker from the mockups (Outfits plus one flat chip per closet
   category, a two-column grid with check marks, and search with Cancel). Closing it generates the look
   for the new pieces. The old Avatar Studio (3D customize and undo/redo) has no entry point now, and its
   four UI tests are skipped. The 3D mannequin stays as the placeholder until a look exists. The
   regenerate button and the explanatory text were removed. Settings no longer explains that the photo
   is sent to OpenAI; this disclosure must be added back before any release.
   The picker also has a **Shop** section listing the shared Firebase catalog (`out-fitted /
   catalogProducts`, about 80 retailer products) through `DiscoveryCatalogSource`. Shop products are worn
   as `ClothingItem`s with a `catalog-` id. They never enter the closet, and their photos download on
   demand and stay in memory. Shop needs a real sign-in; with `-mockSignedIn` the demo catalog has no
   photos, so the chip is hidden. Catalog photos are mostly retailer lifestyle shots with models, and
   their reuse rights are unreviewed (see `backend/catalog/README.md`), so they are fine for a demo but
   not for release. A live run on 2026-11-27 with the real test session tried on a catalog sweater, and
   the generated look took the sweater (plus the model photo's neckerchief).
2. Style: a stylized, semi-realistic "video game avatar" render, not a photograph (bridge prompt v2,
   app cache version 2). The look loads in like the reference video: a pixel mosaic that refines, then a
   blur that sharpens. The lower body fades into a soft brand glow. Full-body output, 1024×1536, model `gpt-image-2.6-sunburst` (OpenAI's documented default for edits
   on 2026-11-27; `gpt-image-1` was shut down on 2026-10-23). `input_fidelity` is not sent because
   the docs do not list it for 2.6. Output is JPEG (quality 90) for speed.
3. Try On Outfit generates immediately. The same photo and pieces come from the cache; Regenerate bypasses it.
4. Simulator and Mac bridge only. Release builds show "not available in this build yet".

Verified: bridge unit tests (9) and app unit tests (`AvatarTryOnModelTests`, 7). UI tests for the try-on
flow with and without a photo ran on iOS 18.4 and iOS 26.4 simulators, through the real bridge in
fixture mode. The UI tests use `-mockSignedIn` and a rendered reference photo
(`-avatarReferenceFixture`), so they are not a real sign-in check. One live OpenAI call (mannequin
reference, jeans and tee) returned a full-body image in about 16 s. One live in-app run on the
iOS 26.4 iPhone 17 Pro Max simulator used Eric's consented test photo (`~/Downloads/test.jpg`, passed with
`-avatarReferencePath`; not in the repo). Try On Outfit on "Easy Denim" produced a full-body look in
15.7 s that kept the person's face and build and showed the closet's navy tee and wide jeans on a
lavender background. Not yet verified: a real test-account sign-in run, picking the photo through
PhotosPicker by hand, and a physical device.

Known gaps: the model sometimes adds shoes that are not in the outfit. There is no history of looks.
Generation is not cancelled when the tab changes, only by Cancel or a new Try On. Five existing UI tests
(`OutfitUndoRedoUITests` tray tests, the post-composer test and the picked-photo test) fail on unmodified
`origin/main` as well.

## Goal

Replace the current procedural 3D mannequin on the Avatar tab with a generated, semi-realistic image of
the user wearing a closet outfit. The user uploads one full-body reference photo in Avatar settings.
Generation uses the OpenAI Images API with that photo plus the outfit's piece photos.

**First demo flow:** Closet → open a saved outfit → **Try On Outfit** → Avatar tab opens and generates
the image of the user in that outfit.

## What exists today (observed)

| Piece | Where | Notes |
| --- | --- | --- |
| Avatar tab (tag 3) | `dressed/ContentView.swift` → `ProfileView` → `AvatarStudioView` | Segmented "Try On / Customize / Full Body" studio with a RealityKit mannequin (`AvatarView`, `AvatarStage`), zoom slider, undo/redo, worn chips. |
| Try-on state | `OutfitStudioModel` in `dressed/Closet/Views/ProfileView.swift` | `worn: [ClothingCategory: ClothingItem]` is in memory with undo history. `look` is saved by `AvatarLookStore` to `Application Support/PrototypeCloset/<ownerId>/avatar.json`. |
| Try On Outfit button | `PrototypeOutfitDetailView` in `dressed/Outfits/Views/PrototypeOutfitViews.swift:221` | Calls `onTryOutfit(outfit)`. `ContentView` maps the outfit placements to `studio.worn` and sets `selectedTab = 3`. **This entry point already exists.** |
| Piece photos | `PrototypeImportStore.image(for:)` | Local files `images/<itemId>.jpg/png` under the owner's prototype closet folder. |
| External calls | `LocalGarmentRecognition` → `backend/recognition/local_service.py` on `127.0.0.1:8765` | DEBUG-only Mac bridge. This is the existing pattern for keeping credentials off the device. |
| Cloud backend | `firebase.json` | Only Firestore and Storage rules. **There are no Cloud Functions.** |
| Settings page | none | The target design's gear button is new. |

## Target UI (from the provided screenshots)

1. **Avatar tab, idle.** A full-bleed avatar fills the area above `DSTabBar` on a white background. Two
   square rounded buttons sit stacked at the top right: gear (`TablerSettings`) and shirt (`TablerShirt`).
   There is no navigation bar, segmented picker or zoom slider. When no image has been generated, the
   grey mannequin placeholder appears.
2. **Shirt button → bottom sheet.** The avatar dims behind the sheet. The sheet has a search icon button
   and horizontally scrolling chips (Outfits, Tops, Jackets, Accessories, …) above a 2-column grid of
   piece cards. Selected cards have a purple border and a check badge.
3. **Search state.** The chip row becomes a "Search Outfits" field with a Cancel button and the
   keyboard is up.

All of this uses the DS tokens and components (`DSColor`, `DSSpacing`, `DSRadius`, the chip and card
components) and Tabler icons. Follow `.agents/skills/dressed-design-system/SKILL.md`.

## Generated look (style target from the reference video)

The reference video works like this. Flat-lay pieces with "Your look is ready" → a pixelated or blurred
reveal with "Pairing the pieces" scan lines → a semi-realistic editorial portrait of the person in the
outfit. The background is soft and pale (lavender/blue/peach gradient) and the lower body fades into it.
A row of piece thumbnails, ‹ › arrows and a dark **Wear this** pill sit at the bottom.

- **Output: a still image.** The motion in the video (head turn, hair) would need image-to-video. The
  OpenAI video API (Sora) restricts input images containing real people's faces, and it is slow and
  costly per clip. **Video is deferred.** We recreate the feel with a client-side reveal animation and
  optionally a slow parallax/Ken Burns drift on the still.
- **Framing:** full body, head to shoes, centred, portrait 2:3 (1024×1536), so shoes and pants are
  visible. (The video crops at the waist; we need the whole outfit.)
- **Style prompt (v1, to tune):** "Semi-realistic editorial fashion portrait of the person in image 1
  wearing exactly the garments in the other images. Preserve their face, hair, skin tone and body
  shape. Full body, standing, relaxed pose, facing camera. Soft diffuse studio light, clean seamless
  pale lavender-to-white background, subtle soft shadow. Clean, polished, slightly illustrative skin
  rendering; not a cartoon; no text, logos or watermarks unless printed on the garment." Store this as
  a versioned constant (`promptVersion`) because changing it invalidates the cache.

## Architecture

```
AvatarTab (SwiftUI)
  └─ AvatarTryOnModel (@MainActor ObservableObject; states below)
       ├─ ReferencePhotoStore   (local, per owner)  — settings upload
       ├─ GeneratedLookCache    (local, per owner)  — PNG + metadata by cache key
       └─ AvatarImageGenerating (protocol, injected)
            ├─ MockAvatarImageGenerator   (previews, XCUITest, offline)
            ├─ LocalBridgeAvatarGenerator (DEBUG: POST 127.0.0.1:8765/avatar)
            └─ (later) CloudAvatarGenerator — Firebase callable; TBD
```

### Where the OpenAI key lives

The key **never goes into the app bundle, plist, source or UserDefaults** (AGENTS.md: no private API
keys in the client).

- **Phase 1 (DEBUG, simulator):** add an `/avatar` route to `backend/recognition/local_service.py`, or a
  sibling `backend/avatar/local_service.py` if it would clutter recognition. It reads `OPENAI_API_KEY`
  from the environment, falling back to `~/.config/dressed/openai.env` (outside the repo, mode 600),
  calls OpenAI and returns the PNG. The key is never committed or logged. A Debug build on a
  device on the same network would need the Mac's LAN address, so the simulator comes first.
- **Later (shippable):** a Firebase callable Cloud Function that holds the key in Secret Manager. It
  enforces auth, a per-user rate limit and a size limit. This needs the Blaze plan and a decision on
  whether reference photos go to Storage. **TBD, discuss with Neal before building.**

### OpenAI call

- Endpoint: `POST /v1/images/edits` (multipart). Image 1 is the reference photo; the rest are the
  outfit's piece photos, max ~6 (tops, bottoms, outerwear, shoes, one accessory). Order the pieces by
  `ClothingCategory.layerOrder` and name each one in the prompt ("image 2: navy t-shirt (top)").
- Model: `gpt-image-2.6-sunburst` (bridge `--model`; `-flare` is the faster option). It is configured
  in the bridge, not the app.
- Params: `size=1024x1536`, `quality=medium` (`--quality high` for demos), `output_format=jpeg`,
  `output_compression=90`, `n=1`. Multiple inputs go in the repeated multipart field `image[]` (max 16).
- Price: the pricing page lists 2.6 image output at $30 per 1M tokens and has no static per-image figure.
  The older `gpt-image-2` figures were $0.041 (medium) and $0.165 (high) per 1024×1536 image.
- Latency is roughly 20–60 s, so the request needs a timeout of ~120 s and must be cancellable.
- Cost: check the current per-image price on OpenAI's pricing page before running many tests. The
  cache below means re-opening the same outfit does not regenerate.
- Downscale inputs on device first (longest side ~1024 px, JPEG ~0.85) to keep uploads small.

### Data and privacy

- **Reference photo:** stored only on the device, with complete file protection, at
  `Application Support/PrototypeCloset/<ownerId>/avatar-reference.jpg`, next to `avatar.json`. It is
  never published or uploaded to Firebase in this phase. Settings shows a one-line notice: "Your photo
  is sent to OpenAI to generate try-on images." There is a **Remove photo** action that also clears the
  generated-image cache.
- **Generated images:** cached at `…/<ownerId>/avatar-looks/<key>.png` with a small JSON index. The key
  is `sha256(referencePhotoHash + sorted itemIds + piece image hashes + promptVersion + model)`.
  Changing the reference photo or any piece invalidates the entry automatically.
- Generated images are private closet media. They are not posted anywhere. Sharing to OOTD is out of
  scope (AGENTS.md: keep private media separate from post snapshots).
- Test only with Eric's own photo or a consented test photo, never real-user data.

### Model states (`AvatarTryOnModel`)

`noReferencePhoto` → `idle(placeholder)` → `generating(progress phase)` → `ready(UIImage)` |
`failed(message, retry)` | `cancelled`.

- `noReferencePhoto`: the placeholder mannequin and a CTA "Add a full-body photo in Settings" that
  opens the gear sheet.
- `generating`: the outfit pieces' thumbnails float in, then the "Pairing the pieces" pixelate/blur
  reveal plays (as in the video) until the image arrives. Navigating away or pressing a new Try On
  cancels the `Task`.
- `ready`: the image goes full-bleed with the bottom fade. A thumbnail row shows the pieces. A
  **Regenerate** action bypasses the cache.
- `failed`: plain message and retry. The bridge's error codes map to user text: offline/bridge down,
  content policy refusal, timeout, rate limit.

## Phased work

**Phase 0: setup (small)**
- [ ] Confirm the model name, params and price on the OpenAI docs; note them in this file.
- [ ] Decide: does the new tab replace `AvatarStudioView`, or does the 3D studio stay reachable (e.g.
  a DEBUG toggle)? See open questions.

**Phase 1: settings and reference photo**
- [ ] `ReferencePhotoStore` (load/save/remove; downscale; per-owner path). Unit tests.
- [ ] Gear button → `AvatarSettingsView` sheet: photo preview, PhotosPicker "Upload full-body photo",
  a guidance line ("Stand facing the camera, full body, plain background, fitted clothes"),
  Remove, and the OpenAI notice.

**Phase 2: generation and Try On Outfit flow (the demo)**
- [ ] `AvatarImageGenerating` protocol + `MockAvatarImageGenerator` (returns a bundled sample after a delay).
- [ ] Bridge `/avatar` route: multipart in → OpenAI → PNG out. It reads the key from the env and
  returns structured errors. Include a fixture mode that runs without a key.
- [ ] `LocalBridgeAvatarGenerator` (DEBUG only, like `LocalGarmentRecognition`).
- [ ] `GeneratedLookCache` with a hash key. Unit tests for key stability and invalidation.
- [ ] `AvatarTryOnModel` with the states above. `onTryOutfit` in `ContentView` sets `studio.worn` and
  switches to tag 3 as it does today, then triggers `generate(for: worn)` (cache hit → instant).
- [ ] New Avatar tab layout: full-bleed image or placeholder, gear + shirt buttons, reveal animation,
  piece thumbnails, Regenerate.

**Phase 3: picker sheet from the screenshots**
- [ ] Shirt button → bottom sheet: chips (Outfits + categories present in the closet), 2-column grid,
  multi-select with check badge, search state with Cancel. Reuse the closet grid/card and `ClothingFilter`.
- [ ] Selecting pieces or an outfit updates `worn`. Generation runs on an explicit **Try on** button,
  not on every tap, to control cost.

**Later / out of scope here**
- Image-to-video motion (Sora or similar), pending the face-input restriction and cost.
- ‹ › history of generated looks and **Wear this** (save as outfit / post).
- Cloud Function + Secret Manager for real devices and other users.

## Verification

- Unit: cache key, reference store, model state transitions with the mock generator (success,
  failure, cancellation, cache hit).
- XCUITest with the mock generator: Closet → outfit → Try On Outfit → Avatar shows the generated
  image; no reference photo → CTA. Report these separately from real auth, per AGENTS.md.
- Manual, in a normally signed simulator build signed in with the documented test account and the bridge
  running with a real key: upload the reference, try on two outfits, check the cache hit on repeat,
  Regenerate, Remove photo. Capture screenshots for the PR.
- Bridge: a Python test for request building and error mapping in fixture mode, with no network.

## Open questions

1. Replace the 3D studio outright, or keep it behind a toggle while this is experimental?
2. Full body (proposed) or waist-up like the video?
3. Auto-generate on Try On Outfit (proposed), or show a "Generate" button first so each call is deliberate?
4. Is the Mac bridge acceptable for the demo, or does it need to run on a physical phone (which needs
   the Cloud Function or a LAN bridge)?
5. Production backend and per-user cost limits: needs a Neal discussion before any student tickets.
