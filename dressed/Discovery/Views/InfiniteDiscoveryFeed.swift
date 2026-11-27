import Combine
import SwiftUI

private final class FeedExposureTracker {
    var postCounts: [String: Int] = [:]
    var authorCounts: [String: Int] = [:]

    func record(post: Post) {
        postCounts[post.id, default: 0] += 1
        authorCounts[post.authorId, default: 0] += 1
    }
}

/// Paginates supplied Post snapshots and displays artwork supplied by the caller.
struct InfiniteDiscoveryFeed<Artwork: View>: View {
    @StateObject private var model: ChronologicalFeedModel
    @Binding private var section: Int
    @State private var nearBottom = false
    @State private var pageTask: Task<Void, Never>?
    @State private var itemsPost: Post?
    @State private var previewItemsPost: Post?
    @State private var selectedPost: Post?
    @State private var commentsPost: Post?
    @State private var previewCommentsPost: Post?
    @State private var lastCommentsPostId: String?
    @State private var commentService: any CommentService
    @State private var commentCounts: [String: Int] = [:]
    @State private var previewPosts: [Post] = []
    @State private var localDeletedPostIds: Set<String> = []
    private let externalDeletedPostIds: Binding<Set<String>>?
    @State private var refreshGeneration = 0
    @State private var exposureTracker = FeedExposureTracker()
    @State private var appliedPostExposureCounts: [String: Int] = [:]
    @State private var appliedAuthorExposureCounts: [String: Int] = [:]
    @State private var postPendingDelete: Post?
    @State private var previewPostPendingDelete: Post?
    @State private var postPendingReport: Post?
    @State private var previewPostPendingReport: Post?
    @State private var authorPendingBlock: String?
    @State private var previewAuthorPendingBlock: String?
    @State private var actionFeedback: String?
    @Binding private var showingCreate: Bool
    /// Set when the floating Search Styles button is tapped; the app shell presents the search sheet.
    @Binding private var isSearching: Bool
    @StateObject private var catalog = CatalogViewModel(service: DiscoveryCatalogSource.current)
    @ObservedObject private var postLikes: PostLikesViewModel
    @ObservedObject private var userProfiles: UserProfileStore
    @ObservedObject private var follows: FollowViewModel
    @ObservedObject private var moderation: ModerationViewModel
    private let hasFollowsFilter: Bool
    private let moderationEnabled: Bool
    private let postService: (any PostFunctions)?
    private let closetCategories: [ClothingCategory]
    private let onOpenProfile: ((String) -> Void)?
    private let canSharePreview: Bool
    private let authorId: String?
    private let publisher: (any PostPublishing)?
    private let compositionSource: (any PostCompositionSource)?
    private let artwork: (Post) -> Artwork
    private let ranker: FeedRanker
    private let rankingContext: FeedRankingContext
    private let accent = DSColor.brand
    private let columns = [GridItem(.flexible(), spacing: DSSpacing.md), GridItem(.flexible(), spacing: DSSpacing.md)]

