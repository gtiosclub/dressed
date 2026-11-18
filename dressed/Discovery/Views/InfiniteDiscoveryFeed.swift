import SwiftUI

/// Paginates supplied Post snapshots and displays artwork supplied by the caller.
struct InfiniteDiscoveryFeed<Artwork: View>: View {
    @StateObject private var model: ChronologicalFeedModel
    @Binding private var section: Int
    @State private var nearBottom = false
    @State private var pageTask: Task<Void, Never>?
    @State private var selectedPost: Post?
    @State private var likedIDs: Set<String> = []
    @State private var previewPosts: [Post] = []
    @Binding private var showingCreate: Bool
    @State private var showingSaved = false
    private let savedPosts: SavedPostsViewModel?
    private let canSharePreview: Bool
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
        savedPosts: SavedPostsViewModel? = nil,
        @ViewBuilder artwork: @escaping (Post) -> Artwork
    ) {
        _model = StateObject(wrappedValue: ChronologicalFeedModel(loadPage: loadPage))
        self.ranker = ranker
        self.rankingContext = rankingContext
        self.artwork = artwork
        _section = section
        _showingCreate = showingCreate
        self.canSharePreview = canSharePreview
        self.savedPosts = savedPosts
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
            OOTDCreatePostView(canSharePreview: canSharePreview) { caption in
                previewPosts.insert(Post(
                    id: "demo_post_\(UUID().uuidString)", schemaVersion: 1,
                    authorId: "you", caption: caption.isEmpty ? "caption (optional)" : caption,
                    outfitSnapshot: PublishedOutfitSnapshot(name: nil, items: []),
                    mediaPath: "", createdAt: .now
                ), at: 0)
                section = 1
                showingCreate = false
            }
        }
        .sheet(item: $selectedPost) { post in
            NavigationStack {
                ScrollView { friendCard(post).padding(20) }
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

    private func friendCard(_ post: Post) -> some View {
        VStack(alignment: .leading, spacing: 0) {
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
                if let savedPosts, !previewPosts.contains(where: { $0.id == post.id }) {
                    SavedPostControl(postId: post.id, post: post, model: savedPosts)
                }
                Text(post.caption).font(.body.weight(.medium))
                    .frame(maxWidth: .infinity, alignment: .leading)
                Button {
                    if !likedIDs.insert(post.id).inserted { likedIDs.remove(post.id) }
                } label: {
                    DSIcon(likedIDs.contains(post.id) ? "TablerHeartFilled" : "TablerHeart", size: 20)
                        .font(.title3)
                        .foregroundStyle(likedIDs.contains(post.id) ? accent : .black)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(likedIDs.contains(post.id) ? "Unlike outfit" : "Like outfit")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .background(Color(white: 0.98))
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(accent.opacity(0.22)))
        .shadow(color: accent.opacity(0.12), radius: 8, y: 4)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("infinite.card.\(post.id)")
    }
}

extension InfiniteDiscoveryFeed where Artwork == DemoOutfitPhoto {
    static func demo(
        failSecondPage: Bool = false,
        section: Binding<Int> = .constant(0),
        showingCreate: Binding<Bool> = .constant(false),
        savedPosts: SavedPostsViewModel? = nil
    ) -> Self {
        let fixtures = InfiniteFeedFixtures(failSecondPage: failSecondPage)
        return Self(
            loadPage: fixtures.loadPage,
            section: section,
            showingCreate: showingCreate,
            canSharePreview: true,
            savedPosts: savedPosts
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
        section: Binding<Int> = .constant(0),
        showingCreate: Binding<Bool> = .constant(false),
        savedPosts: SavedPostsViewModel? = nil
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
        }, section: section, showingCreate: showingCreate, savedPosts: savedPosts) { post in
            PostArtwork(post: post)
        }
    }
}

#Preview("Infinite scroll · For You & Friends") {
    NavigationStack { InfiniteDiscoveryFeed.demo() }
}

#Preview("Infinite scroll · Retry scenario") {
    NavigationStack { InfiniteDiscoveryFeed.demo(failSecondPage: true) }
}
