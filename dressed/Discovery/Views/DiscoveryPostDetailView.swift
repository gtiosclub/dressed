import SwiftUI

/// The post-detail screen. It receives or loads one post and decides what taps do;
/// the layout itself lives in `PostDetailView`.
struct DiscoveryPostDetailView: View {
    @StateObject private var model: PostDetailViewModel
    @Environment(\.openURL) private var openURL

    /// Opened from the feed, which already has the post.
    init(post: Post) {
        _model = StateObject(wrappedValue: PostDetailViewModel(post: post))
    }

    /// Opened by ID; reads `posts/{postId}`.
    init(postId: String, service: any PostFunctions = DiscoveryPostSource.current) {
        _model = StateObject(wrappedValue: PostDetailViewModel(postId: postId, service: service))
    }

    var body: some View {
        content
            .task { model.loadIfNeeded() }
            .onDisappear { model.cancel() }
            .navigationTitle("Post")
            .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private var content: some View {
        switch model.state {
        case .loading:
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .loaded(let content):
            PostDetailView(
                content: content,
                // TODO(#49): open the author's profile once public author data exists.
                onAuthorTap: { _ in },
                // TODO(#59): leads decide what tapping a published piece opens.
                onPieceTap: { _, _ in },
                onProductLinkTap: { openURL($0) }
            )
        case .removed:
            ContentUnavailableView(
                "Post unavailable",
                systemImage: "eye.slash",
                description: Text("This post is no longer available.")
            )
        case .failed(let message):
            ContentUnavailableView {
                Label("Couldn't load this post", systemImage: "exclamationmark.triangle")
            } description: {
                Text(message)
            } actions: {
                Button("Try again", action: model.load)
            }
        }
    }
}

/// Option A layout: author, post image with a pieces button, caption, and a sortable
/// pieces sheet. It shows only what it is handed and reports every tap to its parent.
struct PostDetailView: View {
    let content: PostDetailContent
    let onAuthorTap: (_ authorId: String) -> Void
    let onPieceTap: (_ postId: String, _ pieceIndex: Int) -> Void
    let onProductLinkTap: (URL) -> Void

    @State private var showingPieces = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                authorRow
                    .padding(.horizontal, 16)

                PublishedPostImageView(image: content.postImage)
                    .overlay(alignment: .bottomTrailing) { piecesButton }
                    .padding(.horizontal, 16)