    init(
        loadPage: @escaping ChronologicalFeedModel.PageLoader,
        ranker: FeedRanker = FeedRanker(),
        rankingContext: FeedRankingContext = .chronological(),
        section: Binding<Int> = .constant(0),
        showingCreate: Binding<Bool> = .constant(false),
        isSearching: Binding<Bool> = .constant(false),
        canSharePreview: Bool = false,
        commentService: (any CommentService)? = nil,
        authorId: String? = nil,
        publisher: (any PostPublishing)? = nil,
        compositionSource: (any PostCompositionSource)? = nil,
        postLikes: PostLikesViewModel,
        userProfiles: UserProfileStore? = nil,
        follows: FollowViewModel? = nil,
        moderation: ModerationViewModel? = nil,
        postService: (any PostFunctions)? = nil,
        closetCategories: [ClothingCategory] = [],
        externalDeletedPostIds: Binding<Set<String>>? = nil,
        onOpenProfile: ((String) -> Void)? = nil,
        @ViewBuilder artwork: @escaping (Post) -> Artwork
    ) {
        _model = StateObject(wrappedValue: ChronologicalFeedModel(loadPage: loadPage))
        self.ranker = ranker
        self.rankingContext = rankingContext
        self.artwork = artwork
        _section = section
        _showingCreate = showingCreate
        _isSearching = isSearching
        self.canSharePreview = canSharePreview
        _commentService = State(initialValue: commentService ?? FirebaseCommentService())
        self.authorId = authorId
        self.publisher = publisher
        self.compositionSource = compositionSource
        self.postLikes = postLikes
        self.userProfiles = userProfiles ?? UserProfileStore(service: DiscoveryPostSource.currentUserProfiles)
        self.hasFollowsFilter = follows != nil
        self.follows = follows ?? FollowViewModel(ownerId: authorId ?? "preview_user", service: DemoFollowFunctions())
        self.moderationEnabled = moderation != nil
        self.moderation = moderation ?? ModerationViewModel(ownerId: authorId ?? "preview_user", service: DemoModerationFunctions())
        self.postService = postService
        self.closetCategories = closetCategories
        self.externalDeletedPostIds = externalDeletedPostIds
        self.onOpenProfile = onOpenProfile
    }

    private var allDeletedPostIds: Set<String> {
        localDeletedPostIds.union(externalDeletedPostIds?.wrappedValue ?? [])
    }

    private var visiblePreviewPosts: [Post] {
        let deleted = allDeletedPostIds
        return previewPosts.filter { !deleted.contains($0.id) && !(moderationEnabled && moderation.isBlocked($0.authorId)) }
    }

    private var remainingPosts: [Post] {
        let insertedIds = Set(previewPosts.map(\.id))
        let deleted = allDeletedPostIds
        return model.posts.filter {
            !insertedIds.contains($0.id)
                && !deleted.contains($0.id)
                && !(moderationEnabled && moderation.isBlocked($0.authorId))
        }
    }

    private var categoryAffinity: [ClothingCategory: Double] {
        guard !closetCategories.isEmpty else { return [:] }
        var counts: [ClothingCategory: Int] = [:]
        for category in closetCategories {
            counts[category, default: 0] += 1
        }
        guard let maxCount = counts.values.max(), maxCount > 0 else { return [:] }
        var affinity: [ClothingCategory: Double] = [:]
        for (category, count) in counts {
            affinity[category] = Double(count) / Double(maxCount)
        }
        return affinity
    }

    private var effectiveRankingContext: FeedRankingContext {
        var context = rankingContext
        if context.followedAuthorIDs.isEmpty, hasFollowsFilter {
            context.followedAuthorIDs = follows.followingIds
        }
        if context.categoryAffinity.isEmpty {
            context.categoryAffinity = categoryAffinity
        }
        if context.postExposureCounts.isEmpty {
            context.postExposureCounts = appliedPostExposureCounts
        }
        if context.authorExposureCounts.isEmpty {
            context.authorExposureCounts = appliedAuthorExposureCounts
        }
        return context
    }

    private var forYouPosts: [Post] {
        visiblePreviewPosts + ranker.rank(remainingPosts, context: effectiveRankingContext).map(\.post)
    }

    private var friendsPosts: [Post] {
        let all = visiblePreviewPosts + remainingPosts
        guard hasFollowsFilter, follows.hasLoadedFollowing else { return all }
        return all.filter { post in
            follows.isFollowing(post.authorId) || (authorId != nil && post.authorId == authorId)
        }
    }

    private var loadedAuthorIds: [String] {
        (previewPosts + model.posts).map(\.authorId)
    }

