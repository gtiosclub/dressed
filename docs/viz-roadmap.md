# Viz roadmap and feature spec

The `viz` team owns the small SwiftUI pieces that let a person browse clothing, arrange an outfit, and inspect saved results. This roadmap follows the same My Closet and Share to Dressed sequence as the [data roadmap](data-roadmap.md). Component screenshots and fixture checks show a view works with supplied input; leads still connect navigation, real records, ownership, and saving. GitHub issues and the viz board remain the source of truth for assignment and status.

## Product outcome and sequence

| Release slice | User-visible result | Handoff |
| --- | --- | --- |
| V1. Browse pieces | A labeled Pieces section displays cards, category choices, and a useful empty state. | Data supplies `[ClothingItem]` and private images; lead connects loading and navigation. |
| V2. Inspect a piece | A tap opens item details, with distinct item-edit and outfit actions. | Lead supplies callbacks, edit/save state, and optional provenance. |
| V3. Build and browse outfits | A user selects pieces, names an outfit, sees its arrangement, and recognizes missing pieces. | Data supplies outfits and placements; lead owns editor state and persistence. |
| V4. Show shared-import results | Approved pieces and the resulting outfit appear in their proper Closet sections. | Lead connects review confirmation and refresh after save. |

The October 19 local prototype may display a simpler Pieces grid and one reviewed piece per image. That is integration work on `main`, not completion of the full V1–V4 component or release criteria below.

## Track C: My Closet

### V1. Pieces list and category controls

**User flow:** My Closet labels **Pieces** and **Outfits** with text. Pieces shows a card for each supplied item with an image, readable name, and category. An empty closet explains how to add a piece. Category choices include every shared `ClothingCategory`; a selected category filters the currently loaded items. A name search can filter loaded items when the lead provides the query state.

**Inputs and outputs:** The card receives an image, name, category, and tap callback. The grid receives a supplied array and reports the tapped item ID. The category control reports a category or `nil` for All. The pure filter returns a new array without mutating input. These views do not fetch records or grant access to private media.

**Tickets:** [#56 item card](https://github.com/gtiosclub/dressed/issues/56), [#73 category choices](https://github.com/gtiosclub/dressed/issues/73), [#74 card grid](https://github.com/gtiosclub/dressed/issues/74), [#75 category filter](https://github.com/gtiosclub/dressed/issues/75), and [#118 sort control](https://github.com/gtiosclub/dressed/issues/118). The lead supplies loading/error/empty screen state and makes a card tap open details.

**Acceptance checks:** Long names remain legible; every category can be chosen; filtering All restores the supplied list; a card tap reports exactly one ID; empty and failed loads are visually distinct. Check the native UI at iPhone and iPad sizes and with larger text.

### V2. Piece details and outfit entry points

**User flow:** Opening a piece shows its own photo, name, category, and any known import-source label. **Edit Item Details** changes the piece. **Add to Outfit** and **Create New Outfit** lead to outfit selection. **Outfits Using This Item** shows supplied outfit previews and a **View All** action.

**Inputs and outputs:** The detail view receives one `ClothingItem`, its image, optional provenance, a supplied outfit preview list, and callbacks. Do not fabricate a retailer link or a source app name from image recognition. A deletion button reports intent; the lead decides warning, persistence, and media cleanup.

**Tickets:** [#116 item detail](https://github.com/gtiosclub/dressed/issues/116) and [#131 outfits using one piece](https://github.com/gtiosclub/dressed/issues/131). Data's [#112 fetch one item](https://github.com/gtiosclub/dressed/issues/112), [#111 update details](https://github.com/gtiosclub/dressed/issues/111), and [#130 filter outfits](https://github.com/gtiosclub/dressed/issues/130) supply the data operations.

**Acceptance checks:** The detail opens the selected ID, labels item and outfit edits differently, hides unknown provenance, reports View All with the item ID, and shows no invented buy link.

### V3. Outfit editor and saved outfits

**User flow:** The user picks owned pieces from a horizontal tray, sees selected rows, arranges them on a simple 2D canvas, names the outfit, saves it, and later opens the same arrangement from an Outfits grid. A one-piece outfit is valid. A deleted source piece produces an explicit missing-item warning instead of an empty image that looks saved correctly.

**Inputs and outputs:** Views render shared `OutfitPlacement` data using normalized positions and sizes. Selection controls report item IDs and placement edits to the lead-owned view model. They do not write outfits directly. Preview cards use private images only inside My Closet.

**Tickets:** [#76 item tray](https://github.com/gtiosclub/dressed/issues/76), [#77 selected-item row](https://github.com/gtiosclub/dressed/issues/77), [#84 preview card](https://github.com/gtiosclub/dressed/issues/84), [#117 name field](https://github.com/gtiosclub/dressed/issues/117), [#119 missing-item warning](https://github.com/gtiosclub/dressed/issues/119), and [#120 saved-outfit grid](https://github.com/gtiosclub/dressed/issues/120). [Lead #58](https://github.com/gtiosclub/dressed/issues/58) connects editor state, ownership checks, and save/reopen behavior.

**Acceptance checks:** A supplied one-piece and two-piece fixture render; selection and removal report the correct IDs once; reopening preserves visual order; missing media or a deleted piece remains obvious; deleting an outfit leaves its source pieces visible.

## Track S: Share to Dressed result

The import review controls belong to `data` and the draft/save coordinator belongs to `lead`. Viz makes the result understandable in My Closet: a confirmed piece appears under Pieces, while the outfit created from approved candidates appears under Outfits. The two sections and their edit actions stay separate. Do not present the original shared image as a public post or imply that a visual suggestion is an exact product.

**Acceptance checks:** After a fixture confirmation, the expected number of pieces appears, each opens the correct detail, and the saved outfit previews only those approved pieces. Canceling review adds no card. Relaunching preserves the same view of saved data once lead persistence is connected.

## Delivery gates and proposed three-sprint sequence

| Sprint | Viz work | Observable review |
| --- | --- | --- |
| 1. Pieces | Finish card, category, grid, filter, then detail with supplied fixtures. | Show empty, populated, filtered, and long-name states. |
| 2. Outfits | Build tray, selected row, name field, saved card/grid, and missing-item warning. | Show one- and two-piece arrangements and a missing source piece. |
| 3. Integration | Connect Pieces/Outfits destinations and details as lead provides real owner-scoped data. | Import result appears in the correct section after relaunch. |

The lead supplies approved sample images and callback signatures before each component starts. A fixture review does not close an end-to-end issue. For native UI changes, build and exercise the affected flow in a simulator or device; report untested states. This roadmap does not assign students or change GitHub status.

## Decisions for Neal and leads

1. Confirm the first outfit canvas layout, minimum edit controls, and appearance when a private image is missing.
2. Decide the item-deletion warning when the piece is used by saved outfits.
3. Decide whether provenance is shown in the first detail release; it needs a separate owner-scoped record and must not extend `ClothingItem`.

See the [data roadmap](data-roadmap.md), [architecture](architecture.md), and [ticket index](github-issues.md) for shared contracts and dependencies.
