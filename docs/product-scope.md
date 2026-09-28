# Product scope

## Purpose

Help people capture clothing with less manual work, organize a digital closet, share memorable outfits with peers, find similar pieces, and visualize combinations before wearing them.

Core user questions:

- How can I add clothing from a photo, camera, or another app quickly?
- How can I inspect separate pieces within an outfit?
- How can I save and share an outfit with friends?
- How can I find an exact or visually similar item?
- How can I arrange my clothing on a visual representation of myself?

## Navigation

Use three top-level tabs, in this order. Names below are proposed UI copy.

| Tab | Primary job | Child flows |
| --- | --- | --- |
| My Closet | Browse owned items and saved outfits | Category filters, item detail/edit, create outfit, wishlist, future try-on |
| Discovery | Social feed and discovery/search | OOTD detail, clothing breakdown, search, saved posts, profiles, future similar items |
| Camera | Capture or import clothing | Camera, photo library, incoming share draft, extraction, review, destination selection |

Discovery combines Social / Discover with a Feed / Search switch inside the tab. Profile and settings are child destinations, not extra tabs. Camera must offer a photo-library fallback if permission is denied or the device lacks a camera. Authentication gates the app shell; signing out clears user-specific state.

## First release: capture, closet, outfits, OOTD

A user signs in, chooses or takes a picture, reviews detected garments, selects which ones to keep, corrects names/categories, and saves the selected items to My Closet. They can then compose a saved outfit and publish it to a chronological Discovery feed. Another signed-in user can inspect the outfit's separate pieces and save the post.

Included:

- Existing email/password authentication connected to a session-aware app shell.
- Camera and photo-library imports sharing one ingestion pipeline.
- Garment extraction behind a replaceable service. Manual single-item crop/import is the fallback if extraction fails or returns nothing.
- A verification screen with select/deselect, editable item details, retry and cancel.
- Closet grid, item detail, category filtering and item deletion.
- Categories: Tops, Pants, Skirts, Dresses, Shoes, Outerwear, Accessories, Other. Pants and Skirts stay separate, matching the team's notes.
- Saved outfits using selected closet items and a simple 2D arrangement.
- OOTD publishing from a saved outfit, caption, feed, clothing breakdown and save/unsave.
- Loading, empty, failed, permission-denied and retry states for each asynchronous flow.
- Ownership rules and failure cleanup for private items/media before backend integration is considered complete.

An OOTD post represents an outfit. A source outfit photo can be scanned into individual garments; publishing the original photo is a separate explicit choice and can follow the composite-only first release.

## Next release: import and discover

- **Share to Dressed:** receive supported images or URLs from the iOS share sheet; queue a draft for the same review flow. It should not silently fill the closet. External apps only participate when they provide a supported share payload.
- Wishlist destination for pieces a user wants rather than owns. Do not label imported products as owned by default.
- Product URL import with editable partial metadata and an unsupported-link fallback. This does not imply access to every social app, private post or retailer catalog.
- Text/category/tag search over an explicitly defined public dataset.
- AI-suggested category/tags that users can correct; preserve user-authored tags.
- Similar-piece recommendations, beginning with a bounded corpus and evaluated retrieval baseline.

“Exact match” is only shown when an identifier or verified product source supports it. Visual resemblance alone is labeled “similar.” A recommendation cannot supply a real purchase link unless its source has one.

## Visualization progression

1. Arrange cut-out garments on a 2D outfit canvas and save their positions.
2. Prototype a 2D avatar/mannequin backdrop with movable garments; describe it as outfit visualization, not fit prediction.
3. Consider personalized avatars, measurements, 3D rotation and realistic try-on only after the prototype demonstrates value and the team has selected assets, rendering technology and a feasible garment representation.

No first-release promise of body scanning, AR, sizing accuracy, physics, photorealistic try-on or generated views of unseen garment surfaces.

## Later ideas

Follows and personalized feed ranking; likes/comments; per-user weighted tags; learned recommendation models; weather-based outfit suggestions; challenges; notifications; streaks; widgets; affiliate links; jewelry/hairstyles. Keep these visible without making them dependencies of the first end-to-end flow.

## Demo exit criteria

Using two development accounts, account A imports a photo, approves two detected/manual items, sees them after relaunch, creates an outfit and publishes it. Account B sees that post and its item breakdown, saves it, and sees the saved state after relaunch. Account B cannot read A's private closet or write A's records. A failed import can be retried without duplicate items. Deleting a private original does not break an already published outfit snapshot.

Use development data. A wider public launch additionally needs a defined report/block/moderation process and account/content deletion policy; those decisions are outside the initial classroom demo scope.
