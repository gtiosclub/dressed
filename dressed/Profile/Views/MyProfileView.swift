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
    var onBack: (() -> Void)? = nil
    var ownerId: String? = nil
    var userProfiles: UserProfileStore? = nil
    var follows: FollowViewModel? = nil
    var onDeletePost: ((Post) async throws -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @State private var confirmingSignOut = false
    @State private var isEditingProfile = false
    @State private var selectedPost: Post?

    private let columns = Array(repeating: GridItem(.flexible(), spacing: DSSpacing.xxs), count: 3)

    var body: some View {
        VStack(spacing: 0) {
            DSBackHeader(title: "Profile") { (onBack ?? { dismiss() })() }
                .padding(.horizontal, DSSpacing.lg)
                .padding(.top, DSSpacing.sm)
                .padding(.bottom, DSSpacing.md)

            ScrollView {
                VStack(alignment: .leading, spacing: DSSpacing.lg) {
                    headerSection

                    if userProfiles != nil, ownerId != nil {
                        Button {
                            isEditingProfile = true
                        } label: {
                            Text("Edit Profile").frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.ds(.secondary))
                        .padding(.horizontal, DSSpacing.lg)
                        .accessibilityIdentifier("profile.editProfile")
                    }

                    statsSection

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
            .refreshable { await loadAll() }
        }
        .background(DSColor.background)
        .foregroundStyle(DSColor.textPrimary)
        .toolbar(.hidden, for: .navigationBar)
        .task { await loadAll() }
        .confirmationDialog("Sign out of Dressed?", isPresented: $confirmingSignOut, titleVisibility: .visible) {
            Button("Sign Out", role: .destructive, action: onSignOut)
            Button("Cancel", role: .cancel) {}
        }
        .sheet(isPresented: $isEditingProfile) {
            if let userProfiles, let ownerId {
                EditProfileSheet(
                    ownerId: ownerId,
                    userProfiles: userProfiles,
                    fallbackName: name
                )
            }
        }
        .sheet(item: $selectedPost) { post in
            MyPostPreviewSheet(
                post: post,
                onDeletePost: onDeletePost,
                onDeleted: { deletedId in
                    model.removePost(id: deletedId)
                }
            )
        }
    }

    private func loadAll() async {
        async let postsLoad: Void = model.load()
        async let profileLoad: Void = loadProfileIfNeeded()
        async let countsLoad: Void = loadFollowCountsIfNeeded()
        _ = await (postsLoad, profileLoad, countsLoad)
    }

    private func loadProfileIfNeeded() async {
        guard let userProfiles, let ownerId else { return }
        await userProfiles.loadIfNeeded(userIds: [ownerId])
    }

    private func loadFollowCountsIfNeeded() async {
        guard let follows, let ownerId else { return }
        await follows.loadCounts(for: ownerId)
    }

    private var closetSummary: String {
        "\(pieceCount) \(pieceCount == 1 ? "piece" : "pieces") · \(outfitCount) \(outfitCount == 1 ? "outfit" : "outfits")"
    }

    // MARK: - Header

    @ViewBuilder private var headerSection: some View {
        if let userProfiles, let ownerId {
            ObservedProfileHeader(
                userProfiles: userProfiles,
                ownerId: ownerId,
                fallbackName: name,
                detail: closetSummary
            )
            .padding(.horizontal, DSSpacing.lg)
            .accessibilityIdentifier("profile.header")
        } else {
            ProfileHeader(name: name ?? "Your profile", detail: closetSummary)
                .padding(.horizontal, DSSpacing.lg)
                .accessibilityIdentifier("profile.header")
        }
    }

    // MARK: - Stats

    @ViewBuilder private var statsSection: some View {
        if let follows, let ownerId {
            ObservedFollowStats(
                follows: follows,
                ownerId: ownerId,
                postCount: model.postCount
            )
        } else {
            ProfileStatsRow(
                postCount: model.postCount,
                followerCount: nil,
                followingCount: nil
            )
        }
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
                    Button {
                        selectedPost = post
                    } label: {
                        Color.clear
                            .aspectRatio(1, contentMode: .fit)
                            .overlay { PostArtwork(post: post, cornerRadius: 0) }
                            .clipped()
                    }
                    .buttonStyle(.plain)
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

private struct ObservedProfileHeader: View {
    @ObservedObject var userProfiles: UserProfileStore
    let ownerId: String
    let fallbackName: String?
    let detail: String

    var body: some View {
        let profile = userProfiles.profile(for: ownerId)
        let resolvedName: String = {
            if let displayName = profile?.displayName, !displayName.isEmpty {
                return displayName
            }
            return fallbackName ?? "Your profile"
        }()
        let resolvedUsername: String? = {
            if let username = profile?.username, !username.isEmpty {
                return username
            }
            return nil
        }()
        ProfileHeader(name: resolvedName, username: resolvedUsername, detail: detail)
    }
}

private struct ObservedFollowStats: View {
    @ObservedObject var follows: FollowViewModel
    let ownerId: String
    let postCount: Int?

    var body: some View {
        ProfileStatsRow(
            postCount: postCount,
            followerCount: follows.followerCounts[ownerId],
            followingCount: follows.followingCounts[ownerId]
        )
    }
}

private struct ProfileStatsRow: View {
    let postCount: Int?
    let followerCount: Int?
    let followingCount: Int?

    var body: some View {
        HStack(spacing: 0) {
            stat(value: postCount.map(String.init), label: "Posts", id: "posts")
            stat(value: followerCount.map(String.init), label: "Followers", id: "followers")
            stat(value: followingCount.map(String.init), label: "Following", id: "following")
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
}

private struct EditProfileSheet: View {
    let ownerId: String
    @ObservedObject var userProfiles: UserProfileStore
    let fallbackName: String?

    @Environment(\.dismiss) private var dismiss
    @State private var displayName = ""
    @State private var username = ""
    @State private var errorMessage: String?
    @State private var isSaving = false

    var body: some View {
        VStack(spacing: 0) {
            DSBackHeader(title: "Edit Profile") { dismiss() }
                .padding(.horizontal, DSSpacing.lg)
                .padding(.top, DSSpacing.lg)
                .padding(.bottom, DSSpacing.md)

            ScrollView {
                VStack(alignment: .leading, spacing: DSSpacing.md) {
                    DSLabeledField(label: "Display Name", prompt: "Your name", text: $displayName)
                        .accessibilityIdentifier("editProfile.displayName")

                    DSLabeledField(label: "Username", prompt: "username", text: $username)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .accessibilityIdentifier("editProfile.username")

                    if let errorMessage {
                        Text(errorMessage)
                            .font(DSFont.search)
                            .foregroundStyle(DSColor.destructive)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityIdentifier("editProfile.error")
                    }

                    Button {
                        Task { await save() }
                    } label: {
                        if isSaving {
                            ProgressView()
                                .tint(Color.white)
                                .frame(maxWidth: .infinity)
                        } else {
                            Text("Save").frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(.ds(.primary))
                    .disabled(isSaving)
                    .padding(.top, DSSpacing.sm)
                    .accessibilityIdentifier("editProfile.save")
                }
                .padding(.horizontal, DSSpacing.lg)
                .padding(.vertical, DSSpacing.sm)
            }
        }
        .background(DSColor.background)
        .foregroundStyle(DSColor.textPrimary)
        .onAppear {
            if let existing = userProfiles.profile(for: ownerId) {
                displayName = existing.displayName
                username = existing.username
            } else {
                displayName = fallbackName ?? ""
                username = ""
            }
        }
    }

    private func save() async {
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }
        do {
            try await userProfiles.saveOwnProfile(
                userId: ownerId,
                username: username,
                displayName: displayName
            )
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct MyPostPreviewSheet: View {
    let post: Post
    let onDeletePost: ((Post) async throws -> Void)?
    let onDeleted: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var confirmingDelete = false
    @State private var isDeleting = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            DSBackHeader(title: "Post") { dismiss() }
                .padding(.horizontal, DSSpacing.lg)
                .padding(.top, DSSpacing.lg)
                .padding(.bottom, DSSpacing.md)

            ScrollView {
                VStack(alignment: .leading, spacing: DSSpacing.md) {
                    Color.clear
                        .aspectRatio(3 / 4, contentMode: .fit)
                        .overlay { PostArtwork(post: post, cornerRadius: DSRadius.lg) }
                        .clipShape(RoundedRectangle(cornerRadius: DSRadius.lg, style: .continuous))

                    if !post.caption.isEmpty {
                        Text(post.caption)
                            .font(DSFont.body)
                            .foregroundStyle(DSColor.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .font(DSFont.search)
                            .foregroundStyle(DSColor.destructive)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if onDeletePost != nil {
                        Button(role: .destructive) {
                            confirmingDelete = true
                        } label: {
                            if isDeleting {
                                ProgressView()
                                    .frame(maxWidth: .infinity)
                            } else {
                                Text("Delete Post")
                                    .foregroundStyle(DSColor.destructive)
                                    .frame(maxWidth: .infinity)
                            }
                        }
                        .buttonStyle(.ds(.secondary))
                        .disabled(isDeleting)
                        .padding(.top, DSSpacing.sm)
                        .accessibilityIdentifier("profile.postPreview.delete")
                    }
                }
                .padding(.horizontal, DSSpacing.lg)
                .padding(.bottom, DSSpacing.lg)
            }
        }
        .background(DSColor.background)
        .foregroundStyle(DSColor.textPrimary)
        .confirmationDialog("Delete this post?", isPresented: $confirmingDelete, titleVisibility: .visible) {
            Button("Delete Post", role: .destructive) {
                Task { await deletePost() }
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    private func deletePost() async {
        guard let onDeletePost else { return }
        isDeleting = true
        errorMessage = nil
        defer { isDeleting = false }
        do {
            try await onDeletePost(post)
            onDeleted(post.id)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
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
