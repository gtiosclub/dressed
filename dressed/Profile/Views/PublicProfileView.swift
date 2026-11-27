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

struct AuthorProfileView: View {
    private enum PostsState {
        case loading
        case loaded([Post])
        case failed(String)
    }

    let authorId: String
    let currentUserId: String
    @ObservedObject var userProfiles: UserProfileStore
    @ObservedObject var follows: FollowViewModel
    @ObservedObject var moderation: ModerationViewModel
    var postService: any PostFunctions = DiscoveryPostSource.current
    var onSelectPost: ((Post) -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @State private var postsState: PostsState = .loading
    @State private var isReportingUser = false
    @State private var confirmingBlock = false

    private let columns = Array(repeating: GridItem(.flexible(), spacing: DSSpacing.xxs), count: 3)

    private var isOwnProfile: Bool {
        authorId == currentUserId
    }

    private var isBlocked: Bool {
        moderation.isBlocked(authorId)
    }

    private var postCount: Int? {
        if case .loaded(let posts) = postsState { return posts.count }
        return nil
    }

    var body: some View {
        VStack(spacing: 0) {
            DSBackHeader(title: userProfiles.displayName(for: authorId), onBack: { dismiss() }) {
                if !isOwnProfile {
                    DSMoreMenu(accessibilityLabel: "More options") {
                        Button("Report user") {
                            isReportingUser = true
                        }
                        if isBlocked {
                            Button("Unblock user") {
                                Task { await moderation.unblock(userId: authorId) }
                            }
                        } else {
                            Button("Block user", role: .destructive) {
                                confirmingBlock = true
                            }
                        }
                    }
                    .accessibilityIdentifier("authorProfile.moreMenu")
                }
            }
            .padding(.horizontal, DSSpacing.lg)
            .padding(.top, DSSpacing.sm)
            .padding(.bottom, DSSpacing.md)

            ScrollView {
                VStack(alignment: .leading, spacing: DSSpacing.lg) {
                    ProfileHeader(
                        name: userProfiles.displayName(for: authorId),
                        username: userProfiles.handle(for: authorId)
                    )
                    .padding(.horizontal, DSSpacing.lg)
                    .accessibilityIdentifier("authorProfile.header")

                    statsRow

                    if !isOwnProfile, !isBlocked {
                        let isFollowing = follows.isFollowing(authorId)
                        let isPending = follows.pendingTargetIds.contains(authorId)
                        Button {
                            Task { await follows.toggleFollow(targetUserId: authorId) }
                        } label: {
                            Text(isFollowing ? "Following" : "Follow")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.ds(isFollowing ? .secondary : .primary))
                        .disabled(isPending)
                        .padding(.horizontal, DSSpacing.lg)
                        .accessibilityIdentifier("authorProfile.followButton")
                    }

                    postsSection
                }
                .padding(.top, DSSpacing.sm)
                .padding(.bottom, DSSpacing.lg)
            }
            .refreshable { await loadAll() }
        }
        .background(DSColor.background)
        .foregroundStyle(DSColor.textPrimary)
        .toolbar(.hidden, for: .navigationBar)
        .task(id: authorId) { await loadAll() }
        .confirmationDialog(
            "Block \(userProfiles.displayName(for: authorId))?",
            isPresented: $confirmingBlock,
            titleVisibility: .visible
        ) {
            Button("Block user", role: .destructive) {
                Task { await moderation.block(userId: authorId) }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You won't see their posts in your feed.")
        }
        .sheet(isPresented: $isReportingUser) {
            ReportUserSheet(
                authorId: authorId,
                displayName: userProfiles.displayName(for: authorId),
                moderation: moderation
            )
        }
    }

    private func loadAll() async {
        async let profileLoad: Void = userProfiles.loadIfNeeded(userIds: [authorId])
        async let countsLoad: Void = follows.loadCounts(for: authorId)
        async let postsLoad: Void = loadPosts()
        _ = await (profileLoad, countsLoad, postsLoad)
    }

    private func loadPosts() async {
        postsState = .loading
        do {
            let fetched = try await postService.fetchPosts(authorId: authorId)
            try Task.checkCancellation()
            postsState = .loaded(fetched)
        } catch is CancellationError {
            return
        } catch {
            postsState = .failed("Posts couldn't load. Check your connection and try again.")
        }
    }

    private var statsRow: some View {
        HStack(spacing: 0) {
            stat(value: postCount.map(String.init), label: "Posts", id: "posts")
            stat(value: follows.followerCounts[authorId].map(String.init), label: "Followers", id: "followers")
            stat(value: follows.followingCounts[authorId].map(String.init), label: "Following", id: "following")
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
        .accessibilityIdentifier("authorProfile.stat.\(id)")
    }

    @ViewBuilder private var postsSection: some View {
        if isBlocked {
            DSEmptyState(
                icon: "TablerEyeOff",
                title: "User blocked",
                message: "You blocked this account. Unblock them to see their posts.",
                actionTitle: "Unblock user"
            ) {
                Task { await moderation.unblock(userId: authorId) }
            }
            .accessibilityIdentifier("authorProfile.blocked")
        } else {
            switch postsState {
            case .loading:
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DSSpacing.lg)
                    .accessibilityLabel("Loading posts")
            case .failed(let message):
                DSEmptyState(
                    icon: "TablerAlertTriangle",
                    title: "Posts unavailable",
                    message: message,
                    actionTitle: "Try Again"
                ) {
                    Task { await loadPosts() }
                }
                .accessibilityIdentifier("authorProfile.posts.error")
            case .loaded(let posts) where posts.isEmpty:
                DSEmptyState(
                    icon: "TablerPhoto",
                    title: "No posts yet",
                    message: "Public outfits will appear here."
                )
                .accessibilityIdentifier("authorProfile.posts.empty")
            case .loaded(let posts):
                LazyVGrid(columns: columns, spacing: DSSpacing.xxs) {
                    ForEach(posts) { post in
                        Button {
                            onSelectPost?(post)
                        } label: {
                            Color.clear
                                .aspectRatio(1, contentMode: .fit)
                                .overlay { PostArtwork(post: post, cornerRadius: 0) }
                                .clipped()
                        }
                        .buttonStyle(.plain)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(post.caption.isEmpty ? "Open outfit post" : "Open outfit: \(post.caption)")
                        .accessibilityIdentifier("authorProfile.post.\(post.id)")
                    }
                }
                .padding(.horizontal, DSSpacing.xxs)
            }
        }
    }
}

private struct ReportUserSheet: View {
    let authorId: String
    let displayName: String
    @ObservedObject var moderation: ModerationViewModel

    @Environment(\.dismiss) private var dismiss
    @State private var reason = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            DSBackHeader(title: "Report User") { dismiss() }
                .padding(.horizontal, DSSpacing.lg)
                .padding(.top, DSSpacing.lg)
                .padding(.bottom, DSSpacing.md)

            ScrollView {
                VStack(alignment: .leading, spacing: DSSpacing.md) {
                    Text("Tell us why you are reporting \(displayName).")
                        .font(DSFont.body)
                        .foregroundStyle(DSColor.textMuted)
                        .fixedSize(horizontal: false, vertical: true)

                    DSLabeledField(label: "Reason", prompt: "Describe the issue", text: $reason)
                        .accessibilityIdentifier("reportUser.reason")

                    if let errorMessage {
                        Text(errorMessage)
                            .font(DSFont.search)
                            .foregroundStyle(DSColor.destructive)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Button {
                        Task { await submit() }
                    } label: {
                        if isSubmitting {
                            ProgressView()
                                .tint(Color.white)
                                .frame(maxWidth: .infinity)
                        } else {
                            Text("Submit Report").frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(.ds(.primary))
                    .disabled(isSubmitting)
                    .padding(.top, DSSpacing.sm)
                    .accessibilityIdentifier("reportUser.submit")
                }
                .padding(.horizontal, DSSpacing.lg)
                .padding(.vertical, DSSpacing.sm)
            }
        }
        .background(DSColor.background)
        .foregroundStyle(DSColor.textPrimary)
    }

    private func submit() async {
        isSubmitting = true
        errorMessage = nil
        defer { isSubmitting = false }
        let succeeded = await moderation.report(
            targetType: .user,
            targetId: authorId,
            reason: reason
        )
        if succeeded {
            dismiss()
        } else {
            errorMessage = moderation.errorMessage ?? "Could not submit report. Please try again."
        }
    }
}

#Preview("Author profile") {
    NavigationStack {
        AuthorProfileView(
            authorId: "jane",
            currentUserId: "preview_user",
            userProfiles: UserProfileStore(service: DemoUserProfileFunctions()),
            follows: FollowViewModel(ownerId: "preview_user", service: DemoFollowFunctions()),
            moderation: ModerationViewModel(ownerId: "preview_user", service: DemoModerationFunctions()),
            postService: DemoPostFunctions()
        )
    }
}
