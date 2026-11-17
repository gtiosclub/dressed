---
name: dressed-design-system
description: Build or change Dressed SwiftUI UI with the shared design system tokens, components and Tabler icons in dressed/Common/DesignSystem. Use for any view, screen, component, icon, tab bar, styling, Figma-to-SwiftUI, or design-system work in this repository, including adding a new component, token or icon.
---

# Dressed design system

The design system lives in `dressed/Common/DesignSystem/`. Read its `README.md` first: it lists every token and component, the Figma source frames, and the open items. Then read the components you plan to use. Inspect the real code; the README is a summary, not proof of behavior.

## Figma is the source of truth

When a screen has a Figma frame, match it for **strings, colors, icon colors, component choice and placement**, even when the current app differs. Before editing, call `get_design_context` on the frame and list every visible element with its text, color and position; after editing, compare a simulator screenshot against the frame element by element. Keep existing behavior and data unless the frame requires a change. Record any deviation you cannot avoid (for example, missing data) in the design system README's open items and in your report.

Known mappings:
- The Discovery frames (`915:933` for u, `922:1100` friends) label the sections **For You** (clothing ideas) and **Friends** (OOTD posts).
- Search on mockup screens is a bottom `DSFloatingSearchButton` ("Search Styles", "Search Your Closet") above the tab bar, not a field at the top. Tapping it opens search mode, which shows the text field and suggestions; add `DSFloatingSearchButton.height` plus spacing to the scroll content's bottom padding.
- Header circle buttons are `DSCircleButton`; their icons are `DSColor.iconMuted` (`#6D6D6D`), not black.

## Rules for feature views

- **Tokens, not literals.** Use `DSColor`, `DSSpacing`, `DSRadius`, `DSFont` and `DSShadow` (`.dsShadow(_:)`). Do not add hex values, `Color(red:green:blue:)`, one-off paddings, corner radii or font sizes in feature code. The README's literal-to-token table covers common replacements.
- **Reuse components before writing markup.** A category pill is `DSChip`, a two-way switch is `DSSegmentedControl`, grid squares are `DSTile`, rounded-square buttons use `.buttonStyle(.ds(.primary / .secondary / .glass))`, and so on. Compose them; do not restyle copies.
- **Components stay presentational.** Pass data, bindings and closures in. Loading, persistence and services stay in the feature view model, as `AGENTS.md` requires.
- **One tab bar.** `ContentView` hides the system tab bar and shows `DSTabBar` below the `TabView`. Do not add `.tabItem` or a second bar. New top-level screens go through `DSTabBar`'s items; tab buttons are found in UI tests by `tab.<name>` identifiers, not `app.tabBars`.
- **Tabler icons only.** Every icon comes from [Tabler](https://tabler.io/icons). Never use SF Symbols (`Image(systemName:)`, `systemImage:`, `UIImage(systemName:)`). Use `DSIcon("TablerName", size:)`, or the `tabler:` initializers on `Label`, `Button` and `ContentUnavailableView` in `DSIcon.swift`. Asset icons ignore `.font()`, so set a size that matches the neighbouring text (about 12 for caption, 16 for subheadline, 20 for body; empty states use 48).
- **Light mode only for now.** The mockups have no dark values. Do not invent dark colors; note the gap if a change depends on it.
- **Accessibility.** Icon-only buttons get an `accessibilityLabel`; selected states use `.isSelected`. Keep tap targets at least 43 pt.

## When nothing fits

1. Check whether an existing component can take a parameter or style variant. Extend it in place rather than forking it.
2. Add a new component only when two or more features need it, or the user asks. Otherwise keep the view inside its feature folder, built from tokens.
3. A new component goes in `Components/`, named `DS<Name>`, with a short comment naming its Figma source and at least one `#Preview` covering its states. Add it to `DesignSystemGallery` and the README table.
4. Add a new token only when a design value is used in more than one place and no existing token is within a point or two. Put it in the matching `Tokens/` file with a comment naming where it is used, and update the README.

## Adding an icon

1. Search `dressed/Assets.xcassets` for an existing `Tabler*` image set first.
2. Otherwise find the icon on https://tabler.io/icons and download the official SVG from `https://raw.githubusercontent.com/tabler/tabler-icons/main/icons/<outline|filled>/<name>.svg`. Do not use Figma exports, other icon sets, or redrawn paths.
3. Remove the leading `<!-- ... -->` comment, replace `currentColor` with `#000000`, and add it as `Tabler<PascalName>.imageset` (append `Filled` for the filled style). Copy `Contents.json` from an existing Tabler image set so it keeps `template` rendering and vector data.
4. If Tabler has no fitting icon, ask the user rather than substituting another source.

## Figma

The source file is `dpFDiOAb0ytgiTf9blwa3d` (dressed-design). It has no published variables, so map each value in `get_design_context` output to the nearest token instead of copying raw values. The mockup icons are Tabler icons; identify each by name and add it as above instead of using the Figma SVG. Figma blur values are halved for SwiftUI shadow radii; Figma spread has no SwiftUI equivalent.

## Images

- Previews and `DesignSystemGallery` may use the `Preview*` product cutouts in `dressed/PreviewContent/PreviewAssets.xcassets`. That catalog is development-only; never reference `Preview*` images from feature code.
- Do not commit photos of people from the mockups or the web. Use `OutfitPostPlaceholder` or a photo the team has rights to.
- Downscale new preview images to about 600 px on the long edge before committing.

## Verify

- Build with the simulator command in `AGENTS.md`. A compile pass is not UI verification.
- `grep -rnE --include='*.swift' 'systemName|systemImage' dressed DressedShareExtension` should find only the comment in `DSIcon.swift`.
- UI tests launch with fixture data. If a queued "Review Shared Image" sheet covers the app, earlier test runs left it behind; uninstall the app from the simulator (`xcrun simctl uninstall <UDID> gtiosclub.dressed`) and rerun before treating failures as regressions.
- For component work, run a signed Debug build with the `-designSystemGallery` launch argument and compare a simulator screenshot with the Figma frame. Check that nothing overflows the screen width; a `scaledToFill` image must sit in an overlay over a fixed frame so it cannot widen its parent.
- For feature screens, follow `docs/IOS_DEVELOPMENT.md`, including the real test-account sign-in. Report what you saw and what you could not test.
