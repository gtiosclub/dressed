# Post photo and outfit publication

Implemented client contract for lead #59, November 19, 2026. Rules are local and
emulator-tested; this change does not deploy rules, create a bucket or enable billing.

## Input and result

The author chooses a post photo, tags 1–10 owned local closet pieces (or chooses a
saved outfit), and confirms Share. A saved outfit supplies its name and items;
the author still explicitly chooses the post photo. Editing tags clears the saved
outfit name. Missing item photos block publication. Audio and product-link attachment
are outside this composer. Caption: at most 500 characters; names: at most 80.

The existing `Post` contains the caption, authenticated `authorId`, creation date,
zero initial likes, main media path, and `PublishedOutfitSnapshot`. Each snapshot
item keeps `sourceItemId` as provenance, `name`, `category`, and a separate public
media path. It never stores a private item image path. No shared record gains fields.
The current adapter preserves the draft creation date as a Firestore Timestamp.

Example: selecting “Monday” with a blue shirt and jeans uploads a separate main
photo and two item photos. Another signed-in user can read the post and those
three images, but cannot read `users/{author}/items` or private media. Deleting the
private blue-shirt original does not break the post.

| Asset | Path | Upload format |
| --- | --- | --- |
| Chosen post photo | `posts/{authorId}/{postId}/composite.jpg` | JPEG, longest edge ≤1600 px |
| Each tagged item | `posts/{authorId}/{postId}/items/{sourceItemId}.jpg` | JPEG, longest edge ≤800 px |

The legacy `composite.jpg` filename is retained for the published-image loader;
it contains the explicitly selected photo. Pixel rendering removes source metadata
and orientation tags, and flattens transparency to white. Each upload is ≤10 MiB.

## Ordering, retries and cancellation

1. Freeze one draft ID and its content on the first Share attempt.
2. Read that ID from the server; an identical existing post resolves a lost acknowledgement.
3. Upload independent public copies. Pending media is readable only by the owner.
4. Create the post transactionally, or accept the identical existing snapshot.
5. After acknowledgement, insert the post in Friends and dismiss the composer.

A failed upload/rejected commit triggers deletion of attempted uploads. Cleanup
failures are reported and Retry Share reuses the draft. Cancellation is checked
between uploads and before the commit. Once committed, publication is successful.
If commit status cannot be determined by a server read, never delete potentially
published images: retain the frozen draft and let Retry Share resolve the same ID.
Draft/photo selection is in memory; leaving the composer or terminating the process
can lose the retry state. Abandoned owner-only uploads require maintenance; no
background cleanup service is claimed.

## Authorization and deletion

Firestore validates every snapshot item, author identity, field set, caption,
category, item limit, and post-specific media prefix. Private media references,
impersonation and arbitrary extra fields are rejected. The 10-item boundary is
covered by emulator tests, including a malformed last item.

Storage accepts only owner uploads to the two paths above, with the JPEG MIME type
and byte limit, before the parent post exists. Signed-in community reads require
a parent post belonging to that author. A committed post's media cannot be overwritten
or deleted by a client. Private closet rules remain owner-only. Post edits/deletion
remain disabled, except the existing atomic like-count transition. If an administrator
removes a post, other users lose media access; physical media cleanup is an
administrator responsibility. A separate deletion feature must define full cleanup.

The Firestore and Storage commit is not cross-service atomic: missing external
objects show an image fallback, and trusted maintenance must handle crashes/orphans.
Do not make private photos public to bypass setup or permission errors.

## Validation and deployment

- `npm run test:rules` uses `demo-dressed`, synthetic Alice/Bob/guest identities,
  and Firestore/Storage emulators. It never writes live user data.
- `dressedTests/PostPublishingTests` covers independent paths, retry/idempotency,
  rollback, cancellation, lost acknowledgement and image-size normalization.
- `dressedTests/PostComposerTests` covers required selections, frozen retries and
  missing saved-outfit pieces.
- `NavigationUITests/testPostComposerSelectsPhotoAndSavedOutfitThenShowsSnapshotInFeed`
  uses a mock session and local demo publication; seed a synthetic photo into the
  test simulator first. This does not verify real authentication or live Firebase writes.

Before a live release, confirm Storage is enabled, review/deploy both rules files
and verify publication/relaunch/cross-account access using designated development
accounts. Billing changes are outside this implementation. Production moderation,
post deletion, orphan cleanup scheduling and public author profiles remain separate work.

Verification on November 19: signed Debug simulator build passed; 21 emulator
cases, 10 focused unit tests and two composer UI tests passed. The tests cover
photo/outfit selection, local demo publication and breakdown, required selections
and cancellation. Exported composer/breakdown screenshots were visually inspected.
A separate no-flags launch restored the existing Firebase session; photo picking
and saved-outfit tagging were exercised there without submitting a live post. This
is session restoration, not a fresh sign-in test. Focused lint passes for the new
publication/composer/media code. Full-app build lint still reports pre-existing
violations, including a force cast in CameraCaptureView. No InjectionNext success
is claimed: the change adds files and protocols and was fully rebuilt.

Merge verification: integrated `origin/main` at `77b72e6`, preserving its own-profile
screen and removal of the feed Save control. The merged signed build and all 15
focused unit tests (publication/composer/profile identity) passed. The merged UI
rerun created the demo post but later taps did not reliably open details/composer;
tests now wait for stable hittable frames. The subsequent iOS 26 runner stalled,
and an iOS 27.2 retry was stopped during first-boot migration. Therefore the merged
UI rerun is inconclusive; the two passing UI results above refer to the pre-merge
branch. No Firebase deployment was performed.