    private var showFriendsEmptyState: Bool {
        section == 1
            && friendsPosts.isEmpty
            && model.hasLoaded
            && !model.isLoading
            && model.errorMessage == nil
            && hasFollowsFilter
            && follows.hasLoadedFollowing
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                LazyVStack(spacing: DSSpacing.lg) {
                    if section == 0 {
                        LazyVGrid(columns: columns, spacing: DSSpacing.md) {
                            ForEach(forYouEntries) { entry in
                                switch entry {
                                case .post(let post):
                                    Button { selectedPost = post } label: {
                                        // Fixed square first, photo filling it, so every tile is the same size
                                        // whatever the photo's own proportions.
                                        Color.clear
                                            .aspectRatio(1, contentMode: .fit)
                                            .overlay { artwork(post) }
                                            .clipShape(RoundedRectangle(cornerRadius: DSRadius.lg, style: .continuous))
                                    }
                                    .buttonStyle(.dsPress(0.98))
                                    .accessibilityLabel("\(post.caption), by \(userProfiles.displayName(for: post.authorId))")
                                    .accessibilityIdentifier("infinite.post.\(post.id)")
                                    .onAppear { exposureTracker.record(post: post) }
                                case .product(let product):
                                    DiscoveryRetailPhotoTile(product: product)
                                }
                            }
                        }
                    } else if showFriendsEmptyState {
                        DSEmptyState(
                            icon: "TablerUsers",
                            title: "No friends' posts yet",
                            message: "Follow people from For You to see their outfits here."
                        )
                        .padding(.top, DSSpacing.lg)
                    } else {
                        ForEach(friendsPosts) { post in
                            friendCard(post)
                        }
                    }
                    footer
                }
                .padding(.horizontal, DSSpacing.lg)
                .padding(.top, DSSpacing.md)
                .padding(.bottom, section == 0 ? DSFloatingSearchButton.height + 2 * DSSpacing.lg : DSSpacing.lg)
            }
            .accessibilityIdentifier("infinite.scroll")
            .onScrollGeometryChange(for: CGFloat?.self) { geometry in
                geometry.visibleRect.maxY >= geometry.contentSize.height - 240
                    ? geometry.contentSize.height
                    : nil
            } action: { _, nearBottomContentHeight in
                nearBottom = nearBottomContentHeight != nil
                loadNextPageIfNeeded()
            }
            .refreshable {
                // Await a separately owned task, as in the working manual preview.
                let refreshTask = Task { @MainActor in
                    appliedPostExposureCounts = exposureTracker.postCounts
                    appliedAuthorExposureCounts = exposureTracker.authorCounts
                    postLikes.reset()
                    commentCounts = [:]
                    refreshGeneration += 1
                    await model.refresh()
                }
                await refreshTask.value
            }
        }
        .background(DSColor.background)
        .tint(accent)
        .preferredColorScheme(.light)
        .navigationTitle("Discovery")
        .navigationBarTitleDisplayMode(.inline)
        .task { await model.loadInitial() }
        .task { catalog.search(query: "", category: nil) }
        .task(id: loadedAuthorIds) {
            await userProfiles.loadIfNeeded(userIds: loadedAuthorIds)
        }
        .onChange(of: section) { _, newSection in
            if newSection == 0 {
                appliedPostExposureCounts = exposureTracker.postCounts
                appliedAuthorExposureCounts = exposureTracker.authorCounts
            }
        }
        .overlay(alignment: .bottom) {
            if section == 0 {
                DSFloatingSearchButton(title: "Search Styles") { isSearching = true }
                    .accessibilityIdentifier("discovery.searchButton")
                    .padding(.horizontal, DSSpacing.lg)
                    .padding(.bottom, DSSpacing.sm)
            }
        }
        .onAppear { loadNextPageIfNeeded() }
        .onDisappear { pageTask?.cancel() }
        .navigationDestination(isPresented: $showingCreate) {
            OOTDCreatePostView(canShare: canSharePreview || (publisher != nil && authorId != nil), isDemo: canSharePreview, source: compositionSource) { draft in
                let post: Post
                if let publisher, let authorId {
                    post = try await publisher.publish(draft: draft, authorId: authorId)
                } else {
                    post = draft.post(authorId: authorId ?? "preview_user")
                }
                FirebasePublishedPostImageLoader.cache(draft: draft, post: post)
                previewPosts.removeAll { $0.id == post.id }
                previewPosts.insert(post, at: 0)
                section = 1
                showingCreate = false
            }
        }
        .sheet(item: $itemsPost) { post in
            PublishedOutfitDetailsView(post: post)
        }
        .sheet(item: $commentsPost, onDismiss: { refreshDismissedCommentCount() }) { post in
            PostCommentsSheet(
                postId: post.id,
                service: commentService,
                userProfiles: userProfiles,
                moderation: moderationEnabled ? moderation : nil
            )
        }
        .sheet(item: $selectedPost) { post in
            NavigationStack {
                ScrollView { friendCard(post, inPreview: true).padding(DSSpacing.lg) }
                    .background(DSColor.background)
                    .sheet(item: $previewItemsPost) { selected in
                        PublishedOutfitDetailsView(post: selected)
                    }
                    .sheet(item: $previewCommentsPost, onDismiss: { refreshDismissedCommentCount() }) { selected in
                        PostCommentsSheet(
                            postId: selected.id,
                            service: commentService,
                            userProfiles: userProfiles,
                            moderation: moderationEnabled ? moderation : nil
                        )
                    }
                    .modifier(
                        postActionDialogs(
                            deletePost: $previewPostPendingDelete,
                            reportPost: $previewPostPendingReport,
                            blockAuthor: $previewAuthorPendingBlock
                        )
                    )
                    .navigationTitle("Outfit preview")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") { selectedPost = nil }
                        }
                    }
            }
            .tint(accent)
        }
        .modifier(
            postActionDialogs(
                deletePost: $postPendingDelete,
                reportPost: $postPendingReport,
                blockAuthor: $authorPendingBlock
            )
        )
        .alert(
            "Notice",
            isPresented: Binding(
                get: { actionFeedback != nil },
                set: { if !$0 { actionFeedback = nil } }
            )
        ) {
            Button("OK", role: .cancel) { actionFeedback = nil }
        } message: {
            Text(actionFeedback ?? "")
        }
    }

    @ViewBuilder private var footer: some View {
        if model.isLoading {
            ProgressView(model.isRefreshing ? "Refreshing…" : "Loading outfits…")
                .font(DSFont.search)
                .foregroundStyle(DSColor.textMuted)
                .padding(DSSpacing.lg)
                .accessibilityIdentifier("infinite.loading")
        } else if let message = model.errorMessage {
            VStack(spacing: DSSpacing.md) {
                Text(message)
                    .font(DSFont.body)
                    .foregroundStyle(DSColor.textMuted)
                    .multilineTextAlignment(.center)
                Button("Retry") { Task { await model.retry() } }
                    .buttonStyle(.ds(.primary))
                    .accessibilityIdentifier("infinite.retry")
            }
            .padding(DSSpacing.lg)
        } else if showFriendsEmptyState {
            EmptyView()
        } else if model.hasLoaded && !model.hasMore {
            if remainingPosts.isEmpty && visiblePreviewPosts.isEmpty {
                DSEmptyState(
                    icon: "TablerHanger2",
                    title: "No outfits yet",
                    message: "Share your first look or check back soon."
                )
                .accessibilityIdentifier("infinite.end")
            } else {
                Label("You're all caught up", tabler: "TablerCircleCheck")
                    .font(DSFont.search)
                    .foregroundStyle(DSColor.textMuted)
                    .padding(DSSpacing.lg)
                    .accessibilityIdentifier("infinite.end")
            }
        }
    }

    private enum GridEntry: Identifiable {
        case post(Post)
        case product(CatalogProduct)

        var id: String {
            switch self {
            case .post(let post): "post.\(post.id)"
            case .product(let product): "product.\(product.id)"
            }
        }
    }

    /// Outfit photos with a retailer photo after every two outfits, while retailer products last.
    private var forYouEntries: [GridEntry] {
        var products: [CatalogProduct] = []
        if case .loaded(let loaded) = catalog.state { products = DiscoveryRetailPhotos.featured(loaded) }
        var entries: [GridEntry] = []
        for (index, post) in forYouPosts.enumerated() {
            entries.append(.post(post))
            if index % 2 == 1, !products.isEmpty { entries.append(.product(products.removeFirst())) }
        }
        return entries + products.map(GridEntry.product)
    }

    private func refreshDismissedCommentCount() {
        guard let postId = lastCommentsPostId else { return }
        lastCommentsPostId = nil
        Task { await refreshCommentCount(postId, force: true) }
    }

    private func loadNextPageIfNeeded() {
        guard nearBottom, model.hasMore, !model.isLoading, model.errorMessage == nil else { return }
        pageTask = Task { @MainActor in await model.loadMore() }
    }

    private func friendCard(_ post: Post, inPreview: Bool = false) -> some View {
        let like = postLikes.state(for: post)
        let commentCount = commentCounts[post.id] ?? 0
        let isOwnPost = authorId != nil && post.authorId == authorId
        return DSPostCard(
            handle: userProfiles.handle(for: post.authorId),
            date: Self.dateLabel(post.createdAt),
            caption: post.caption,
            commentCount: commentCount,
            commentCountText: commentCount >= 50 ? "50+" : nil,
            likeCount: like.likeCount,
            isLiked: like.isLiked,
            isLikeEnabled: like.isLoaded && !like.isPending && !like.isRemoved,
            likeLabel: like.isLiked ? "Unlike outfit" : "Like outfit",
            shopID: "infinite.items.\(post.id)",
            commentID: "infinite.comments.\(post.id)",
            likeID: "ootd.like.\(post.id)",
            errorMessage: like.errorMessage,
            onShop: { if inPreview { previewItemsPost = post } else { itemsPost = post } },
            onComment: {
                lastCommentsPostId = post.id
                if inPreview { previewCommentsPost = post } else { commentsPost = post }
            },
            onLike: { postLikes.toggle(post: post) },
            onRetryLike: like.isRemoved ? nil : { postLikes.retry(post: post) },
            onAuthorTap: onOpenProfile.map { cb in
                {
                    if inPreview { selectedPost = nil }
                    cb(post.authorId)
                }
            },
            isOwnPost: isOwnPost,
            onDelete: isOwnPost ? {
                if inPreview { previewPostPendingDelete = post } else { postPendingDelete = post }
            } : nil,
            onReport: (!isOwnPost && moderationEnabled) ? {
                if inPreview { previewPostPendingReport = post } else { postPendingReport = post }
            } : nil,
            onBlockAuthor: (!isOwnPost && moderationEnabled) ? {
                if inPreview { previewAuthorPendingBlock = post.authorId } else { authorPendingBlock = post.authorId }
            } : nil
        ) {
            artwork(post)
        }
        .task(id: "\(post.id)|\(refreshGeneration)") { await refreshCommentCount(post.id) }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("infinite.card.\(post.id)")
        .task(id: "\(post.id)|\(refreshGeneration)") { await postLikes.loadIfNeeded(post: post) }
    }

    private func postActionDialogs(
        deletePost: Binding<Post?>,
        reportPost: Binding<Post?>,
        blockAuthor: Binding<String?>
    ) -> PostActionDialogsModifier {
        PostActionDialogsModifier(
            deletePost: deletePost,
            reportPost: reportPost,
            blockAuthor: blockAuthor,
            handleForAuthor: { userProfiles.handle(for: $0) },
            onConfirmDelete: { post in
                Task { await delete(post: post) }
            },
            onConfirmReport: { post, reason in
                Task { await report(post: post, reason: reason) }
            },
            onConfirmBlock: { targetUserId in
                Task { await block(userId: targetUserId) }
            }
        )
    }

    private func delete(post: Post) async {
        do {
            if let postService {
                try await postService.deletePost(id: post.id)
            }
            localDeletedPostIds.insert(post.id)
            externalDeletedPostIds?.wrappedValue.insert(post.id)
            previewPosts.removeAll { $0.id == post.id }
            if selectedPost?.id == post.id {
                selectedPost = nil
            }
        } catch {
            actionFeedback = error.localizedDescription
        }
    }

    private func report(post: Post, reason: String) async {
        guard moderationEnabled else { return }
        let succeeded = await moderation.report(
            targetType: .post,
            targetId: post.id,
            postId: post.id,
            reason: reason
        )
        if succeeded {
            actionFeedback = "Thanks for letting us know. We've received your report."
        } else if let error = moderation.errorMessage {
            actionFeedback = error
        }
    }

    private func block(userId targetUserId: String) async {
        guard moderationEnabled else { return }
        await moderation.block(userId: targetUserId)
        if moderation.isBlocked(targetUserId), hasFollowsFilter, follows.isFollowing(targetUserId) {
            await follows.toggleFollow(targetUserId: targetUserId)
        }
        if selectedPost?.authorId == targetUserId {
            selectedPost = nil
        }
        if let error = moderation.errorMessage {
            actionFeedback = error
        }
    }

    private static func dateLabel(_ date: Date) -> String {
        let c = Calendar.current.dateComponents([.month, .day, .year], from: date)
        return String(format: "%02d.%02d.%02d", c.month ?? 0, c.day ?? 0, (c.year ?? 0) % 100)
    }

    // shortcut: counts via bounded fetch(postId:); upgrade to count() or denormalized commentCount when feed grows.
    private func refreshCommentCount(_ postId: String, force: Bool = false) async {
        guard force || commentCounts[postId] == nil else { return }
        if let fetched = try? await commentService.fetch(postId: postId) { commentCounts[postId] = fetched.count }
    }
}

