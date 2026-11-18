# Public profile — SOCIAL-P07 / #245

The implemented presentation is grid-only, following the user's final direction.
It uses a simple social profile header, a circular supplied avatar, wrapping name
and handle, and a tightly spaced three-column square photo grid. White surfaces,
gray supporting text, and a lavender section divider use Dressed design tokens
and the supplied UI reference as inspiration. There is no feed mode or switch.

## Parent-supplied input

`PublicProfilePresentation` is view input, not a replacement for shared
`UserProfile`: authorID, displayName, username, and optional resolved SwiftUI Image.
`PublicProfileView` takes this optional profile, public `[Post]`, optional resolved
public images keyed by post ID, and `onSelectPost(authorID, postID)`.

The parent owns navigation, loading, authorization and media resolution. The view
filters supplied posts by exact author ID, preserves their order, and returns the
selected Post's authorId and id. It does not query Auth, private closet records,
storage paths, or URLs. Filtering is presentation logic, not backend authorization.

- Missing avatar: neutral user icon.
- Missing post image: neutral photo icon.
- No matching public posts: identity and an empty-state message.
- Unavailable account (nil profile): hides all supplied identity and posts.
- Long display names and handles: wrap within the header beside the avatar.

## Review evidence

Temporary screenshot content is used only during verification and removed before
handoff. The final change has no sample identity, posts, image assets, launch route,
or screenshot test harness. PR screenshots are saved outside the repository.
Live profile integration and backend access rules remain outside this component.

## Verification — November 17, 2026

The temporary grid-only UI check passed on iPhone 17 / iOS 26.5 with zero failures.
It covered a supplied avatar and posts, two long-name cases (one with a long handle),
missing avatar, no posts, unavailable account, absence of a Feed option, and the
author/post selection callback. Six simulator screenshots were inspected: names
wrap within the header without overlapping the avatar or grid. The capture harness
and all associated sample data were then removed. Screenshots are external PR
attachments; they are not app assets. Live backend/authentication and the full
application regression suite were not tested. SwiftLint is unavailable.

After removing the screenshot harness and sample content, the final Xcode Debug
simulator build passed. `git diff --check` also passed.
