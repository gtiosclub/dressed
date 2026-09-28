# Delivery plan and ownership

## Team boundaries

The confirmed subteams are `viz`, `data`, and `social`. [Team ownership](teams.md) defines their boundaries. Data owns schema stewardship, ingestion and persistence; viz owns shell/closet/composition; social owns community and discovery behavior. Individuals are not assigned from names alone. Nicole is the proposed visual-similarity contributor.

## Milestones

| Phase | Outcome / exit gate | Planning IDs |
| --- | --- | --- |
| P0 Foundation | Shared contracts, session shell, mocks and verified owner-scoped backend | P0.1-P0.3 |
| P1 Closet import | Capture or select, extract/manual fallback, review, save, filter and reopen | P1.1-P1.5 |
| P2 Outfits and OOTD | Arrange garments, save outfit, publish snapshot, browse and save posts | P2.0-P2.4 |
| P3 Import and discovery | Share drafts, product-link/wishlist flow, scoped search | P3.1-P3.3 |
| P4 Experiments | Evaluated visual retrieval and tag suggestions; usable 2D avatar prototype | PS4.1, P4.2-P4.4 |

P0-P2 form the proposed first release. P3 extends it; P4 is exploratory and must not block shipping the reliable core. Nicole's retrieval spike can begin independently using consented fixtures before P3 is complete. No calendar estimates or commitments have been agreed.

## Implementation order

Begin P0.1 (contracts) and PS4.1 (retrieval research) independently. After P0.1, the shell, backend, input adapter, review component and closet view can progress against mocks. Integration tickets depend on the relevant upstream contracts and components. Do not interpret every item in a phase as a prerequisite for every later phase; see each ticket's explicit dependencies.

End each milestone with its user-flow demo and update the backlog status. A component being rendered with fixtures is not evidence that Firebase integration works. Use shared cards for closet, post breakdown and outfit picking, and a single confirmation flow for all import sources.

## Decisions before implementation

| Decision | Proposed default | Who confirms / when |
| --- | --- | --- |
| Tab labels/order | My Closet, Discovery, Camera | Product/team before P0.2 |
| Category vocabulary | Separate pants and skirts; see scope | All three groups in P0.1 |
| Persistence | Firestore and Storage; owner-private closet | data in P0.3 |
| Development Firebase | Separate dev data/config from any real user data | Officer team before backend smoke test |
| Client plist | Keep existing client config for now; never add privileged keys | Officer team during setup review |
| Feed audience | Signed-in community; explicit publish | social in P2.2 |
| Deleted items in posts | Immutable publishable snapshots | social + data in P0.1/P2.2 |
| Extraction | Select after a bounded device/hosted evaluation; manual fallback required | data in P1.2 |
| External links | Supported URLs only; missing metadata editable | data in P3.2 |
| Search corpus | Published in-app content first; retailer catalog later if available | social before P3.3 |
| Visual similarity | Small labeled corpus; no exact-match promise | Nicole in PS4.1 |
| Avatar fidelity | 2D composition experiment | viz before P4.3 |
| Tag weighting | Defer learned personal weights; explicit tags first | social after retrieval baseline |
| Wider launch | Define report/block/moderation and deletion policy | Team before use beyond the development demo |

## Readiness and completion

A ticket is ready when its input/output contract, owner and dependencies are known. It is complete when the acceptance criteria pass, appropriate build/tests run, review evidence is recorded, and docs reflect changed contracts. Keep changes small enough to review as one behavior or reusable component. Use the existing GitHub templates if tickets or PRs are later created; the user has authorized publishing these scoped tickets with team labels; individual assignment remains unconfirmed.

## Repository maintenance completed

The redundant wrapper folder was removed in `5c10212`; README setup instructions, ignore rules and CI project path were updated, and the simulator build passed. During this planning task, the already-deleted remote `35-neal-kotval` branch was pruned, the local branch was removed, and the working checkout moved to updated `main`. Previous local work is preserved in a named Git stash; do not apply it wholesale because it contains the pre-main folder reorganization.
