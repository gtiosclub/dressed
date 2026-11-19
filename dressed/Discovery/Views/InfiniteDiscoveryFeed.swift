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
    @State private var previewPosts: [Post] = []
    @Binding private var showingCreate: Bool
    @State private var showingSaved = false
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
            if savedPosts != nil {
                HStack {
                    Spacer()
                    DSCircleButton(content: .icon("TablerBookmark"), accessibilityLabel: "Saved Posts") {
                        showingSaved = true
                    }
                    .accessibilityIdentifier("ootd.savedPosts")
                }
                .padding(.horizontal, DSSpacing.lg)
            }
            ScrollView {
                LazyVStack(spacing: 20) {
                    if section == 0 {
                        DiscoveryRetailShelf()
                        LazyVGrid(columns: columns, spacing: 12) {
                            ForEach(forYouPosts) { post in
                                Button { selectedPost = post } label: {
                                    artwork(post)
                                        .aspectRatio(1, contentMode: .fit)
                                        .clipShape(RoundedRectangle(cornerRadius: 24))
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("\(post.caption), by \(post.authorId)")
                                .accessibilityIdentifier("infinite.post.\(post.id)")
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
                .padding(.bottom, 24)
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
        .task { await savedPosts?.loadIfNeeded() }
        .navigationDestination(isPresented: $showingSaved) {
            if let savedPosts { SavedPostsView(model: savedPosts) }
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
        .sheet(item: $commentsPost) { post in
            PostCommentsSheet(postId: post.id, service: commentService)
        }
        .sheet(item: $selectedPost) { post in
            NavigationStack {
                ScrollView { friendCard(post, inPreview: true).padding(20) }
                    .sheet(item: $previewCommentsPost) { selected in
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

    private func loadNextPageIfNeeded() {
        guard nearBottom, model.hasMore, !model.isLoading, model.errorMessage == nil else { return }
        pageTask = Task { @MainActor in await model.loadMore() }
    }

    private func friendCard(_ post: Post, inPreview: Bool = false) -> some View {
        let like = postLikes.state(for: post)
        return VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("@\(post.authorId)").fontWeight(.semibold)
                Text(post.createdAt, format: .dateTime.month(.twoDigits).day(.twoDigits).year(.twoDigits))
                    .foregroundStyle(.secondary)
            }
            .font(.subheadline)
            .padding(16)

            artwork(post)
                .aspectRatio(0.82, contentMode: .fit)

            HStack(alignment: .center, spacing: 12) {
                Text(post.caption).font(.body.weight(.medium))
                    .frame(maxWidth: .infinity, alignment: .leading)
                Button {
                    if inPreview { previewCommentsPost = post } else { commentsPost = post }
                } label: {
                    DSIcon("TablerMessageCircle", size: 20)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Comments")
                .accessibilityIdentifier("infinite.comments.\(post.id)")
                Button { postLikes.toggle(post: post) } label: {
                    DSIcon(like.isLiked ? "TablerHeartFilled" : "TablerHeart", size: 20)
                        .font(.title3)
                        .foregroundStyle(like.isLiked ? accent : .black)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .disabled(!like.isLoaded || like.isPending)
                .accessibilityLabel(like.isLiked ? "Unlike outfit" : "Like outfit")
                .accessibilityValue("\(like.likeCount) likes\(like.isPending ? ", updating" : "")")
                .accessibilityIdentifier("ootd.like.\(post.id)")
                Text("\(like.likeCount)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            if let savedPosts, !previewPosts.contains(where: { $0.id == post.id }) {
                SavedPostControl(postId: post.id, post: post, model: savedPosts)
                    .padding(DSSpacing.md)
            }
        }
        .background(Color(white: 0.98))
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(accent.opacity(0.22)))
        .shadow(color: accent.opacity(0.12), radius: 8, y: 4)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("infinite.card.\(post.id)")
        .task { await postLikes.loadIfNeeded(post: post) }
    }
}

extension InfiniteDiscoveryFeed where Artwork == DemoOutfitPhoto {
    static func demo(
        failSecondPage: Bool = false,
        section: Binding<Int> = .constant(0),
        showingCreate: Binding<Bool> = .constant(false),
        savedPosts: SavedPostsViewModel? = nil,
        postLikes: PostLikesViewModel
    ) -> Self {
        let fixtures = InfiniteFeedFixtures(failSecondPage: failSecondPage)
        return Self(
            loadPage: fixtures.loadPage,
            section: section,
            showingCreate: showingCreate,
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
        }, section: section, showingCreate: showingCreate, authorId: authorId,
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
