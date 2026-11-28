# Post comments

Implemented client and emulator-tested rules. The rules were published to
`out-fitted` on November 17, 2026 with user approval. The console showed the new
active version and no unpublished changes; its rule content matched the tested
file. Signed-in iOS save/relaunch and cross-account persistence checks remain pending.

Path: `posts/{postId}/comments/{commentId}`. Synthetic JSON example:

```json
{
  "id": "stable-comment-id",
  "authorId": "synthetic-alice",
  "text": "Nice fit",
  "createdAt": "2026-11-17T20:00:00Z"
}
```

The shared Codable record is `Common/Models/PostComment.swift`. Firestore stores
`createdAt` as a server-generated Timestamp, decoded to Date. Auth supplies the
author UID; the client never writes an email, display name or private media.
Reads require sign-in and an existing parent post. Queries order descending by
`createdAt`, then document ID, and must limit reads to at most 50. The single-field
index supports this query; no composite index or count record is introduced.

Create requires matching record/document ID and author/auth UID, exactly these
four fields, non-whitespace text of at most 1,000 characters and request-time
timestamp. Transactions reuse an ID during retry and treat an existing identical
author/text as success. Updates and deletes are denied. Removed posts make their
comments inaccessible; orphan deletion is deferred to the post deletion service.

UI displays “You” / “Member” pending trusted public profile integration. Editing,
deletion, reporting and moderation remain TBD before public launch. Demo comments
use an injected in-memory service, visibly labeled, never this database path.

Verification:

```sh
npm ci
npm run test:rules
swiftc dressed/Common/Models/PostComment.swift \
  dressed/Common/Firebase/CommentService.swift \
  dressed/Discovery/ViewModels/CommentsViewModel.swift \
  tests/CommentsViewModelChecks.swift -o /private/tmp/dressed-comments-model-checks
/private/tmp/dressed-comments-model-checks
```

The rules suite uses only `demo-dressed` and synthetic users. The focused UI test
`ShareImportUITests/testCommentsSubmitAndReopenFromBothFeedLayouts` uses a mock
session and demo service: it checks UI wiring, not Firebase authentication.
For live acceptance checks, use a normally signed build and dedicated
development accounts through normal sign-in. On a designated synthetic published
post, account A submits, closes/reopens, and relaunches; account B refreshes and
sees the same comment. Check the record in the console. Do not use real-user posts
for this test or open client post publication just to seed it.