private struct PostActionDialogsModifier: ViewModifier {
    @Binding var deletePost: Post?
    @Binding var reportPost: Post?
    @Binding var blockAuthor: String?
    let handleForAuthor: (String) -> String
    let onConfirmDelete: (Post) -> Void
    let onConfirmReport: (Post, String) -> Void
    let onConfirmBlock: (String) -> Void

    private static let reportReasons = [
        "Spam or misleading",
        "Inappropriate content",
        "Harassment or hate",
        "Copyright or impersonation"
    ]

    func body(content: Content) -> some View {
        content
            .confirmationDialog(
                "Delete post?",
                isPresented: Binding(
                    get: { deletePost != nil },
                    set: { if !$0 { deletePost = nil } }
                ),
                titleVisibility: .visible,
                presenting: deletePost
            ) { post in
                Button("Delete post", role: .destructive) {
                    deletePost = nil
                    onConfirmDelete(post)
                }
                Button("Cancel", role: .cancel) {
                    deletePost = nil
                }
            } message: { _ in
                Text("This permanently removes the post from Discovery.")
            }
            .confirmationDialog(
                "Report post",
                isPresented: Binding(
                    get: { reportPost != nil },
                    set: { if !$0 { reportPost = nil } }
                ),
                titleVisibility: .visible,
                presenting: reportPost
            ) { post in
                ForEach(Self.reportReasons, id: \.self) { reason in
                    Button(reason) {
                        reportPost = nil
                        onConfirmReport(post, reason)
                    }
                }
                Button("Cancel", role: .cancel) {
                    reportPost = nil
                }
            } message: { _ in
                Text("Choose a reason for reporting this post.")
            }
            .confirmationDialog(
                blockAuthor.map { "Block \(handleForAuthor($0))?" } ?? "Block user?",
                isPresented: Binding(
                    get: { blockAuthor != nil },
                    set: { if !$0 { blockAuthor = nil } }
                ),
                titleVisibility: .visible,
                presenting: blockAuthor
            ) { targetUserId in
                Button("Block user", role: .destructive) {
                    blockAuthor = nil
                    onConfirmBlock(targetUserId)
                }
                Button("Cancel", role: .cancel) {
                    blockAuthor = nil
                }
            } message: { _ in
                Text("You will no longer see posts or comments from this user.")
            }
    }
}

