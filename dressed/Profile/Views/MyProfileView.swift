import SwiftUI

/// The signed-in user's own profile, opened from the initial in the Discovery header.
/// No Figma frame exists yet; it is composed from design-system parts and follows
/// `PublicProfileView` for the post grid.
struct MyProfileView: View {
    let name: String?
    let pieceCount: Int
    let outfitCount: Int
    @ObservedObject var model: MyProfileModel
    let onSignOut: () -> Void
    var onBack: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    @State private var confirmingSignOut = false

    private let columns = Array(repeating: GridItem(.flexible(), spacing: DSSpacing.xxs), count: 3)

    var body: some View {
        VStack(spacing: 0) {
            DSBackHeader(title: "Profile") { (onBack ?? { dismiss() })() }
                .padding(.horizontal, DSSpacing.lg)
                .padding(.top, DSSpacing.sm)
                .padding(.bottom, DSSpacing.md)

            ScrollView {
                VStack(alignment: .leading, spacing: DSSpacing.lg) {
                    ProfileHeader(name: name ?? "Your profile", detail: closetSummary)
                        .padding(.horizontal, DSSpacing.lg)
                        .accessibilityIdentifier("profile.header")

                    stats

                    postsSection

                    Button(role: .destructive) {
                        confirmingSignOut = true
                    } label: {
                        Text("Sign Out").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.ds(.secondary))
                    .padding(.horizontal, DSSpacing.lg)
                    .padding(.top, DSSpacing.sm)
                    .accessibilityIdentifier("profile.signOut")
                }
                .padding(.top, DSSpacing.sm)
                .padding(.bottom, DSSpacing.lg)
            }
            .refreshable { await model.load() }
        }
        .background(DSColor.background)
        .foregroundStyle(DSColor.textPrimary)
        .toolbar(.hidden, for: .navigationBar)
        .task { await model.load() }
        .confirmationDialog("Sign out of Dressed?", isPresented: $confirmingSignOut, titleVisibility: .visible) {
            Button("Sign Out", role: .destructive, action: onSignOut)
            Button("Cancel", role: .cancel) {}
        }
    }

    private var closetSummary: String {
        "\(pieceCount) \(pieceCount == 1 ? "piece" : "pieces") · \(outfitCount) \(outfitCount == 1 ? "outfit" : "outfits")"
    }

    // MARK: - Stats

    private var stats: some View {
        HStack(spacing: 0) {
            stat(value: model.postCount.map(String.init), label: "Posts", id: "posts")
            // TODO(social): followers and following need the Follow service; placeholders until then.
            stat(value: nil, label: "Followers", id: "followers")
            stat(value: nil, label: "Following", id: "following")
        }
        .padding(.vertical, DSSpacing.md)
        .overlay(alignment: .top) { Rectangle().fill(DSColor.divider).frame(height: 1) }
        .overlay(alignment: .bottom) { Rectangle().fill(DSColor.divider).frame(height: 1) }
    }

    private func stat(value: String?, label: String, id: String) -> some View {
        VStack(spacing: DSSpacing.xxs) {
            Text(value ?? "–")
                .font(DSFont.bodyEmphasis)
                .monospacedDigit()
                .foregroundStyle(value == nil ? DSColor.textPlaceholder : DSColor.textPrimary)
            Text(label)
                .font(DSFont.search)
                .foregroundStyle(DSColor.textMuted)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(value.map { "\($0) \(label)" } ?? "\(label), not available yet")
        .accessibilityIdentifier("profile.stat.\(id)")
    }

    // MARK: - Posts

    @ViewBuilder private var postsSection: some View {
        Text("Posts")
            .font(DSFont.bodyEmphasis)
            .padding(.horizontal, DSSpacing.lg)
            .accessibilityAddTraits(.isHeader)

        switch model.posts {
        case .loading:
            ProgressView()
                .frame(maxWidth: .infinity)
                .padding(.vertical, DSSpacing.lg)
                .accessibilityLabel("Loading your posts")
        case .failed(let message):
            status(icon: "TablerAlertTriangle", title: "Posts unavailable", detail: message) {
                Button("Try Again") { Task { await model.load() } }
                    .buttonStyle(.ds(.secondary))
            }
            .accessibilityIdentifier("profile.posts.error")
        case .loaded(let posts) where posts.isEmpty:
            status(icon: "TablerPhoto", title: "No posts yet",
                   detail: "Outfits you post to Discovery appear here.") { EmptyView() }
                .accessibilityIdentifier("profile.posts.empty")
        case .loaded(let posts):
            LazyVGrid(columns: columns, spacing: DSSpacing.xxs) {
                ForEach(posts) { post in
                    // Square thumbnails form one continuous grid, as on PublicProfileView.
                    Color.clear
                        .aspectRatio(1, contentMode: .fit)
                        .overlay { PostArtwork(post: post, cornerRadius: 0) }
                        .clipped()
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(post.caption.isEmpty ? "Your outfit post" : "Your outfit: \(post.caption)")
                        .accessibilityIdentifier("profile.post.\(post.id)")
                }
            }
            .padding(.horizontal, DSSpacing.xxs)
        }
    }

    private func status<Action: View>(
        icon: String, title: String, detail: String,
        @ViewBuilder action: () -> Action
    ) -> some View {
        VStack(spacing: DSSpacing.sm) {
            DSIcon(icon, size: 48).foregroundStyle(DSColor.iconMuted)
            Text(title).font(DSFont.bodyEmphasis)
            Text(detail).font(DSFont.body).foregroundStyle(DSColor.textMuted)
            action().padding(.top, DSSpacing.xs)
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, DSSpacing.lg)
        .padding(.vertical, DSSpacing.lg)
    }
}

#Preview("With posts") {
    NavigationStack {
        MyProfileView(
            name: "eric", pieceCount: 12, outfitCount: 3,
            model: MyProfileModel(ownerId: "user38483", service: DemoPostFunctions()),
            onSignOut: {}, onBack: {}
        )
    }
}

#Preview("Empty") {
    NavigationStack {
        MyProfileView(
            name: "eric", pieceCount: 1, outfitCount: 0,
            model: MyProfileModel(ownerId: "nobody", service: DemoPostFunctions()),
            onSignOut: {}, onBack: {}
        )
    }
}
