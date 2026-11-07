# Design system

Shared tokens and SwiftUI components from the high-fidelity mockups in the
[dressed-design Figma file](https://www.figma.com/design/dpFDiOAb0ytgiTf9blwa3d/dressed-design):
closet (`915:526`), for u (`915:933`), friends (`922:1100`), share to dressed (`777:6352`)
and the navigation bar (`915:662`).
The Figma file has no published variables, so token values were read from the frames.

## Tokens

| File | Contents |
| --- | --- |
| `DSColor` | Brand purple `#9D83EB`, text, `iconMuted` `#6D6D6D` (inactive tabs, circle-button icons), surface and stroke colors |
| `DSSpacing` | 2, 4, 8, 12, 20 pt |
| `DSRadius` | 5, 16, 26, 30 pt |
| `DSFont` | 16 regular/medium, 14 medium button, 13 medium search, 10 tab |
| `DSShadow` | raised, floating, card, brand glow, and two inner shadows |

### Replacing literals

| Instead of | Use |
| --- | --- |
| `Color(hex: 0x9D83EB)`, purple accents | `DSColor.brand` |
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
| `DSChip` | Closet category pills; with `icon: "TablerX"`, removable filter chips (Discovery styles) |
| `DSSegmentedControl` | For You / Friends switch |
| `DSCircleButton` | Profile initial, new-post plus |
| `DSTile` | Closet item and For You photo grid tiles |
| `DSFloatingSearchButton` | "Search Your Closet" / "Search Styles" pinned above the tab bar; opens search mode. Pad scroll content by `DSFloatingSearchButton.height` |
| `DSButtonStyle` (`.ds(.primary/.secondary/.glass)`) | Search, Back, Skip, shop buttons |
| `DSPostCard` | Friends feed card |
| `DSPageIndicator` | Friends carousel dots |
| `DSCandidateRow` | Share-to-Dressed product rows |
| `DSThumbnailSlot`, `DSCropFrame` | Share flow queued pieces and detection frame |
| `DSTabBar` | Bottom navigation: Closet, Discovery, Avatar, Camera |
| `DSIcon` | Sized Tabler icon, plus `tabler:` initializers for `Label`, `Button`, `ContentUnavailableView` |

Components are presentational: callers own state, data and actions.

## Migrated screens

| Screen | Figma | Notes |
| --- | --- | --- |
| Discovery (`DiscoveryHeader`, `DiscoveryIdeasView`) | `915:933` | For You / Friends header, photo tiles, floating "Search Styles". The Friends feed (`OOTDFeedView`) body is not migrated yet. |

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

## Preview images

`dressed/PreviewContent/PreviewAssets.xcassets` holds the product cutouts from the
mockups (`Preview*` images), downscaled to 600 px. It is listed in
`DEVELOPMENT_ASSET_PATHS`, so Xcode excludes it from archives. Use these images only
in previews and `DesignSystemGallery`. Photos of people from the mockups are not
committed; photo previews use `OutfitPostPlaceholder` until the team has photos it can use.

## Open items

- The Discovery header shows a profile icon where the mockup shows the user's initial;
  the session does not expose a display name yet.
- The mockups are light mode only; dark-mode colors are TBD.
- `DSFont` sizes are fixed and do not scale with Dynamic Type.
- The product scope still describes three tabs; the app and mockups have four
  (Closet, Discovery, Avatar, Camera). Avatars have a separate milestone.
- Some SF Symbols were replaced by the nearest Tabler icon rather than an exact match,
  for example the garment preset icons in `GarmentPreset.icon`.