extension InfiniteDiscoveryFeed where Artwork == DemoOutfitPhoto {
    static func demo(
        failSecondPage: Bool = false,
        authorId: String? = "preview_user",
        section: Binding<Int> = .constant(0),
        showingCreate: Binding<Bool> = .constant(false),
        isSearching: Binding<Bool> = .constant(false),
        compositionSource: (any PostCompositionSource)? = nil,
        postLikes: PostLikesViewModel,
        userProfiles: UserProfileStore? = nil,
        follows: FollowViewModel? = nil,
        moderation: ModerationViewModel? = nil,
        closetCategories: [ClothingCategory] = [],
        deletedPostIds: Binding<Set<String>>? = nil,
        onOpenProfile: ((String) -> Void)? = nil
    ) -> Self {
        let fixtures = InfiniteFeedFixtures(failSecondPage: failSecondPage)
        return Self(
            loadPage: fixtures.loadPage,
            section: section,
            showingCreate: showingCreate,
            isSearching: isSearching,
            canSharePreview: true,
            commentService: DemoCommentService(),
            authorId: authorId,
            compositionSource: compositionSource,
            postLikes: postLikes,
            userProfiles: userProfiles,
            follows: follows,
            moderation: moderation,
            closetCategories: closetCategories,
            externalDeletedPostIds: deletedPostIds,
            onOpenProfile: onOpenProfile
        ) { post in
            DemoOutfitPhoto(post: post)
        }
    }
}

