import SwiftUI

/// Paginates supplied Post snapshots and displays artwork supplied by the caller.
struct InfiniteDiscoveryFeed<Artwork: View>: View {
    @StateObject private var model: ChronologicalFeedModel
    @Binding private var section: Int
    @State private var nearBottom = false
    @State private var pageTask: Task<Void, Never>?
    @State private var selectedPost: Post?
    @State private var commentsPost: Post?
    @State private var previewCommentsPost: Post?
    @State private var commentService: any CommentService
    @State private var commentCounts: [String: Int] = [:]
    @State private var previewPosts: [Post] = []
    @Binding private var showingCreate: Bool
    /// Set when the floating Search Styles button is tapped; the app shell presents the search sheet.
    @Binding private var isSearching: Bool
    @StateObject private var catalog = CatalogViewModel(service: DiscoveryCatalogSource.current)
    private let savedPosts: SavedPostsViewModel?
    @ObservedObject private var postLikes: PostLikesViewModel
    private let canSharePreview: Bool
    private let authorId: String?
    private let publisher: (any PostPublishing)?
    private let artwork: (Post) -> Artwork
    private let ranker: FeedRanker
    private let rankingContext: FeedRankingContext
    private let accent = DSColor.brand
    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

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
        savedPosts: SavedPostsViewModel? = nil,
        postLikes: PostLikesViewModel,
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
        self.savedPosts = savedPosts
        self.postLikes = postLikes
    }

    private var forYouPosts: [Post] {
        previewPosts + ranker.rank(model.posts, context: rankingContext).map(\.post)
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                LazyVStack(spacing: 20) {
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
                                    .accessibilityLabel("\(post.caption), by \(post.authorId)")
                                    .accessibilityIdentifier("infinite.post.\(post.id)")
                                case .product(let product):
                                    DiscoveryRetailPhotoTile(product: product)
                                }
                            }
                        }
                    } else {
                        ForEach(previewPosts + model.posts) { post in
                            friendCard(post)
                        }
                    }
                    footer
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, section == 0 ? DSFloatingSearchButton.height + 2 * DSSpacing.lg : 24)
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
                let refreshTask = Task { @MainActor in await model.refresh() }
                await refreshTask.value
            }
        }
        .background(.white)
        .tint(accent)
        .preferredColorScheme(.light)
        .navigationTitle("Discovery")
        .navigationBarTitleDisplayMode(.inline)
        .task { await model.loadInitial() }
        .task { catalog.search(query: "", category: nil) }
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
            OOTDCreatePostView(canShare: canSharePreview || (publisher != nil && authorId != nil)) { caption in
                if let publisher, let authorId {
                    let post = try await publisher.publish(caption: caption, authorId: authorId)
                    previewPosts.insert(post, at: 0)
                } else {
                    previewPosts.insert(Post(
                        id: "demo_post_\(UUID().uuidString)", schemaVersion: 1,
                        authorId: "you", caption: caption.isEmpty ? "caption (optional)" : caption,
                        outfitSnapshot: PublishedOutfitSnapshot(name: nil, items: []),
                        mediaPath: "", createdAt: .now
                    ), at: 0)
                }
                section = 1
                showingCreate = false
            }
        }
        .sheet(item: $commentsPost, onDismiss: { refreshAllCounts() }) { post in
            PostCommentsSheet(postId: post.id, service: commentService)
        }
        .sheet(item: $selectedPost) { post in
            NavigationStack {
                ScrollView { friendCard(post, inPreview: true).padding(20) }
                    .sheet(item: $previewCommentsPost, onDismiss: { refreshAllCounts() }) { selected in
                        PostCommentsSheet(postId: selected.id, service: commentService)
                    }
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
    }

    @ViewBuilder private var footer: some View {
        if model.isLoading {
            ProgressView(model.isRefreshing ? "Refreshing…" : "Loading outfits…")
                .padding()
                .accessibilityIdentifier("infinite.loading")
        } else if let message = model.errorMessage {
            VStack(spacing: 10) {
                Text(message).font(.subheadline).multilineTextAlignment(.center)
                Button("Retry") { Task { await model.retry() } }
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("infinite.retry")
            }
            .padding()
        } else if model.hasLoaded && !model.hasMore {
            Label(model.posts.isEmpty ? "No outfits yet" : "You're all caught up", tabler: "TablerCircleCheck")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding()
                .accessibilityIdentifier("infinite.end")
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

    private func refreshAllCounts() {
        Task { for id in Array(commentCounts.keys) { await refreshCommentCount(id) } }
    }

    private func loadNextPageIfNeeded() {
        guard nearBottom, model.hasMore, !model.isLoading, model.errorMessage == nil else { return }
        pageTask = Task { @MainActor in await model.loadMore() }
    }

    private func friendCard(_ post: Post, inPreview: Bool = false) -> some View {
        let like = postLikes.state(for: post)
        return DSPostCard(
            handle: "@\(post.authorId)",
            date: Self.dateLabel(post.createdAt),
            caption: post.caption,
            commentCount: commentCounts[post.id] ?? 0,
            likeCount: like.likeCount,
            isLiked: like.isLiked,
            isLikeEnabled: like.isLoaded && !like.isPending,
            likeLabel: like.isLiked ? "Unlike outfit" : "Like outfit",
            commentID: "infinite.comments.\(post.id)",
            likeID: "ootd.like.\(post.id)",
            onComment: { if inPreview { previewCommentsPost = post } else { commentsPost = post } },
            onLike: { postLikes.toggle(post: post) }
        ) {
            artwork(post)
        }
        .task(id: post.id) { await refreshCommentCount(post.id) }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("infinite.card.\(post.id)")
        .task { await postLikes.loadIfNeeded(post: post) }
    }

    private static func dateLabel(_ date: Date) -> String {
        let c = Calendar.current.dateComponents([.month, .day, .year], from: date)
        return String(format: "%02d.%02d.%02d", c.month ?? 0, c.day ?? 0, (c.year ?? 0) % 100)
    }

    private func refreshCommentCount(_ postId: String) async {
        if let fetched = try? await commentService.fetch(postId: postId) { commentCounts[postId] = fetched.count }
    }
}

extension InfiniteDiscoveryFeed where Artwork == DemoOutfitPhoto {
    static func demo(
        failSecondPage: Bool = false,
        section: Binding<Int> = .constant(0),
        showingCreate: Binding<Bool> = .constant(false),
        isSearching: Binding<Bool> = .constant(false),
        savedPosts: SavedPostsViewModel? = nil,
        postLikes: PostLikesViewModel
    ) -> Self {
        let fixtures = InfiniteFeedFixtures(failSecondPage: failSecondPage)
        return Self(
            loadPage: fixtures.loadPage,
            section: section,
            showingCreate: showingCreate,
            isSearching: isSearching,
            canSharePreview: true,
            commentService: DemoCommentService(),
            savedPosts: savedPosts,
            postLikes: postLikes
        ) { post in
            DemoOutfitPhoto(post: post)
        }
    }
}

extension InfiniteDiscoveryFeed where Artwork == PostArtwork {
    /// The current post service returns one bounded chronological result set.
    /// It can adopt cursor-based paging here once PostFunctions exposes a cursor contract.
    static func live(
        service: any PostFunctions = DiscoveryPostSource.current,
        publisher: any PostPublishing = FirebasePostPublisher(),
        authorId: String,
        section: Binding<Int> = .constant(0),
        showingCreate: Binding<Bool> = .constant(false),
        isSearching: Binding<Bool> = .constant(false),
        savedPosts: SavedPostsViewModel? = nil,
        postLikes: PostLikesViewModel
    ) -> Self {
        Self(loadPage: { cursor in
            guard cursor == nil else {
                return FeedPage(posts: [], nextCursor: nil, removedPostIDs: [])
            }
            return FeedPage(
                posts: try await service.fetchRecentPosts(),
                nextCursor: nil,
                removedPostIDs: []
            )
        }, section: section, showingCreate: showingCreate, isSearching: isSearching, authorId: authorId,
           publisher: publisher, savedPosts: savedPosts,
           postLikes: postLikes) { post in
            PostArtwork(post: post)
        }
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
