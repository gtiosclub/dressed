# Roadmap

Build one working path first: select a photo, enter a clothing name/category, save it, and see it after reopening the closet. Extraction is later work and must not block this milestone.

| Milestone | Student pieces | Lead integration | Working result |
| --- | --- | --- | --- |
| 1. Add and browse clothing | Choose-photo button, details form, save/fetch/upload functions, clothing card/grid, category controls/filter | Photo picker, session, IDs, record construction, failure recovery and closet loading | A manually described garment is saved and visible after relaunch |
| 2. Build an outfit | Item tray, selected-item row, save/fetch outfit functions, preview card | Selection/layout state and opening saved outfits | An outfit can be saved and reopened |
| 3. Share an outfit | Post card, profile header, fetch posts, save-post function, clothing breakdown | Publication, separate public media and feed wiring | Another account can browse and save the published outfit |
| 4. Improve importing and discovery | Search field and garment-review row; more small pieces after decisions | Camera capture, extraction, Share to Dressed, product links, recommendations | Faster imports and useful discovery |
| 5. Explore try-on | Define small components after agreeing on direction | Avatar approach and rendering | An agreed visualization prototype |

## How tickets connect

Approved sample records feed the clothing card, category filter and basic database functions. The clothing card (#56) is reused by the closet grid (#74), outfit tray (#76) and post breakdown (#79). These are component dependencies, not a requirement for every team to finish an entire phase before another team starts.

Leads connect the details form and upload/save functions to the closet. Saved outfits then use the selection components and outfit functions. Publishing uses those outfits; feed cards and save-post functions can be built independently with sample data while publishing is developed.

Students can start views with supplied images and arrays. Live database checks depend on approved samples (#49) and development Firebase access (#51). Leads own authentication, rules and multi-step failure recovery. Lead issue #55 connects manual import; extraction research in #53 is separate.

The existing `out-fitted` Firebase project remains the app's target. It contains older data, so student work uses the new owner-scoped paths and synthetic emulator identities. Owner-scoped Firestore rules are published. Live image uploads require Cloud Storage, which currently asks for Blaze. The first photo demo therefore waits on #87 and lead Storage setup unless Neal chooses a metadata-only first demo. Bookmark writes also need owner-only rules in #94. See [Firebase testing](officers/firebase-testing.md) and the [ticket feasibility check](officers/ticket-feasibility.md).

## Lead work to tackle first

1. Finish approval of the shared model fields and examples (#49). The first `ClothingItem` shape is already agreed.
2. Prepare repeatable local demo data (#93), connect a Debug app to it (#95), then test student Firestore functions against the development project (#90).
3. Decide the photo-storage route (#87) before claiming the live photo flow in #55 is ready.
4. Connect the manual photo flow and closet (#55), outfit flow (#58), and safe publication (#59) as their pieces arrive.

The app-shell code from #50 is merged, but #50 is In review until its live sign-in, restored-session, Camera, and sign-out checks are observed. Initial Firestore ownership rules (#51) are done. Extraction, external sharing, recommendations and avatars remain separate projects of work. Discuss unresolved behavior with Neal before writing student tickets that depend on it.
