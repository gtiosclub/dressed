import SwiftUI

/// The signed-in user's saved posts, opened from the OOTD feed. Like a post card in the feed, tapping
/// a saved post opens its published pieces rather than a separate post page.
struct SavedPostsView: View {
    @ObservedObject var model: SavedPostsViewModel
    @State private var itemsPost: Post?

    var body: some View {
        content
            .navigationTitle("Saved Posts")
            .navigationBarTitleDisplayMode(.large)
            .toolbar(.visible, for: .navigationBar)
            .task { await model.refresh() }
            .sheet(item: $itemsPost) { post in
                OOTDItemsSheet(post: post)
                    .presentationDetents([.fraction(0.48), .large])
                    .presentationDragIndicator(.visible)
            }
    }

    @ViewBuilder
    private var content: some View {
        if model.isLoading {
            ProgressView("Loading your saved posts")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .accessibilityIdentifier("savedPosts.loading")
        } else if !model.state.hasLoaded {
            FeedStatusView(status: .error(message: "Couldn't load your saved posts."), onRetry: retry)
        } else {
            // The banner scrolls with the grid. Placed above the scroll view, it hides the large title.
            ScrollView {
                VStack(spacing: 0) {
                    if model.state.refreshFailed {
                        refreshFailedBanner
                    }
                    SavedPostGrid(
                        entries: model.state.gridEntries,
                        onPostTap: { itemsPost = $0 },
                        control: { entry in SavedPostControl(postId: entry.id, model: model) }
                    )
                }
            }
            .refreshable { await model.refresh() }
            .accessibilityIdentifier("savedPosts.content")
        }
    }

    private var refreshFailedBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle")
                .accessibilityHidden(true)
            Text("Couldn't refresh. Showing your last saved posts.")
                .font(.footnote)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button("Retry", action: retry)
                .buttonStyle(.bordered)
                .tint(.primary)
                .accessibilityIdentifier("savedPosts.retry")
        }
        .padding(12)
        .background(Color.orange.opacity(0.15), in: RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }

    private func retry() {
        Task { await model.refresh() }
    }
}

#Preview("Saved posts") {
    NavigationStack {
        SavedPostsView(model: SavedPostsViewModel(
            ownerId: "preview_user",
            saves: DemoSavedPostFunctions(arguments: ["-seedSavedPosts"]),
            posts: DemoPostFunctions()
        ))
    }
}

#Preview("Couldn't load") {
    NavigationStack {
        SavedPostsView(model: SavedPostsViewModel(
            ownerId: "preview_user",
            saves: DemoSavedPostFunctions(arguments: ["-failSavedPostReads", "1"]),
            posts: DemoPostFunctions()
        ))
    }
}
