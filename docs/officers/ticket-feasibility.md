# Ticket feasibility check

Checked September 28, 2026 against the 21 open student issues on the `data`, `viz`, and `social` boards, the shared Swift models, and the current Firebase rules. GitHub remains the source of truth for issue status and individual assignment.

## What students can start

The first clothing milestone has seven unblocked tickets in **Ready**: data #52, #70, #71, and #82; viz #56, #73, and #75. They have an agreed `ClothingItem` shape or self-contained UI inputs. A student can finish each without designing app navigation or the whole import flow. Later cards stay in **Backlog** so the boards show the current delivery order. No individual student has been assigned by this audit.

The remaining student tasks are feasible as isolated functions or components, subject to these explicit gates:

| Work | Gate before a live feature is claimed |
| --- | --- |
| Image upload #72 and full closet import #55 | #72 can be tested in the Storage emulator. Live photos need the Storage decision in #87, provisioned Storage, and published rules. |
| Outfit save/fetch #57 and #83 | Lead issue #49 must approve the proposed `Outfit` fields and sample. Lead #58 connects selection, layout, validation, and reopening. |
| Bookmark save #61 | The current Firestore rules deny `savedPosts`; lead #94 adds and tests owner-only access. This function bookmarks a post; it does not publish one. |
| Feed fetch #80 and post views #60, #79 | Use approved synthetic post data locally. Lead #59 defines publication and public media. Lead #49 must decide where author names and avatars come from because `Post` has no username and client profile reads are currently denied. |
| Local demo dataset #93 | Seed synthetic data in the emulator. Its post must be seeded by an admin/test helper because client post writes are denied. This does not connect the iOS app automatically. |
| Debug app demo #95 | After #93, #70, and #71, point a Debug launch at the matching local Auth and Firestore emulators. Release must keep its normal configuration. |
| Live Firestore check #90 | After #70/#71, leads use a Debug-only app path to save/read metadata with test accounts; photo Storage is not part of this check. |

The decision tickets #63 (links and wishlist) and #66 (optional AI tags) now finish with a documented choice and examples. They no longer imply that deciding a feature also implements it.

Lead #50 has been returned to **In review**. Its app-shell code is merged, but the PR verified only a mock session; live sign-in, restored session, Camera, and sign-out are still the ticket's own acceptance checks. Do not mark it Done until those paths are observed.

## Responsibility and handoffs

| Owner | Delivers | Hands to |
| --- | --- | --- |
| `data` | Small import controls and individual clothing/outfit Firebase functions | Leads connect photo selection, IDs, upload, save, and recovery in #55 and outfit persistence in #58. |
| `viz` | Closet and outfit components plus the category filter, driven by supplied values | Leads provide screen state and real items; the clothing card is reused by #74 and #76. |
| `social` | Post/profile/search components and basic bookmark/feed functions | Leads provide safe public post data, author display data, publication, and access rules in #49, #59, and #94. |
| `lead` | Shared field decisions, authentication/navigation, security rules, cloud setup, cross-team flows, and end-to-end checks | Students receive approved inputs and paths; leads own the resulting app behavior. Local demo connection is #95; live metadata check is #90. |

Each issue has one primary owner label. `frontend` and `backend` describe the work, so data can own a small view and social can own a database function. No names in old notes are assignments.

## Product choice still needed

The roadmap says the first live demo saves a garment **photo**, while the current Spark project cannot use Cloud Storage for Firebase. Neal must choose whether milestone 1 waits for an approved photo-storage route or ships a metadata-only closet demo first. Keep #87's existing low priority until that choice is made. Do not describe the photo flow as unblocked merely because the Firestore functions work.
