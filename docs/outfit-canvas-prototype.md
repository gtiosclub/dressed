# Outfit canvas prototype handoff

## Interaction comparison

| Approach | Strengths | Risks and access |
| --- | --- | --- |
| Drag the garment directly | Fast and spatial; the garment follows the finger. | Small or overlapping pieces can be hard to grab, and an unintended drag can change placement. Keep normalized positions clamped to the canvas. |
| Select a garment, then use controls | The size slider and layer buttons are explicit, discoverable, and usable with VoiceOver and Switch Control. | Takes more taps and requires a visible selected state. |

The prototype combines both: drag to move, tap to select, then use the size slider and **Send backward / Bring forward** controls. A selection outline and an editing label make the target clear before adjustments. Ordering controls are discrete swaps, which reduces accidental large changes. Rotation is deliberately not included in this first interaction pass.

## Fixture

`OutfitCanvasFixture` in `dressed/Outfits/Views/PrototypeOutfitViews.swift` supplies one and two-piece data using stable fixture IDs, `ClothingItem`, and normalized `OutfitPlacement` values. The two-piece case overlaps the blue shirt over dark pants so the layer order is visible. Fixture image paths are placeholders; the canvas shows its missing-photo fallback until image assets are supplied.

## Parent integration contract

- The parent owns `[OutfitPlacement]` and supplies a stable `itemId` per placement. This view does not save, mutate shared schema, or invent IDs.
- On every drag, resize, or layer action, the binding reports updated normalized `centerX`, `centerY`, `width`, and integer `layer`. Positions remain within the canvas and width remains between 0.2 and 0.8 in this editor.
- `layer` is rendered from lowest to highest; layer controls swap adjacent pieces and rewrite consecutive layer values. Reopening from those values restores the same visible order.
- Removing a selected item from the parent placement array should clear its selection. A missing closet item remains represented by the warning marker already used by the canvas.
- Production integration still needs the parent to decide persistence timing and validate item ownership before save (see Lead #58).
