# Design system

Shared tokens and SwiftUI components from the high-fidelity mockups in the
[dressed-design Figma file](https://www.figma.com/design/dpFDiOAb0ytgiTf9blwa3d/dressed-design):
closet (`915:526`), for u (`915:933`), friends (`922:1100`) and share to dressed (`777:6352`).
The Figma file has no published variables, so token values were read from the frames.

## Tokens

| File | Contents |
| --- | --- |
| `DSColor` | Brand purple `#9D83EB`, text, surface and stroke colors |
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

Agents should load the `/dressed-design-system` skill
(`.agents/skills/dressed-design-system/SKILL.md`) before UI work.

## Components

Each file has `#Preview` blocks; open it in Xcode's canvas. `DesignSystemGallery`
shows every component on one screen: preview it, or launch a Debug build with
`-designSystemGallery`.

| Component | Mockup use |
| --- | --- |
| `DSChip` | Closet category pills |
| `DSSegmentedControl` | For You / Friends switch |
| `DSCircleButton` | Profile initial, new-post plus |
| `DSTile` | Closet item and For You photo grid tiles |
| `DSFloatingSearchButton` | "Search Your Closet" / "Search Styles" |
| `DSButtonStyle` (`.ds(.primary/.secondary/.glass)`) | Search, Back, Skip, shop buttons |
| `DSPostCard` | Friends feed card |
| `DSPageIndicator` | Friends carousel dots |
| `DSCandidateRow` | Share-to-Dressed product rows |
| `DSThumbnailSlot`, `DSCropFrame` | Share flow queued pieces and detection frame |

Components are presentational: callers own state, data and actions.
The tab bar stays the native `TabView` in `ContentView`; the mockup's purple active
tab is `DSColor.brand` as its tint. Feature views have not been migrated yet.

## Preview images

`dressed/PreviewContent/PreviewAssets.xcassets` holds the product cutouts from the
mockups (`Preview*` images), downscaled to 600 px. It is listed in
`DEVELOPMENT_ASSET_PATHS`, so Xcode excludes it from archives. Use these images only
in previews and `DesignSystemGallery`. Photos of people from the mockups are not
committed; photo previews use `OutfitPostPlaceholder` until the team has photos it can use.

## Open items

- The mockups are light mode only; dark-mode colors are TBD.
- `DSFont` sizes are fixed and do not scale with Dynamic Type.
- The mockups show an **Avatar** tab, which is not in the current navigation
  (My Closet, Discovery, Camera). Avatars have a separate milestone.
