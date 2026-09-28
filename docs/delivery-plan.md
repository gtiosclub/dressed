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

## Lead work to tackle first

1. Approve the shared model fields and examples (#49).
2. Prepare development Firebase access and verify ownership rules (#51).
3. Connect existing authentication to the three tabs (#50).
4. Connect the manual photo flow and closet (#55).

These are actionable now, but they are not all already complete. Outfit integration (#58) and publication (#59) follow their required data/UI pieces. Extraction, external sharing, recommendations and avatars remain separate projects of work. Discuss unresolved behavior with Neal before writing student tickets that depend on it.
