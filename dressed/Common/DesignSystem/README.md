# Design system

Shared tokens and SwiftUI components from the high-fidelity mockups in the
[dressed-design Figma file](https://www.figma.com/design/dpFDiOAb0ytgiTf9blwa3d/dressed-design):
closet (`915:526`), closet search (`976:162`), closet outfits (`973:5888`), outfit detail (`1280:421`),
create new outfit (`1273:173`), for u (`915:933`, `1380:337`), friends (`922:1100`), camera (`1012:388`),
share to dressed (`777:6352`, selected state `1012:282`), import (`1253:449`) and the navigation bar (`915:662`).
The Figma file has no published variables, so token values were read from the frames.

## Tokens

| File | Contents |
| --- | --- |
| `DSColor` | Brand purple `#9D83EB`, `brandLight` `#A98BFF` (selected outlines), `destructive` `#D93025` (validation/errors), scrim, camera bar, text, `iconMuted` `#6D6D6D` (inactive tabs, circle-button icons), surface and stroke colors |
| `DSSpacing` | 2, 4, 8, 12, 20 pt |
| `DSRadius` | 5, 8, 12 (crop frame), 16, 26 pt |
| `DSFont` | 16 regular/medium, 14 medium button, 13 medium search, 20 nav title, 11 badge, 10 tab and field label |
| `DSShadow` | raised, floating, card, brand glow, selected tile glow, selected row, and inner shadows (`pressedInner`, `recessedInner`) |

### Raised and pressed controls

Chips and the segmented control have depth in the mockups (`915:526`, `915:933`). Keep both halves:

| State | Surface | Shadow |
| --- | --- | --- |
| Raised: unselected `DSChip`, segment thumb | `DSColor.raised` | `.dsShadow(.raised)`: 25% black, 2 pt downward |
| Pressed: selected `DSChip`, segment track | `DSColor.pressed` with a `pressedBorder` stroke | `.fill(DSColor.pressed.shadow(DSShadow.pressedInner))`: 40% black inner shadow from the top |

The downward offset is intentional; do not center it. The segment thumb fills its 93 x 34 pt segment and labels sit at the capsule's center, with no optical offset.

### Replacing literals

| Instead of | Use |
| --- | --- |
| `Color(hex: 0x9D83EB)`, purple accents | `DSColor.brand` |
| `Color.red`, validation or error text | `DSColor.destructive` |
| `.secondary`, grey captions and dates | `DSColor.textMuted` |
| `Color(.secondarySystemBackground)`, grey tile fill | `DSColor.tile` |
| `.padding(.horizontal, 16)` screen margins | `.padding(.horizontal, DSSpacing.lg)` (20 in the mockups) |
| `spacing: 8` between rows or chips | `DSSpacing.sm` |
| `.cornerRadius(12)` on tiles and cards | `RoundedRectangle(cornerRadius: DSRadius.lg, style: .continuous)` |
| `.font(.headline)` for titles and handles | `DSFont.bodyEmphasis` |
| `.shadow(radius: 4)` | `.dsShadow(.raised)` or `.dsShadow(.card)` |
| `Image(systemName: "heart")` | `DSIcon("TablerHeart", size: 20)` |
| `Label("Save", systemImage: "heart")` | `Label("Save", tabler: "TablerHeart")` |

Agents should load the `/dressed-design-system` skill
(`.agents/skills/dressed-design-system/SKILL.md`) before UI work.

## Components

Each file has `#Preview` blocks; open it in Xcode's canvas. `DesignSystemGallery`
shows every component on one screen: preview it, or launch a Debug build with
`-designSystemGallery`.

| Component | Mockup use |
| --- | --- |
| `DSChip` | Closet category pills; with `icon: "TablerX"`, removable filter chips (Discovery styles); `style: .flat` is the black/grey filter row on Create Outfit |
| `DSSegmentedControl` | For You / Friends switch; the thumb springs with a bounce and a selection haptic |
| `DSCircleButton` | Profile initial, new-post plus |
| `DSTile` | Closet item and For You photo grid tiles; `isHighlighted` is the purple outline on the newest piece, `isChecked` adds the Create Outfit select circle |
| `DSBadge` | "New" on closet tiles, "3 of 3" counter on the share photo |
| `DSSelectionMark` | 24 pt select circle (ring or black check) |
| `DSOutfitCollage` | 2 x 2 outfit preview: closet Outfits grid, outfit detail, import review |
| `DSItemRow` | Piece row with bordered thumbnail and "more" dots: outfit detail, import |
| `DSFloatingActionButton` | Purple 56 pt new-outfit button beside the floating search pill |
| `DSBackHeader` | Chevron and 20 pt title for pushed screens (Outfit Name, Select Items) |
| `DSLabeledField` | Outline text field with small label (Outfit Name) |
| `DSSearchSheet` | Search mode: dimming scrim, white close button, suggestion sheet, pill field. Discovery presents it over the whole screen (`DiscoverySearchOverlay`) |
| `DSCloseButton`, `DSCloseIcon` | The camera's 50 pt glass close control: camera, piece review and its search sheet |
| `DSSearchField` | Bordered floating pill search field used by `DSSearchSheet` and the review search |
| `DSCameraControls` | Upload, shutter and flip inside the translucent capture bar |
| `DSFloatingSearchButton` | "Search Your Closet" / "Search Styles" pinned above the tab bar; opens search mode. Pad scroll content by `DSFloatingSearchButton.height` |
| `DSButtonStyle` (`.ds(.primary/.secondary/.glass/.tile/.text)`) | Search, Back, Skip, Next, shop, close, full-width Import / Create Outfit (put `.frame(maxWidth: .infinity)` on the label, inside the `Button`, not on the button), Find More (`.text`) |
| `DSPostCard` | Friends feed card |
| `DSPageIndicator` | Friends carousel dots |
| `DSCandidateRow` | Share-to-Dressed product rows; `isSelected` adds the purple outline |
| `DSThumbnailSlot`, `DSCropFrame` | Share flow queued pieces and detection frame (`color:` white, or brand once a candidate is selected) |
| `DSTabBar` | Bottom navigation: Closet, Discovery, Avatar, Camera |
| `DSIcon` | Sized Tabler icon, plus `tabler:` initializers for `Label`, `Button`, `ContentUnavailableView` |

Components are presentational: callers own state, data and actions.

## Migrated screens

| Screen | Figma | Notes |
| --- | --- | --- |
| Discovery For You grid (`InfiniteDiscoveryFeed`) | `1380:337` | Photos only: outfit photos plus retailer product photos (no titles or prices; the product page opens on tap), floating "Search Styles" above the tab bar. Friends cards expose comments, likes and outfit details; saving posts is not part of the design. |
| My Closet (`PrototypeClosetView`), outfit detail and Create Outfit (`PrototypeOutfitViews`) | `915:526`, `973:5888`, `1280:421`, `1273:173` | Chip row (Outfits, All, Wishlist, then one per category), `DSTile` piece grid with a "New" badge on the newest piece (added in the last 24 h), `DSOutfitCollage` outfit tiles, floating `Search Your Closet` plus a purple new-outfit button on the Outfits chip, search via `DSSearchSheet`. Outfit detail uses `DSBackHeader` with a trailing `DSMoreMenu` (Delete Outfit, with confirmation; pieces stay in the closet), `DSOutfitCollage` and `DSItemRow` with a `DSMoreMenu` (Try On). Create Outfit: `DSLabeledField`, flat `DSChip`s, `DSTile(isChecked:)`, a Create Outfit button. Tapping a piece still opens `PrototypeItemDetailView` (not restyled). |
| Camera (`CameraCaptureView`, `PrototypeImportView`) | `1012:388` | Full-screen live camera with `DSCameraControls`. Close returns to the previous tab; Upload offers photos (one item or full outfit) or a product link, and goes straight to the existing review sheets. Flip switches front and back cameras. |
| Discovery (`DiscoveryHeader`, `DiscoveryIdeasView`) | `915:933` | For You / Friends header, photo tiles, floating "Search Styles". The one top switch controls `InfiniteDiscoveryFeed`: ranked outfit grid / chronological outfit cards. Its body is not fully migrated yet. |

| Avatar (`AvatarTabView`, `AvatarSettingsView`) | none yet (provided mockups) | Full-bleed generated look, or the 3D mannequin until one exists. Settings and outfit buttons are 50 pt `.ds(.tile)` buttons with `TablerSettings` / `TablerShirt` in `iconMuted`. The outfit button opens the old Avatar Studio in a sheet until the picker sheet from the mockups is built. The generating state uses a soft `brand` radial glow and a "Pairing the pieces" label. See `docs/eric-avatar-aiimg.md`. |
| My profile (`MyProfileView`) | none yet | Opened from the Discovery header's initial circle (`DSCircleButton(.initial)`, first letter of the account name). `DSBackHeader`, `ProfileHeader` with an initial avatar and closet summary, Posts / Followers / Following row, a 3-column grid of the user's posts, and Sign Out (`.ds(.secondary)` with a confirmation). No Figma frame exists; the name comes from the Firebase account (display name, else the email before "@") until a UserProfile service exists. Followers and Following show "–" placeholders, and posts are filtered from the 20 most recent until `PostFunctions` has an author query. |

Other feature views still use their own styling.

## Navigation

`ContentView` keeps a `TabView` so each tab keeps its navigation state, hides the
system tab bar, and places `DSTabBar` below it. On iOS 26 the system bar is a floating
glass bar that cannot match the mockup. `DSTabBar` hides while the keyboard is up, as the
system bar does. Tab tags keep their old values (Closet 0, Discovery 1, Camera 2,
Avatar 3), so launch flags such as `-showCamera` still work; only the display order
follows the mockup. UI tests find tabs by identifier: `tab.closet`, `tab.discovery`,
`tab.avatar`, `tab.camera`.

## Icons

All icons come from [Tabler](https://tabler.io/icons) and live in
`Assets.xcassets` as `Tabler<Name>` template image sets (`…Filled` for the filled
style). SF Symbols are not used. Asset icons do not scale with `.font()`, so `DSIcon`
and the `tabler:` initializers take an explicit size. To add an icon, download the
official SVG from the
[tabler-icons repository](https://github.com/tabler/tabler-icons/tree/main/icons),
strip its header comment, replace `currentColor` with `#000000`, and copy an existing
Tabler image set's `Contents.json`.

## Demo closet

Debug builds fill an empty closet with the cutouts below and two outfits (`DemoClosetSeeder`). Pass `-skipDemoCloset` to start empty; the UI tests do.

## Preview images

`dressed/PreviewContent/PreviewAssets.xcassets` holds the product cutouts from the
mockups (`Preview*` images), downscaled to 600 px. It is listed in
`DEVELOPMENT_ASSET_PATHS`, so Xcode excludes it from archives. Use these images only
in previews and `DesignSystemGallery`. Photos of people from the mockups are not
committed; photo previews use `OutfitPostPlaceholder` until the team has photos it can use.

## Integration on social_main

The November 17 merge keeps the social branch's infinite paging, ranking, retry,
and post-detail implementation. The header's create button uses the existing
composer; demo posts remain local. The November 19 implementation adds live
photo/item publication adapters, with rule deployment and live verification still pending.
Per the user's November 17 correction, the top For You / Friends switch directly
controls the ranked outfit grid and chronological outfit cards. There is no inner
selector. The catalog clothing-ideas view remains in the project but is no longer
the For You destination. This merge reuses Eric's committed styling; an independent
comparison with the live Figma file has not been performed.

## Figma update, November 17

The twelve frames listed at the top were read through `get_design_context`. This pass added the
components above and the `dots` Tabler icon, and kept existing screens unchanged: none of the new
closet, outfit or search screens is migrated to them yet. The camera screen is (see Migrated screens). The component gallery
(`-designSystemGallery`) was checked in a simulator at the top (chips, header, tiles); the sections
below it compile but were not compared to their frames.

## Open items

- Raised chips and the segment thumb have a thin white edge (and a faint inner highlight) in `915:526` and `915:933` that the app does not draw.
- Closet screens are migrated except `PrototypeItemDetailView` (Form layout) and the Wishlist list. Camera and shared-image review follow `777:6352`, `1012:282` and `1253:449`; the multi-photo import review still uses its own styling. Deviations: those frames have no close control, so review places the camera's `DSCloseButton` over the top-left corner (it discards the photo); the outfit name field was dropped to match the import frame (outfits save as "Shared outfit"); a piece with no catalog match shows one "Your photo" row.
- Create Outfit drops the old drag-and-resize arranger: pieces are placed automatically. The Figma filter row starts with "Outfits"; this uses "All" instead because there is nothing to pick from an outfit. Outfit detail keeps a "Try On Outfit" button that is not in the frame. The camera screen uses `DSCameraControls`.
- The camera needs a real device to show a live preview; the simulator shows the "unavailable" message.
  Capture, flip and the live preview were not exercised.
- The camera frame flips with an SF Symbol (`arrow.trianglehead.2.clockwise.rotate.90`); `DSCameraControls`
  uses Tabler Refresh. The mockup's "store" shop button, search-icon glyph in the share frame and the
  `x`/`plus`/`check`/`dots` marks were matched by name to Tabler, not compared pixel by pixel.
- The mockup uses `#A98BFF` for selected outlines and `#9D83EB` elsewhere; both are tokens.
- Closet frames show a floating search pill 293 pt wide beside the FAB; the pill takes the remaining width.

- The Data integration preserves the four-tab navigation and direct Avatar Studio entry, adds outfit persistence to that studio, and uses Tabler icons in the incoming import and saved-post views. These prototype layouts have not had an independent Figma comparison.
- The persistent comment sheet uses shared tokens and button styles. Live Figma
  design-context access was unavailable; an independent frame comparison is pending.

- Saved Posts and the Friends-card save control were removed from the active Discovery flow because they are not present in the approved design.

- The mockups are light mode only; dark-mode colors are TBD.
- `DSFont` sizes are fixed and do not scale with Dynamic Type.
- The product scope still describes three tabs; the app and mockups have four
  (Closet, Discovery, Avatar, Camera). Avatars have a separate milestone.
- Some SF Symbols were replaced by the nearest Tabler icon rather than an exact match,
  for example the garment preset icons in `GarmentPreset.icon`.

- New post now uses a photo picker, `DSBackHeader`, shared buttons, `DSItemRow` and
  selection marks for real closet/saved-outfit tagging. The audio placeholder was
  removed. Live Figma design-context access was unavailable; the functional additions
  have no independent frame comparison.
