import SwiftUI

/// Paginates supplied Post snapshots and displays artwork supplied by the caller.
struct InfiniteDiscoveryFeed<Artwork: View>: View {
    private enum FeedTab: String {
        case forYou = "For You"
        case friends = "Friends"
    }

    @StateObject private var model: ChronologicalFeedModel
    @State private var section: FeedTab = .forYou
    @State private var nearBottom = false
    @State private var pageTask: Task<Void, Never>?
    @State private var selectedPost: Post?
    @State private var likedIDs: Set<String> = []
    private let artwork: (Post) -> Artwork
    private let accent = Color(red: 0.61, green: 0.48, blue: 0.91)
    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    init(loadPage: @escaping ChronologicalFeedModel.PageLoader, @ViewBuilder artwork: @escaping (Post) -> Artwork) {
        _model = StateObject(wrappedValue: ChronologicalFeedModel(loadPage: loadPage))
        self.artwork = artwork
    }

    var body: some View {
        VStack(spacing: 0) {
            sectionPicker
            ScrollView {
                LazyVStack(spacing: 20) {
                    if section == .forYou {
                        LazyVGrid(columns: columns, spacing: 12) {
                            ForEach(model.posts) { post in
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
                        ForEach(model.posts) { post in
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
        .onAppear { loadNextPageIfNeeded() }
        .onDisappear { pageTask?.cancel() }
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

    private var sectionPicker: some View {
        Picker("Discovery feed", selection: $section) {
            Text(FeedTab.forYou.rawValue).tag(FeedTab.forYou)
            Text(FeedTab.friends.rawValue).tag(FeedTab.friends)
        }
        .pickerStyle(.segmented)
        .frame(maxWidth: 260)
        .padding(.vertical, 20)
        .accessibilityIdentifier("infinite.sections")
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
            Label(model.posts.isEmpty ? "No outfits yet" : "You're all caught up", systemImage: "checkmark.circle")
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
                Text(post.caption).font(.body.weight(.medium))
                    .frame(maxWidth: .infinity, alignment: .leading)
                Button {
                    if !likedIDs.insert(post.id).inserted { likedIDs.remove(post.id) }
                } label: {
                    Image(systemName: likedIDs.contains(post.id) ? "heart.fill" : "heart")
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
        .accessibilityIdentifier("infinite.card.\(post.id)")
    }
}

extension InfiniteDiscoveryFeed where Artwork == DemoOutfitPhoto {
    static func demo(failSecondPage: Bool = false) -> Self {
        let fixtures = InfiniteFeedFixtures(failSecondPage: failSecondPage)
        return Self(loadPage: fixtures.loadPage) { post in
            DemoOutfitPhoto(post: post)
        }
    }
}

#Preview("Infinite scroll · For You & Friends") {
    NavigationStack { InfiniteDiscoveryFeed.demo() }
}

#Preview("Infinite scroll · Retry scenario") {
    NavigationStack { InfiniteDiscoveryFeed.demo(failSecondPage: true) }
}
