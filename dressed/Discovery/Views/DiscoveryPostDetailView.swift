import SwiftUI

struct DiscoveryPostDetailView: View {
    let post: Post
    @State private var showingPieces = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 10) {
                    Image(systemName: "person.crop.circle.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("@\(post.authorId)")
                            .font(.headline)
                        Text(post.createdAt, format: .dateTime.month(.abbreviated).day())
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 16)

                ZStack(alignment: .bottomTrailing) {
                    PostArtwork(post: post, cornerRadius: 0)
                        .aspectRatio(1, contentMode: .fit)

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
                    .padding(16)
                    .accessibilityLabel("Show \(post.outfitSnapshot.items.count) pieces in this post")
                    .accessibilityIdentifier("discovery.showPostPieces")
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text(post.caption)
                        .font(.body)

                    if let name = post.outfitSnapshot.name, !name.isEmpty {
                        Text(name)
                            .font(.title3.weight(.semibold))
                    }
                }
                .padding(.horizontal, 16)
            }
            .padding(.top, 16)
            .padding(.bottom, 16)
        }
        .sheet(isPresented: $showingPieces) {
            PostPiecesSheet(items: post.outfitSnapshot.items)
                .presentationDetents([.height(360), .large])
                .presentationDragIndicator(.visible)
                .presentationBackground(Color(.systemGray6))
        }
        .navigationTitle("Post")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct PostPiecesSheet: View {
    let items: [PublishedClothingSnapshot]
    @State private var sortOrder: PieceSortOrder = .postOrder

    private var orderedIndices: [Int] {
        items.indices.sorted { left, right in
            let comparison: ComparisonResult
            switch sortOrder {
            case .postOrder:
                return left < right
            case .nameAscending, .nameDescending:
                comparison = items[left].name.localizedStandardCompare(items[right].name)
                if comparison == .orderedSame { return left < right }
                return sortOrder == .nameAscending
                    ? comparison == .orderedAscending
                    : comparison == .orderedDescending
            case .category:
                comparison = items[left].category.rawValue.localizedStandardCompare(items[right].category.rawValue)
                if comparison == .orderedSame { return left < right }
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
                if items.isEmpty {
                    ContentUnavailableView(
                        "No pieces in this post",
                        systemImage: "hanger",
                        description: Text("The author did not include a clothing breakdown.")
                    )
                } else {
                    LazyVStack(spacing: 16) {
                        ForEach(orderedIndices, id: \.self) { index in
                            PublishedPieceRow(item: items[index])
                                .accessibilityIdentifier("discovery.postPiece.\(index)")
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
    let item: PublishedClothingSnapshot

    private var publicProductURL: URL? {
        guard let url = item.productURL,
              url.scheme == "https",
              url.host != nil,
              url.host?.hasSuffix(".example") != true else { return nil }
        return url
    }

    var body: some View {
        CatalogProductRowLayout(backgroundColor: Color(.systemGray4)) {
            GarmentArtwork(category: item.category)
                .padding(10)
                .background(Color(.systemGray5), in: RoundedRectangle(cornerRadius: 10))
                .accessibilityHidden(true)
        } details: {
            VStack(alignment: .leading, spacing: 4) {
                Text(item.name)
                    .font(.headline)
                Text(item.category.rawValue.capitalized)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if let publicProductURL {
                    Link("View product", destination: publicProductURL)
                        .font(.caption)
                }
            }
        }
    }
}
