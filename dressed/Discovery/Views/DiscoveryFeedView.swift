import SwiftUI

struct DiscoveryFeedView: View {
    @StateObject private var model: DiscoveryFeedViewModel
    let dismissRequest: Int
    @State private var query = ""
    @State private var submittedQuery = ""
    @State private var isSearchActive = false
    @State private var isSearchFieldFocused = false
    @State private var selectedStyles: [String] = []
    @State private var dismissedStyles: Set<String> = []
    @State private var stylesAtSearchStart: [String] = []
    @State private var dismissedAtSearchStart: Set<String> = []

    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]
    private let stylePool = ["Y2K", "Colorful", "Trendy", "Comfortable", "Monotone", "Vintage", "Minimal", "Streetwear"]

    private let demoStyles: [String: Set<String>] = [
        "demo_post_1": ["Y2K", "Comfortable"],
        "demo_post_2": ["Minimal", "Trendy"],
        "demo_post_3": ["Colorful", "Trendy"],
        "demo_post_4": ["Streetwear", "Y2K"],
        "demo_post_5": ["Vintage", "Colorful"],
        "demo_post_6": ["Comfortable", "Minimal"],
        "demo_post_7": ["Trendy", "Monotone"],
        "demo_post_8": ["Minimal", "Monotone"]
    ]

    init(service: any PostFunctions = DiscoveryPostSource.current, dismissRequest: Int = 0) {
        _model = StateObject(wrappedValue: DiscoveryFeedViewModel(service: service))
        self.dismissRequest = dismissRequest
    }

    var body: some View {
        VStack(spacing: 0) {
            SearchField(
                query: $query,
                focus: $isSearchFieldFocused,
                onSubmit: submitSearch,
                onClear: clearSearch
            )
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, selectedStyles.isEmpty ? 12 : 8)

            if !selectedStyles.isEmpty {
                selectedStyleChips
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
            }

            if isSearchActive {
                suggestionsView
            } else {
                feedContent
            }
        }
        .task { model.load() }
        .onDisappear { model.cancel() }
        .onChange(of: query) { _, newValue in
            if newValue.isEmpty && !isSearchActive { submittedQuery = "" }
        }
        .onChange(of: isSearchFieldFocused) { _, focused in
            if focused && !isSearchActive {
                stylesAtSearchStart = selectedStyles
                dismissedAtSearchStart = dismissedStyles
                isSearchActive = true
            }
        }
        .onChange(of: dismissRequest) { _, _ in
            if isSearchActive { cancelSearch() }
        }
    }

    private var suggestedStyles: [String] {
        stylePool.filter { !selectedStyles.contains($0) && !dismissedStyles.contains($0) }.prefix(3).map { $0 }
    }

    private var suggestionsView: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Suggested styles")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        ForEach(suggestedStyles, id: \.self) { style in
                            HStack(spacing: 0) {
                                Button(style) {
                                    selectedStyles.append(style)
                                    isSearchFieldFocused = true
                                }
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                                .padding(.leading, 16)
                                .foregroundStyle(.primary)
                                .buttonStyle(.plain)
                                .accessibilityIdentifier("discovery.style.select.\(style)")

                                Button {
                                    dismissedStyles.insert(style)
                                    isSearchFieldFocused = true
                                } label: {
                                    Image(systemName: "xmark")
                                        .foregroundStyle(.secondary)
                                        .frame(width: 48, height: 48)
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("Dismiss \(style)")
                                .accessibilityIdentifier("discovery.style.dismiss.\(style)")
                            }
                            .frame(height: 52)
                            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 20)
                }
                .frame(height: min(geometry.size.height, CGFloat(56 + suggestedStyles.count * 64)))

                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture(perform: cancelSearch)
                    .accessibilityLabel("Back to Discovery feed")
                    .accessibilityAddTraits(.isButton)
                    .accessibilityIdentifier("discovery.dismissSearchArea")
            }
        }
    }

    private var selectedStyleChips: some View {
        WrappingStyleLayout(spacing: 8) {
            ForEach(selectedStyles, id: \.self) { style in
                Button {
                    selectedStyles.removeAll { $0 == style }
                } label: {
                    HStack(spacing: 6) {
                        Text(style)
                            .lineLimit(1)
                            .truncationMode(.tail)
                        Image(systemName: "xmark")
                            .font(.caption2.weight(.bold))
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(.black, in: Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Remove \(style) style")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var feedContent: some View {
        switch model.state {
        case .idle, .loading:
            FeedStatusView(status: .loading)
        case .failed(let message):
            FeedStatusView(status: .error(message: message), onRetry: model.load)
        case .loaded(let posts) where posts.isEmpty:
            FeedStatusView(status: .empty)
        case .loaded(let posts):
            let visiblePosts = filtered(posts)
            if visiblePosts.isEmpty {
                ContentUnavailableView(
                    "No matching posts",
                    systemImage: "magnifyingglass",
                    description: Text("Try another search or style.")
                )
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(visiblePosts) { post in
                            NavigationLink {
                                DiscoveryPostDetailView(post: post)
                            } label: {
                                DiscoveryPostTile(post: post)
                            }
                            .buttonStyle(.plain)
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel("Post by \(post.authorId): \(post.caption)")
                            .accessibilityIdentifier("discovery.post.\(post.id)")
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
                }
                .accessibilityIdentifier("discovery.postGrid")
            }
        }
    }

    private func submitSearch() {
        submittedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        isSearchActive = false
        isSearchFieldFocused = false
    }

    private func cancelSearch() {
        isSearchFieldFocused = false
        isSearchActive = false
        selectedStyles = stylesAtSearchStart
        dismissedStyles = dismissedAtSearchStart
        query = submittedQuery
    }

    private func clearSearch() {
        query = ""
        if !isSearchActive { submittedQuery = "" }
        selectedStyles.removeAll()
    }

    private func filtered(_ posts: [Post]) -> [Post] {
        let term = submittedQuery
        return posts.filter { post in
            let textMatches = term.isEmpty ||
                post.authorId.localizedCaseInsensitiveContains(term) ||
                post.caption.localizedCaseInsensitiveContains(term) ||
                (post.outfitSnapshot.name?.localizedCaseInsensitiveContains(term) ?? false) ||
                post.outfitSnapshot.items.contains { $0.name.localizedCaseInsensitiveContains(term) }
            let styles = demoStyles[post.id] ?? []
            let styleMatches = selectedStyles.isEmpty || selectedStyles.contains { style in
                styles.contains(style) ||
                    post.caption.localizedCaseInsensitiveContains(style) ||
                    (post.outfitSnapshot.name?.localizedCaseInsensitiveContains(style) ?? false) ||
                    post.outfitSnapshot.items.contains { $0.name.localizedCaseInsensitiveContains(style) }
            }
            return textMatches && styleMatches
        }
    }
}

private struct WrappingStyleLayout: Layout {
    let spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 320
        let layout = arrange(subviews, within: width)
        return CGSize(width: width, height: layout.height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let layout = arrange(subviews, within: bounds.width)
        for index in subviews.indices {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + layout.origins[index].x, y: bounds.minY + layout.origins[index].y),
                anchor: .topLeading,
                proposal: ProposedViewSize(layout.sizes[index])
            )
        }
    }

    private func arrange(_ subviews: Subviews, within width: CGFloat) -> (
        origins: [CGPoint], sizes: [CGSize], height: CGFloat
    ) {
        let availableWidth = max(width, 1)
        var origins: [CGPoint] = []
        var sizes: [CGSize] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let idealWidth = subview.sizeThatFits(.unspecified).width
            let itemWidth = min(idealWidth, availableWidth)
            let measured = subview.sizeThatFits(ProposedViewSize(width: itemWidth, height: nil))
            let size = CGSize(width: itemWidth, height: measured.height)

            if x > 0 && x + size.width > availableWidth {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }

            origins.append(CGPoint(x: x, y: y))
            sizes.append(size)
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }

        return (origins, sizes, subviews.isEmpty ? 0 : y + rowHeight)
    }
}

private struct DiscoveryPostTile: View {
    let post: Post

    var body: some View {
        PostArtwork(post: post)
            .aspectRatio(1, contentMode: .fit)
            .overlay(alignment: .bottomLeading) {
                Text("@\(post.authorId)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.black.opacity(0.55), in: Capsule())
                    .padding(8)
            }
    }
}

/// Published media is not connected yet. Demo posts show garment artwork; live posts show a clear fallback.
struct PostArtwork: View {
    let post: Post
    var cornerRadius: CGFloat = 12

    var body: some View {
        ZStack {
            Color(.systemGray5)
            if post.id.hasPrefix("demo_post_") {
                HStack(spacing: 0) {
                    ForEach(Array(post.outfitSnapshot.items.prefix(2).enumerated()), id: \.offset) { _, item in
                        GarmentArtwork(category: item.category)
                            .padding(8)
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(12)
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "photo")
                        .font(.largeTitle)
                    Text("Post image unavailable")
                        .font(.caption)
                }
                .foregroundStyle(.secondary)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(post.id.hasPrefix("demo_post_") ? "Illustrated outfit" : "Post image unavailable")
    }
}

#Preview {
    NavigationStack {
        DiscoveryFeedView(service: DemoPostFunctions())
    }
}
