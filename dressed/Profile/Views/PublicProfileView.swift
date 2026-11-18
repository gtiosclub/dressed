import SwiftUI

/// Presentation input, not a replacement for the shared Codable UserProfile contract.
/// Images must already be approved for community display by the parent.
struct PublicProfilePresentation {
    let authorID: String
    let displayName: String
    let username: String
    var avatar: Image?
}

struct PublicProfileView: View {
    /// nil means unavailable; stale identity and posts are never rendered in that state.
    let profile: PublicProfilePresentation?
    let posts: [Post]
    var postImages: [String: Image] = [:]
    let onSelectPost: (_ authorID: String, _ postID: String) -> Void

    private var visiblePosts: [Post] {
        guard let profile else { return [] }
        return posts.filter { $0.authorId == profile.authorID }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DSSpacing.lg) {
                if let profile {
                    ProfileHeader(avatar: profile.avatar, name: profile.displayName, username: profile.username)
                        .padding(.horizontal, DSSpacing.lg)
                        .padding(.top, DSSpacing.lg)
                    VStack(spacing: DSSpacing.md) {
                        Rectangle().fill(DSColor.divider).frame(height: 1)
                        Label("Public outfits", tabler: "TablerPhoto", size: 20)
                            .font(DSFont.bodyEmphasis)
                            .foregroundStyle(DSColor.brand)
                            .accessibilityAddTraits(.isHeader)
                        Rectangle().fill(DSColor.brand).frame(height: DSSpacing.xxs)
                    }
                    if visiblePosts.isEmpty {
                        message("No public posts yet", detail: "Public outfits will appear here.", icon: "TablerPhoto")
                    } else {
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: DSSpacing.xxs), count: 3),
                                  spacing: DSSpacing.xxs) {
                            ForEach(visiblePosts) { post in postButton(post) }
                        }
                        .padding(.horizontal, DSSpacing.xxs)
                    }
                } else {
                    message("Account unavailable", detail: "This profile is not available to view.", icon: "TablerUserCircle")
                }
            }
            .padding(.bottom, DSSpacing.lg)
        }
        .background(DSColor.background)
        .foregroundStyle(DSColor.textPrimary)
    }

    private func postButton(_ post: Post) -> some View {
        Button {
            onSelectPost(post.authorId, post.id)
        } label: {
            // Tight square thumbnails form one continuous profile grid.
            Rectangle()
                .fill(DSColor.tile)
                .aspectRatio(1, contentMode: .fit)
                .overlay {
                    if let image = postImages[post.id] {
                        image.resizable().scaledToFill()
                    } else {
                        DSIcon("TablerPhoto", size: 48)
                            .foregroundStyle(DSColor.iconMuted)
                    }
                }
                .clipped()
        }
        .buttonStyle(.plain)
        .accessibilityLabel(post.caption.isEmpty ? "Open public outfit" : "Open outfit: \(post.caption)")
        .accessibilityHint(postImages[post.id] == nil ? "Post image unavailable" : "")
        .accessibilityIdentifier("publicProfile.post.\(post.id)")
    }

    private func message(_ title: String, detail: String, icon: String) -> some View {
        VStack(spacing: DSSpacing.md) {
            DSIcon(icon, size: 48).foregroundStyle(DSColor.iconMuted)
            Text(title).font(DSFont.bodyEmphasis)
            Text(detail).font(DSFont.body).foregroundStyle(DSColor.textMuted)
        }
        .padding(.horizontal, DSSpacing.lg)
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        .padding(.vertical, DSSpacing.lg)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(profile == nil ? "publicProfile.unavailable" : "publicProfile.empty")
    }
}
