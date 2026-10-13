# Data roadmap and feature spec

This roadmap has two active workstreams: **My Closet** (pieces and saved outfits) and **Share to Dressed** (turn a shared image into extracted pieces and an outfit). Share to Dressed extracts candidates automatically, but saves only after the user reviews and confirms them. The supplied mockups define the intended navigation and review moments. They do not imply that those screens, the share extension, or recognition already run. GitHub issues and the [data board](https://github.com/orgs/gtiosclub/projects/74) are the source of truth for assignment and status.

## Product outcome and sequence

| Release slice | User-visible result | Why it comes first |
| --- | --- | --- |
| C1. Pieces in My Closet | Select a photo, enter a name and category, save one piece, and find it after relaunch. | Establishes the owned item and private image path used by both tracks. |
| C2. Saved outfits | Select owned pieces, save their arrangement, reopen an outfit, and see which outfits use a piece. | Establishes the outfit contract that shared imports will reuse. |
| S1. Share to Dressed | Share a supported image, automatically extract garment candidates, review them, then save the approved pieces and one outfit together. | Delivers the second full user journey without creating a parallel closet or outfit model. |

Work on the share intake and recognition contract can proceed while C1/C2 integration is underway. S1 cannot claim completion until it can save through the same owner-scoped item and outfit paths. A fixture extractor is useful for development, but the S1 release gate includes a working recognition approach selected in [lead issue #53](https://github.com/gtiosclub/dressed/issues/53).

## Track C: My Closet

### C1. Pieces

**Navigation and user flow:** My Closet has two clearly labeled sections inside the same tab: **Pieces** and **Outfits**. “Saved Outfits” gets text beside a recognizable icon instead of an icon alone. From Camera or My Closet, the user selects one garment photo, sees it before saving, enters a name and category, and confirms. Pieces shows the new item. Tapping a card opens its detail view; the user can edit its name/category or delete it. Use a category dropdown/menu that covers every `ClothingCategory`; a few visible quick filters may remain if they fit. Search matches piece names among the currently loaded items for the first version; server-side search is a separate decision if the closet outgrows that approach.

**Data contract:** Use the agreed six-field `ClothingItem`: `id`, `ownerId`, `name`, `category`, `imagePath`, and `createdAt`. Its image lives under a private owner path. The mockup's extra chips such as color, fabric, and style are design examples, not existing `ClothingItem` fields. Additional tags require a separate contract decision. The detail view should show the import source when available (for example, Photo Library or Shared Image). Persist that separately as owner-scoped provenance keyed to the item; do not add it to the six-field first-milestone record or require it in the basic save/fetch functions. Display an external app name only when the share payload provides a trustworthy identity. A buy link requires a verified product URL and a later contract; an image match alone is not a product source.

**Required states:** Empty closet, loading, failed load with retry, denied photo access, selected photo, saving, save failure with a retained draft, and successful return to the grid. Canceling before confirmation leaves no item. Repeating a failed save uses the same item/import ID so it does not create duplicates; a partial upload is cleaned up or retained for a safe retry.

**Tickets and handoff:** Data pieces are [photo button #52](https://github.com/gtiosclub/dressed/issues/52), [photo preview #114](https://github.com/gtiosclub/dressed/issues/114), [details form #82](https://github.com/gtiosclub/dressed/issues/82), [image upload #72](https://github.com/gtiosclub/dressed/issues/72), [save #70](https://github.com/gtiosclub/dressed/issues/70), [list #71](https://github.com/gtiosclub/dressed/issues/71), [fetch one #112](https://github.com/gtiosclub/dressed/issues/112), and [update details #111](https://github.com/gtiosclub/dressed/issues/111). `viz` owns the grid, filters, and detail views. [Lead issue #55](https://github.com/gtiosclub/dressed/issues/55) connects the full flow. #52 is unassigned in Backlog as of October 10, 2026.

**Acceptance checks:**

- Account A saves one photo with name and category, relaunches, and sees the same piece and image.
- The Pieces and Outfits sections have visible text labels. The category menu includes every category; category filtering and name search return the expected cards.
- Opening a piece shows its own record and an import-source label when provenance exists. An item without known provenance shows no invented source or buy link.
- Editing changes only name/category. Deleting a piece removes it from the closet and follows the agreed media cleanup policy.
- An interrupted or retried save never creates two pieces. Account B cannot read or change A's private record or image.

### C2. Outfits

**User flow:** The labeled Outfits section opens the user's saved-outfit list. From a piece detail, “Add to Outfit” selects that piece and “Create New Outfit” starts an outfit with it. The user adds or removes owned pieces, arranges them, saves, then reopens the same arrangement. A one-piece outfit is valid. The piece detail labels its edit action **Edit Item Details**; editing an outfit is a separate action in the outfit editor. An **Outfits Using This Item** section shows a horizontal row of outfit snapshots and a **View All** action. For the first version, filter the already fetched outfits by item ID; define pagination or an index before relying on this for a large closet.

**Data contract:** Reuse the shared `Outfit` and `OutfitPlacement` types: owner ID, optional name, placement schema version, item IDs, normalized positions/sizes, rotation, and layer order. An outfit stores references to owned items; it does not copy private item images into a public record. Snapshot cards can be rendered from the saved placements and private item images; the current `Outfit` schema has no stored preview image field. Leads need to define the empty/missing-image appearance and performance limit for that rendering.

**Required states:** No outfits, editing, saving, saved, load failure, and a missing/deleted piece warning. If a referenced piece is gone, let the user remove or replace it before publishing. Deleting an outfit must leave its pieces and photos intact.

**Tickets and handoff:** Data work is [save outfit #57](https://github.com/gtiosclub/dressed/issues/57), [fetch outfits #83](https://github.com/gtiosclub/dressed/issues/83), [delete outfit #113](https://github.com/gtiosclub/dressed/issues/113), and [filter outfits by item #130](https://github.com/gtiosclub/dressed/issues/130). `viz` supplies the item tray, selected-item row, saved-outfit card/grid, [outfits-using-item row #131](https://github.com/gtiosclub/dressed/issues/131), and missing-item warning. [Lead issue #58](https://github.com/gtiosclub/dressed/issues/58) owns editor integration and validation that every referenced item belongs to the user.

**Acceptance checks:**

- Account A saves an outfit with two owned pieces, relaunches, and sees the same pieces and placement order.
- Each piece detail lists outfits that use its ID. An unrelated piece lists none.
- Outfits using a piece appear as a horizontal snapshot row; View All opens the complete filtered list. Edit Item Details changes the piece, while Edit Outfit opens the outfit editor.
- Saving with a missing or another user's item ID fails with a clear message.
- Removing an outfit leaves both source pieces in My Closet. A deleted source piece produces a visible missing-item state in an existing outfit.

## Track S: Share to Dressed

### S1. Intake and draft

**User flow:** A supported external app offers Dressed in the iOS share sheet. The first release accepts images only. The share extension receives a supported image, creates a private draft, and hands it to the signed-in app's import review flow. The Camera/photo-library flow may create the same kind of draft. The extension must not assume it can force the main app to open. For a URL, inaccessible image, expired draft, or signed-out user, show a recoverable message rather than silently saving anything. URL and product-link support can be specified later in [#63](https://github.com/gtiosclub/dressed/issues/63).

**Draft contract:** `ImportDraft`, `ClothingSource`, and `ImportCandidate` in `Common/Models/ImportSchema.swift` are proposed templates. The draft needs a stable import ID, owner binding, source kind, temporary media, expiry, status, and candidate IDs. It is local/private, not a public post or a `ClothingItem`. Leads must confirm how the App Group handoff, expiration, duplicate delivery, and owner changes work before shipping.

### S2. Automatic extraction and review

**Processing:** After intake, recognition analyzes the image and returns separate garment candidates with stable IDs, preview/crop references, and suggested name/category when available. For an uncertain candidate, show up to three ranked alternate garment interpretations from the same image. These are alternate detections, not products for sale. A fixture implementation should establish the result and error contract; [lead issue #135](https://github.com/gtiosclub/dressed/issues/135) then implements the selected approach against real test images. [Lead issue #53](https://github.com/gtiosclub/dressed/issues/53) chooses the approach, provider, cost/privacy limits, and manual fallback. No secret key belongs in the iOS client.

**Review:** The user can approve or skip each proposed piece, compare up to three alternate detections when available, correct its details, inspect the set, and remove an unwanted candidate. A searchable manual category choice provides a fallback when none of the alternatives fit; it does not search a product catalog. For manual region correction, prefer a lasso/circular selection control over the mockup's square box, while #53 determines whether the chosen extraction method can produce a useful cutout from that selection. The merged [review row #54](https://github.com/gtiosclub/dressed/issues/54), [review action bar #115](https://github.com/gtiosclub/dressed/issues/115), [alternate choice #132](https://github.com/gtiosclub/dressed/issues/132), and [category search #133](https://github.com/gtiosclub/dressed/issues/133) are data-team components; leads coordinate the draft state and final save in [#134](https://github.com/gtiosclub/dressed/issues/134). The mockup's “find more” path is later discovery work. If recognition finds nothing or fails, the user can manually create/select a piece from the original image.

**Confirm:** One explicit action saves the approved pieces **and an outfit referencing them**. One approved piece is enough for a one-piece outfit. The coordinator assigns stable IDs, uploads each selected image privately, writes item records, then writes the outfit with only successfully saved item IDs. A retry must resume or safely compensate for partial writes; it must not create duplicate pieces or an outfit that references missing pieces. The exact outfit layout for extracted pieces is a lead decision; an initial simple arrangement can be edited later. The original shared photo stays private unless the user separately publishes it.

**State transitions:** `received -> processing -> review -> saving -> saved`. Processing can lead to no-detection, retry, or manual correction. Save failure returns to a draft the user can retry or cancel. Sign-out, owner changes, duplicate share delivery, and expiry invalidate or recover the draft without exposing another user's media. Cancel removes temporary assets according to the cleanup policy.

**Acceptance checks:**

- Sharing a supported image produces multiple distinct candidates on an agreed test fixture. The user approves one, skips another, corrects a suggested field, and sees the reviewed selection before confirming.
- An uncertain result offers up to three alternate detections when available. If none fits, the user can search for and enter the right clothing name/category and adjust the selected image region without accepting a false match.
- Confirmation creates exactly the approved pieces and one outfit referencing those pieces, including when only one piece is approved. They appear in My Closet after relaunch. A second confirmation or a retried share does not duplicate them.
- A failed upload or item write leaves no broken outfit; retry recovers the same draft. No-detection and unsupported-input paths allow manual entry or a clear exit.
- Account B cannot access A's draft, private source image, item images, items, or outfit. No source photo is published by importing it.

## Delivery gates and current evidence

- PRs for the details form and the item/outfit save and fetch functions have merged into `data_main`. Their merge is component evidence, not proof of either complete flow in the running app.
- A live photo save needs the [Storage decision #87](https://github.com/gtiosclub/dressed/issues/87), usable Storage and owner-only rules. The [Firestore metadata check #90](https://github.com/gtiosclub/dressed/issues/90) does not cover image upload.
- Before declaring a slice done, build and exercise its native iOS flow in a simulator or device. Check owner and non-owner access in an emulator or designated development project with synthetic data. Record observed results and untested states on the relevant lead issue or PR.
- Share to Dressed's first release needs a real extraction result plus the manual fallback. Recognition quality thresholds and the evaluation image set must be defined in #53 before choosing a provider.

## Next three one-week sprints: ticket draft

This is a sequencing proposal, not a change to GitHub assignment or dates. The six new follow-up issues below are unassigned and in Backlog. Each student ticket is one small function or view with supplied inputs and observable checks. Leads own the multi-step flows, security, and unresolved contracts. Reuse the linked issue when its current scope fits; add a follow-up ticket for new behavior instead of expanding a student's active PR. Every PR in these sprints targets `data_main`.

### Sprint 1: finish the pieces path

**Goal:** A user can add one manually described piece and see it in My Closet using development data. The live photo save remains gated by Storage.

| Owner | Tickets to pull | Observable finish |
| --- | --- | --- |
| Data | [#52 choose-photo button](https://github.com/gtiosclub/dressed/issues/52), [#114 selected-photo preview](https://github.com/gtiosclub/dressed/issues/114), [#112 fetch one item](https://github.com/gtiosclub/dressed/issues/112), [#111 update details](https://github.com/gtiosclub/dressed/issues/111) | Each small component/function passes its own fixture checks and has a PR targeting `data_main`. #52 has no assignee; choose one only when work starts. |
| Viz | Finish review of [#56 item card](https://github.com/gtiosclub/dressed/issues/56), [#73 category control](https://github.com/gtiosclub/dressed/issues/73), [#74 grid](https://github.com/gtiosclub/dressed/issues/74), and [#75 filter](https://github.com/gtiosclub/dressed/issues/75); start [#116 item detail](https://github.com/gtiosclub/dressed/issues/116) when its inputs are ready. | Fixture-driven pieces list and detail are visible. The labeled category menu and Edit Item Details copy can be small follow-ups after the current reviews. |
| Lead | [#49 approved examples](https://github.com/gtiosclub/dressed/issues/49), [#93 repeatable emulator data](https://github.com/gtiosclub/dressed/issues/93), [#95 Debug emulator connection](https://github.com/gtiosclub/dressed/issues/95), and [#87 Storage decision](https://github.com/gtiosclub/dressed/issues/87); advance [#55 manual integration](https://github.com/gtiosclub/dressed/issues/55). | A synthetic signed-in owner saves/reads metadata and sees seeded pieces in the simulator. The photo-storage route is written down before a live-photo completion claim. |

**Sprint review:** Demonstrate one piece from selection through the closet grid with a mock or approved development image. Record which path used emulator data and which still awaits live Storage. Keep #55 open until the full photo path, retry, and cleanup checks pass.

Start #95 after #93 has repeatable sample data; use #90 for the separate signed-in app-to-Firestore metadata check. Neither check substitutes for a private photo upload.

### Sprint 2: saved outfits and import contract

**Goal:** Save and reopen a private outfit from owned pieces. Freeze the input/output contract for the shared-image review pipeline.

| Owner | Tickets to pull | Observable finish |
| --- | --- | --- |
| Data | [#113 delete outfit](https://github.com/gtiosclub/dressed/issues/113) and [#130 filter outfits by item ID](https://github.com/gtiosclub/dressed/issues/130). Reuse merged [#57 save](https://github.com/gtiosclub/dressed/issues/57) and [#83 fetch](https://github.com/gtiosclub/dressed/issues/83). | Supplied outfit arrays return only outfits containing the selected item; deleting an outfit leaves its item records. |
| Viz | [#77 selected-item row](https://github.com/gtiosclub/dressed/issues/77), [#117 outfit-name field](https://github.com/gtiosclub/dressed/issues/117), [#120 saved-outfit grid](https://github.com/gtiosclub/dressed/issues/120), and [#131 outfits-using-item row](https://github.com/gtiosclub/dressed/issues/131). | A one-piece and a two-piece outfit render from fixtures; the item detail shows horizontal outfit snapshots and View All. |
| Lead | [#58 outfit editor integration](https://github.com/gtiosclub/dressed/issues/58), [#53 extraction decision](https://github.com/gtiosclub/dressed/issues/53), and the draft/hand-off contract for [#62 Share to Dressed](https://github.com/gtiosclub/dressed/issues/62). | Reopening preserves placements; non-owned IDs are rejected. #53 names a recognition approach, test images, failure fallback, and candidate shape. #62 specifies image-only intake and owner-bound draft behavior. |

**Sprint review:** Demonstrate saved outfits after relaunch, including a one-piece outfit and a missing-item state. Review a fixture import draft with candidate IDs and no persistence. Recognition and external sharing are not called shipped from fixtures.

### Sprint 3: shared-image review and coordinated save

**Goal:** Move one supported shared image through automatic extraction, review, and confirmation into pieces plus one outfit, provided the Sprint 2 recognition and Storage gates are met.

| Owner | Tickets to pull | Observable finish |
| --- | --- | --- |
| Data | [#115 import-review action bar](https://github.com/gtiosclub/dressed/issues/115), [#132 alternate detections](https://github.com/gtiosclub/dressed/issues/132), and [#133 manual category search](https://github.com/gtiosclub/dressed/issues/133). | A user can choose among up to three supplied alternatives, correct an item when none fits, and cannot confirm with zero approved pieces. |
| Lead | Implement [#62 share intake](https://github.com/gtiosclub/dressed/issues/62), [#135 recognition adapter](https://github.com/gtiosclub/dressed/issues/135) after #53's decision, and [#134 coordinated save](https://github.com/gtiosclub/dressed/issues/134). | A shared image reaches a private draft, processing produces real candidates, review happens before writes, and one confirmation creates only the approved items plus a referencing outfit. |
| Viz | Connect the My Closet Pieces/Outfits destinations and item-detail entry points as lead integration supplies real data. | Saved import results appear in the appropriate section; the item and outfit edit actions are distinct. |

**Sprint review:** Use a synthetic shared image with at least two recognizable garments; approve one, skip one, then verify one item and one one-piece outfit after relaunch. Repeat the share/confirm path and check for duplicates. If recognition quality, Storage, or extension handoff is not ready, close only the verified fixture/review tickets and carry the blocked lead integration forward with the failed check recorded.

### New small follow-up tickets

These four issues are in Backlog without assignees. The lead must supply the shared input types and sample values before dependent work starts. Their UI ticket bodies end with “Screenshots of the component are preferred in the PR.”

| Ticket | Owner / type | Input and action | Done when |
| --- | --- | --- | --- |
| [#130 Filter outfits using one piece](https://github.com/gtiosclub/dressed/issues/130) | `data` / `frontend` | Given `[Outfit]` and an item ID, return outfits with a placement for that ID. | One matching outfit appears once; an unrelated or missing ID returns an empty array; source outfits are unchanged. |
| [#131 Show outfits using this piece](https://github.com/gtiosclub/dressed/issues/131) | `viz` / `frontend` | Given supplied outfit previews and callbacks, show a horizontal row and View All. | Each card shows its supplied snapshot; tapping a card reports its outfit ID once; View All reports the selected item ID. |
| [#132 Choose an alternate garment detection](https://github.com/gtiosclub/dressed/issues/132) | `data` / `frontend` | Given one candidate and up to three supplied alternatives, show their previews and report the chosen alternative ID. | The selected alternative is visible; a tap reports its ID once; an empty alternatives list shows the manual fallback. |
| [#133 Search categories for manual correction](https://github.com/gtiosclub/dressed/issues/133) | `data` / `frontend` | Given a query and supplied categories, filter the local list for manual correction. | Matching categories appear; an unmatched query offers manual entry; selecting a choice updates the draft, not the closet. |

The category dropdown, item provenance label, and clearer edit labels are design follow-ups to plan with `viz` after its current component reviews. Do not add source fields to the six-field `ClothingItem`; a lead first defines the separate provenance contract. A lasso/circular correction control belongs behind #53's extraction-method decision because its output must be usable by the processor.

**Lead integration:** [#134 saves reviewed pieces and one outfit](https://github.com/gtiosclub/dressed/issues/134) with stable IDs, retry, and cleanup. [#135 implements garment recognition](https://github.com/gtiosclub/dressed/issues/135) after #53 records the provider, test images, quality bar, and fallback. Both are unassigned in the lead board's Backlog.

## Decisions to close before implementation tickets

1. **Outfit from a shared image:** Decide the initial placement layout and how a user adjusts it after import. One approved piece already qualifies as an outfit.
2. **Item deletion:** Decide whether used-in-outfit warnings appear before deletion and how private media is cleaned up. Keep existing outfits' missing-item state explicit.
3. **Provenance and snapshots:** Define the owner-scoped import-source record and the private outfit-snapshot rendering/cache limit. A verified product URL is later work under #63.
4. **Mockup metadata and discovery:** Color/fabric/style chips and “find more” need separate contracts. They should not be added to the six-field `ClothingItem` or treated as implemented search.

Leads should record these choices, supply sample inputs/outputs, and then split unresolved integration into small tickets. The [delivery plan](delivery-plan.md), [architecture](architecture.md), and [ticket index](github-issues.md) provide the cross-team context.