                VStack(alignment: .leading, spacing: 8) {
                    if !content.caption.isEmpty {
                        ExpandableCaption(text: content.caption)
                    }
                    if let name = content.outfitName, !name.isEmpty {
                        Text(name)
                            .font(.title3.weight(.semibold))
                    }
                }
                .padding(.horizontal, 16)
            }
            .padding(.vertical, 16)
        }
        .sheet(isPresented: $showingPieces) {
            PostPiecesSheet(
                pieces: content.pieces,
                onPieceTap: { index in onPieceTap(content.postId, index) },
                onProductLinkTap: onProductLinkTap
            )
            .presentationDetents([.height(360), .large])
            .presentationDragIndicator(.visible)
            .presentationBackground(Color(.systemGray6))
        }
    }

    private var authorRow: some View {
        Button {
            onAuthorTap(content.authorId)
        } label: {
            HStack(spacing: 10) {
                avatar
                VStack(alignment: .leading, spacing: 2) {
                    Text(content.authorDisplayName)
                        .font(.headline)
                    Text(content.createdAt, format: .dateTime.month(.abbreviated).day())
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityHint("Shows the author")
        .accessibilityIdentifier("discovery.postAuthor")
    }

    @ViewBuilder
    private var avatar: some View {
        if let image = content.authorAvatar {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 36, height: 36)
                .clipShape(Circle())
                .accessibilityHidden(true)
        } else {
            Image(systemName: "person.crop.circle.fill")
                .font(.system(size: 36))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
        }
    }

    private var piecesButton: some View {
        Button {
            showingPieces = true
        } label: {
            Image(systemName: "tag.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(.black.opacity(0.7), in: Circle())
        }
        .buttonStyle(.plain)
        .padding(12)
        .accessibilityLabel("Show \(content.pieces.count) pieces in this post")
        .accessibilityIdentifier("discovery.showPostPieces")
    }
}

/// Shows the first three lines with a "more" toggle for long captions.
private struct ExpandableCaption: View {
    let text: String
    @State private var isExpanded = false

    private let collapsedLineLimit = 3
    private var isLong: Bool {
        text.count > 120 || text.filter { $0 == "\n" }.count >= collapsedLineLimit
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(text)
                .font(.body)
                .lineLimit(isExpanded ? nil : collapsedLineLimit)
            if isLong {
                Button(isExpanded ? "less" : "more") {
                    isExpanded.toggle()
                }
                .font(.subheadline.weight(.semibold))
                .accessibilityLabel(isExpanded ? "Show less of the caption" : "Show the full caption")
            }
        }
    }
}

private struct PostPiecesSheet: View {
    let pieces: [PostDetailPiece]
    let onPieceTap: (_ pieceIndex: Int) -> Void
    let onProductLinkTap: (URL) -> Void

    @State private var sortOrder: PieceSortOrder = .postOrder

    private var orderedPieces: [PostDetailPiece] {
        pieces.sorted { left, right in
            let comparison: ComparisonResult
            switch sortOrder {
            case .postOrder:
                return left.index < right.index
            case .nameAscending, .nameDescending:
                comparison = left.name.localizedStandardCompare(right.name)
                if comparison == .orderedSame { return left.index < right.index }
                return sortOrder == .nameAscending
                    ? comparison == .orderedAscending
                    : comparison == .orderedDescending
            case .category:
                comparison = left.category.rawValue.localizedStandardCompare(right.category.rawValue)
                if comparison == .orderedSame { return left.index < right.index }
                return comparison == .orderedAscending
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Menu {
                Picker("Sort pieces", selection: $sortOrder) {
                    ForEach(PieceSortOrder.allCases) { option in
                        Text(option.title).tag(option)
                    }
                }
            } label: {
                HStack(spacing: 8) {
                    Text("Sort by: \(sortOrder.title)")
                    Image(systemName: "chevron.down")
                }
                .font(.subheadline)
                .foregroundStyle(.primary)
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(.white, in: Capsule())
            }
            .tint(.black)
            .accessibilityIdentifier("discovery.piecesSort")
            .padding(.horizontal, 16)
            .padding(.top, 28)
            .padding(.bottom, 12)

            ScrollView {
                if pieces.isEmpty {
                    ContentUnavailableView(
                        "No pieces in this post",
                        systemImage: "hanger",
                        description: Text("The author did not include a clothing breakdown.")
                    )
                } else {
                    LazyVStack(spacing: 16) {
                        ForEach(orderedPieces) { piece in
                            PublishedPieceRow(
                                piece: piece,
                                onTap: { onPieceTap(piece.index) },
                                onProductLinkTap: onProductLinkTap
                            )
                            .accessibilityIdentifier("discovery.postPiece.\(piece.index)")
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 20)
        }
    }
}

private enum PieceSortOrder: String, CaseIterable, Identifiable {
    case postOrder
    case nameAscending
    case nameDescending
    case category

    var id: Self { self }

    var title: String {
        switch self {
        case .postOrder: "Post order"
        case .nameAscending: "Name: A to Z"
        case .nameDescending: "Name: Z to A"
        case .category: "Category"
        }
    }
}

private struct PublishedPieceRow: View {
    let piece: PostDetailPiece
    let onTap: () -> Void
    let onProductLinkTap: (URL) -> Void

    var body: some View {
        VStack(alignment: .trailing, spacing: 6) {
            Button(action: onTap) {
                CatalogProductRowLayout(backgroundColor: Color(.systemGray4)) {
                    PieceThumbnail(image: piece.image)
                } details: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(piece.name)
                            .font(.headline)
                            .foregroundStyle(.primary)
                        Text(piece.category.rawValue.capitalized)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        if piece.image == nil {
                            Text("Image unavailable")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .buttonStyle(.plain)

            if let url = piece.productURL {
                Button {
                    onProductLinkTap(url)
                } label: {
                    Label("View product", systemImage: "arrow.up.right")
                        .font(.caption)
                }
                .frame(minHeight: 44)
            }
        }
    }
}

/// A piece's published image, or a placeholder. Never a closet photo.
private struct PieceThumbnail: View {
    let image: UIImage?

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(.systemGray5))
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .padding(6)
            } else {
                Image(systemName: "photo")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityHidden(true)
    }
}

// MARK: - Dummy data for previews (no Firebase, no private paths)

#if DEBUG
private extension UIImage {
    /// A grey stand-in for a published photo.
    static func fixture(width: CGFloat, height: CGFloat) -> UIImage {
        let size = CGSize(width: width, height: height)
        return UIGraphicsImageRenderer(size: size).image { context in
            UIColor(white: 0.45, alpha: 1).setFill()
            context.fill(CGRect(origin: .zero, size: size))
            let diameter = min(width, height) * 0.5
            UIColor.white.setFill()
            context.cgContext.fillEllipse(in: CGRect(
                x: (width - diameter) / 2,
                y: (height - diameter) / 2,
                width: diameter,
                height: diameter
            ))
        }
    }
}

private extension PostDetailContent {
    /// Two pieces, a long caption, and one missing piece image. The blue shirt's
    /// original closet item was deleted; the published post still shows it normally.
    static let sample = PostDetailContent(
        postId: "post_001",
        authorId: "user_a",
        authorDisplayName: "Example",
        authorAvatar: nil,
        createdAt: Date(timeIntervalSince1970: 1_790_000_000),
        caption: "Monday outfit for a cold morning. Layered the blue shirt over a tee, "
            + "kept the black jeans simple, and added nothing else so the colors stay calm. "
            + "Would wear this again for a long day on campus.",
        outfitName: "Monday",
        postImage: .fixture(width: 400, height: 500),
        pieces: [
            PostDetailPiece(index: 0, name: "Blue shirt", category: .tops,
                            image: .fixture(width: 200, height: 200), productURL: nil),
            PostDetailPiece(index: 1, name: "Black jeans", category: .pants,
                            image: nil, productURL: nil)
        ]
    )

    static let noMedia: PostDetailContent = {
        var content = sample
        content.postImage = nil
        content.caption = "Short caption"
        content.pieces = content.pieces.map { piece in
            var piece = piece
            piece.image = nil
            return piece
        }
        return content
    }()
}

#Preview("Two pieces, long caption") {
    NavigationStack {
        PostDetailView(
            content: .sample,
            onAuthorTap: { print("author tapped:", $0) },
            onPieceTap: { print("piece tapped:", $0, $1) },
            onProductLinkTap: { print("link tapped:", $0) }
        )
        .navigationTitle("Post")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview("No media available") {
    NavigationStack {
        PostDetailView(
            content: .noMedia,
            onAuthorTap: { _ in },
            onPieceTap: { _, _ in },
            onProductLinkTap: { _ in }
        )
    }
}

#Preview("Removed post") {
    NavigationStack {
        DiscoveryPostDetailView(postId: "post_that_was_deleted", service: DemoPostFunctions())
    }
}
#endif
