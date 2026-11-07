---
name: dressed-design-system
description: Build or change Dressed SwiftUI UI with the shared design system tokens and components in dressed/Common/DesignSystem. Use for any view, screen, component, styling, Figma-to-SwiftUI, or design-system work in this repository, including adding a new component or token.
---

# Dressed design system

The design system lives in `dressed/Common/DesignSystem/`. Read its `README.md` first: it lists every token and component, the Figma source frames, and the open items. Then read the components you plan to use. Inspect the real code; the README is a summary, not proof of behavior.

## Rules for feature views

- **Tokens, not literals.** Use `DSColor`, `DSSpacing`, `DSRadius`, `DSFont` and `DSShadow` (`.dsShadow(_:)`). Do not add hex values, `Color(red:green:blue:)`, one-off paddings, corner radii or font sizes in feature code. The README's literal-to-token table covers common replacements.
- **Reuse components before writing markup.** A category pill is `DSChip`, a two-way switch is `DSSegmentedControl`, grid squares are `DSTile`, rounded-square buttons use `.buttonStyle(.ds(.primary / .secondary / .glass))`, and so on. Compose them; do not restyle copies.
- **Components stay presentational.** Pass data, bindings and closures in. Loading, persistence and services stay in the feature view model, as `AGENTS.md` requires.
- **Navigation stays native.** The tab bar is the `TabView` in `ContentView`; do not build a custom tab bar from the mockups.
- **Light mode only for now.** The mockups have no dark values. Do not invent dark colors; note the gap if a change depends on it.
- **Accessibility.** Icon-only buttons get an `accessibilityLabel`; selected states use `.isSelected`. Keep tap targets at least 43 pt.

## When nothing fits

1. Check whether an existing component can take a parameter or style variant. Extend it in place rather than forking it.
2. Add a new component only when two or more features need it, or the user asks. Otherwise keep the view inside its feature folder, built from tokens.
3. A new component goes in `Components/`, named `DS<Name>`, with a short comment naming its Figma source and at least one `#Preview` covering its states. Add it to `DesignSystemGallery` and the README table.
4. Add a new token only when a design value is used in more than one place and no existing token is within a point or two. Put it in the matching `Tokens/` file with a comment naming where it is used, and update the README.

## Figma

The source file is `dpFDiOAb0ytgiTf9blwa3d` (dressed-design). It has no published variables, so map each value in `get_design_context` output to the nearest token instead of copying raw values. Reuse existing Tabler icons in `Assets.xcassets`; download a Figma asset only when no existing icon matches. Figma blur values are halved for SwiftUI shadow radii; Figma spread has no SwiftUI equivalent.

## Images

- Previews and `DesignSystemGallery` may use the `Preview*` product cutouts in `dressed/PreviewContent/PreviewAssets.xcassets`. That catalog is development-only; never reference `Preview*` images from feature code.
- Do not commit photos of people from the mockups or the web. Use `OutfitPostPlaceholder` or a photo the team has rights to.
- Downscale new preview images to about 600 px on the long edge before committing.

## Verify

- Build with the simulator command in `AGENTS.md`. A compile pass is not UI verification.
- For component work, run a signed Debug build with the `-designSystemGallery` launch argument and compare a simulator screenshot with the Figma frame. Check that nothing overflows the screen width; a `scaledToFill` image must sit in an overlay over a fixed frame so it cannot widen its parent.
- For feature screens, follow `docs/IOS_DEVELOPMENT.md`, including the real test-account sign-in. Report what you saw and what you could not test.
