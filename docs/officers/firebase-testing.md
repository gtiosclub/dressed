# Firebase testing for student work

The iOS app currently uses the existing Firebase project `out-fitted` (shown as **dressed** in the Firebase console). Keep the tracked `dressed/GoogleService-Info.plist` for that project. Do not point students at the separate `dressed-development` project created during planning.

As checked on September 28, 2026, `out-fitted` has existing accounts and older data in uppercase collections such as `CLOTHING` and `OUTFITS`. Its deployed Firestore rules deny all client reads and writes. The new student examples use owner-scoped paths such as `users/{uid}/items/{itemId}` and must not overwrite or migrate those older collections. Do not use existing users' records for tests.

## Safe local check

Use two synthetic identities, `alice` and `bob`, in the Firebase emulators. From the repository root:

```sh
npm ci
npm run test:rules
```

The rules test checks that an owner can save and fetch a clothing item, another account and a signed-out client cannot, malformed records are rejected, outfits stay private, and the older collection names remain closed. It also checks private JPEG paths in the Storage emulator. The emulator uses the `demo-dressed` project ID and never contacts the live project.

The sample `ClothingItem` is in `backend/schemas/examples.json`. The lead supplies the signed-in user's UID, a stable item ID, and the path `users/{uid}/items/{itemId}/original.jpg`. Students should use their own approved test account after live rules are reviewed and published. A Firebase `permission-denied` error means the operation was rejected by rules; a Storage billing error means the bucket is not available on the current plan. Students should report either error to a lead rather than change rules themselves.

## Live project status and next steps

- Firestore metadata can use the current Spark plan, but the proposed `firestore.rules` file is not deployed yet. Its new paths must be reviewed and tested before a lead publishes them to `out-fitted`.
- [Cloud Storage for Firebase](https://firebase.google.com/docs/storage/ios/start) currently requires Blaze, and the console asks to upgrade `out-fitted`. This blocks the live image-upload ticket and the full photo-save demo. Club credits may apply only if they are on a [Google Cloud billing account linked to this project](https://firebase.google.com/docs/projects/billing/firebase-pricing-plans); check that account and its terms before changing plans.
- `storage.rules` is tested locally only. Publish it after Storage exists and the account owner has approved the billing change.
- Public post reads are defined for signed-in users, but client publication stays denied until lead issue #59 defines the published snapshot and media flow.

No service-account key, private credential, or real-user fixture belongs in this repository.