extension InfiniteDiscoveryFeed where Artwork == PostArtwork {
    static func live(
        service: any PostFunctions = DiscoveryPostSource.current,
        publisher: (any PostPublishing)? = nil,
        authorId: String,
        section: Binding<Int> = .constant(0),
        showingCreate: Binding<Bool> = .constant(false),
        isSearching: Binding<Bool> = .constant(false),
        compositionSource: (any PostCompositionSource)? = nil,
        postLikes: PostLikesViewModel,
        userProfiles: UserProfileStore? = nil,
        follows: FollowViewModel? = nil,
        moderation: ModerationViewModel? = nil,
        closetCategories: [ClothingCategory] = [],
        deletedPostIds: Binding<Set<String>>? = nil,
        onOpenProfile: ((String) -> Void)? = nil
    ) -> Self {
        Self(
            loadPage: { cursor in
                let decodedCursor = cursor.flatMap(Self.decodeCursor)
                let page = try await service.fetchPostPage(after: decodedCursor)
                return FeedPage(posts: page.posts, nextCursor: page.nextCursor.map(Self.encodeCursor), removedPostIDs: [])
            },
            section: section,
            showingCreate: showingCreate,
            isSearching: isSearching,
            authorId: authorId,
            publisher: publisher ?? FirebasePostPublisher(),
            compositionSource: compositionSource,
            postLikes: postLikes,
            userProfiles: userProfiles,
            follows: follows,
            moderation: moderation,
            postService: service,
            closetCategories: closetCategories,
            externalDeletedPostIds: deletedPostIds,
            onOpenProfile: onOpenProfile
        ) { post in
            PostArtwork(post: post)
        }
    }

    nonisolated private static func encodeCursor(_ cursor: PostPageCursor) -> String {
        "\(cursor.createdAt.timeIntervalSince1970)|\(cursor.id)"
    }

    nonisolated private static func decodeCursor(_ value: String) -> PostPageCursor? {
        guard let separator = value.firstIndex(of: "|"),
              let seconds = TimeInterval(value[..<separator]) else { return nil }
        let id = String(value[value.index(after: separator)...])
        guard isValidFirestoreDocumentId(id) else { return nil }
        return PostPageCursor(createdAt: Date(timeIntervalSince1970: seconds), id: id)
    }
}

#Preview("Infinite scroll · For You & Friends") {
    NavigationStack {
        InfiniteDiscoveryFeed.demo(
            postLikes: PostLikesViewModel(ownerId: "preview", service: DemoPostLikeFunctions())
        )
    }
}

#Preview("Infinite scroll · Retry scenario") {
    NavigationStack {
        InfiniteDiscoveryFeed.demo(
            failSecondPage: true,
            postLikes: PostLikesViewModel(ownerId: "preview", service: DemoPostLikeFunctions())
        )
    }
}
