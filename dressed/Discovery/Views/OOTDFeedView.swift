import SwiftUI

/// Outfit posts stay in the feed; only their individual controls are interactive.
struct OOTDFeedView: View {
    @StateObject private var model: DiscoveryFeedViewModel
    @State private var liked: Set<String> = []
    @State private var comments: [String: [OOTDComment]] = [:]
    @State private var commentsPost: Post?
    @State private var itemsPost: Post?
    @State private var showingCreate = false
    @State private var previewPosts: [Post] = []
    private let demo: Bool

    init(service: any PostFunctions = DiscoveryPostSource.current) {
        _model = StateObject(wrappedValue: DiscoveryFeedViewModel(service: service))
        demo = service is DemoPostFunctions
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            switch model.state {
            case .idle, .loading: FeedStatusView(status: .loading)
            case .failed(let message): FeedStatusView(status: .error(message: message), onRetry: model.load)
            case .loaded(let posts) where posts.isEmpty && previewPosts.isEmpty: FeedStatusView(status: .empty)
            case .loaded(let posts):
                ScrollView {
                    LazyVStack(spacing: 24) {
                        ForEach(Array((previewPosts + posts).enumerated()), id: \.element.id) { index, post in
                            OOTDPostCard(post: post,
                                         likes: demoLikes(post) + (liked.contains(post.id) ? 1 : 0),
                                         isLiked: liked.contains(post.id),
                                         commentCount: postComments(post).count,
                                         onItems: { itemsPost = post },
                                         onComments: { commentsPost = post },
                                         onLike: {
                                             if !liked.insert(post.id).inserted { liked.remove(post.id) }
                                         })
                            if demo && index == 0 { OOTDOutfitGrid() }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 24)
                }
                .accessibilityIdentifier("ootd.postFeed")
            }
        }
        .task { model.load() }
        .onDisappear { model.cancel() }
        .sheet(item: $commentsPost) { post in
            OOTDCommentsSheet(comments: postComments(post)) { text in
                comments[post.id, default: demoComments(post)]
                    .append(OOTDComment(author: "@you", text: text, when: "now"))
            }
            .presentationDetents([.fraction(0.72)])
            .presentationDragIndicator(.visible)
        }
        .sheet(item: $itemsPost) { post in
            OOTDItemsSheet(post: post)
                .presentationDetents([.fraction(0.48), .large])
                .presentationDragIndicator(.visible)
        }
        .navigationDestination(isPresented: $showingCreate) {
            OOTDCreatePostView(canSharePreview: demo) { caption in
                previewPosts.insert(Post(id: "demo_post_\(UUID().uuidString)", schemaVersion: 1,
                                         authorId: "you", caption: caption.isEmpty ? "caption (optional)" : caption,
                                         outfitSnapshot: PublishedOutfitSnapshot(name: nil, items: []),
                                         mediaPath: "", createdAt: .now), at: 0)
                showingCreate = false
            }
        }
    }

    private var header: some View {
        HStack(spacing: 0) {
            Button { showingCreate = true } label: {
                Image("TablerPlus")
                    .renderingMode(.template)
                    .resizable()
                    .frame(width: 28, height: 28)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Create Post")
            .accessibilityIdentifier("ootd.createPost")
            Spacer()
            Text("Fit check")
                .font(.system(size: 17, weight: .semibold))
                .padding(.horizontal, 14)
                .frame(height: 34)
                .background(Color.black.opacity(0.08), in: Capsule())
            Spacer()
            Color.clear.frame(width: 44, height: 44)
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 16)
    }

    private func demoLikes(_ post: Post) -> Int {
        guard demo else { return 0 }
        return post.id == "demo_post_1" ? 24 : (post.id == "demo_post_2" ? 18 : 0)
    }

    private func demoComments(_ post: Post) -> [OOTDComment] {
        guard demo else { return [] }
        switch post.id {
        case "demo_post_1":
            return [.init(author: "@mina.fits", text: "Those trousers are everything", when: "2h"),
                    .init(author: "@jun", text: "where are the loafers from?", when: "1h")]
        case "demo_post_2":
            return [.init(author: "@sofia", text: "The belt ties it all together", when: "5h")]
        default: return []
        }
    }

    private func postComments(_ post: Post) -> [OOTDComment] { comments[post.id] ?? demoComments(post) }
}

private struct OOTDPostCard: View {
    let post: Post
    let likes: Int
    let isLiked: Bool
    let commentCount: Int
    let onItems: () -> Void
    let onComments: () -> Void
    let onLike: () -> Void
    @State private var activePin: Int?

    private var dateLabel: String {
        let date = Calendar.current.dateComponents([.month, .day, .year], from: post.createdAt)
        return "\(date.month ?? 0).\(date.day ?? 0).\(String(format: "%02d", (date.year ?? 0) % 100))"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("@\(post.authorId)")
                .font(.system(size: 14, weight: .bold))
                .tracking(-0.2)
                .padding(.bottom, 8)
            PostArtwork(post: post)
                .aspectRatio(4 / 5, contentMode: .fit)
                .overlay(alignment: .topLeading) {
                    Text(dateLabel)
                        .font(.system(size: 13, weight: .bold))
                        .padding(.top, 12)
                        .padding(.leading, 14)
                }
                .overlay {
                    GeometryReader { geometry in
                        ForEach(Array(post.outfitSnapshot.items.prefix(4).enumerated()), id: \.offset) { index, item in
                            Button { activePin = activePin == index ? nil : index } label: {
                                ZStack {
                                    Circle().fill(.white)
                                        .frame(width: activePin == index ? 15 : 11,
                                               height: activePin == index ? 15 : 11)
                                        .shadow(color: .black.opacity(0.35), radius: 2)
                                    if activePin == index {
                                        Text(item.name)
                                            .font(.system(size: 11, weight: .semibold))
                                            .foregroundStyle(.white)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(.black, in: RoundedRectangle(cornerRadius: 6))
                                            .fixedSize()
                                            .offset(y: -24)
                                    }
                                }
                                .frame(width: 44, height: 44)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(item.name)
                            .accessibilityValue(activePin == index ? "Selected" : "Unselected")
                            .accessibilityIdentifier("ootd.pin.\(post.id).\(index)")
                            .position(x: geometry.size.width * [0.48, 0.54, 0.50, 0.44][index],
                                      y: geometry.size.height * [0.38, 0.54, 0.47, 0.68][index])
                        }
                    }
                }
                .overlay(alignment: .bottomTrailing) {
                    Button(action: onItems) {
                        Image("TablerBuildingStore")
                            .renderingMode(.template)
                            .resizable()
                            .frame(width: 24, height: 24)
                            .frame(width: 50, height: 50)
                            .background(.white.opacity(0.85), in: Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Find items in this outfit")
                    .accessibilityIdentifier("ootd.findItems.\(post.id)")
                    .padding(12)
                }

            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(post.caption).font(.system(size: 13.5))
                    Text("song....").font(.system(size: 11.5)).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                HStack(spacing: 6) {
                    action(icon: "TablerMessageFilled", count: commentCount, action: onComments)
                        .foregroundStyle(Color(red: 0.47, green: 0.47, blue: 0.47))
                        .accessibilityLabel("Comments, \(commentCount)")
                        .accessibilityIdentifier("ootd.comments.\(post.id)")
                    action(icon: isLiked ? "TablerHeartFilled" : "TablerHeart", count: likes, action: onLike)
                        .accessibilityLabel("\(isLiked ? "Unlike" : "Like"), \(likes) likes")
                        .accessibilityIdentifier("ootd.like.\(post.id)")
                }
            }
            .padding(.top, 10)
        }
    }

    private func action(icon: String, count: Int, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(icon)
                    .renderingMode(.template)
                    .resizable()
                    .frame(width: 24, height: 24)
                Text("\(count)")
                    .font(.system(size: 14, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            .frame(minHeight: 44)
            .padding(.horizontal, 6)
        }
        .buttonStyle(.plain)
    }
}

private struct OOTDOutfitGrid: View {
    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
            ForEach(0..<4) { _ in
                RoundedRectangle(cornerRadius: 10).fill(.white)
                    .aspectRatio(1, contentMode: .fit)
                    .shadow(color: .black.opacity(0.06), radius: 2, y: 1)
            }
        }
        .padding(14)
        .background(Color(.systemGray5), in: RoundedRectangle(cornerRadius: 12))
        .accessibilityLabel("Outfit breakdown")
    }
}

private struct OOTDComment: Identifiable {
    let id = UUID()
    let author: String
    let text: String
    let when: String
}

private struct OOTDCommentsSheet: View {
    let comments: [OOTDComment]
    let onSend: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var draft = ""

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                Text("Comments").font(.system(size: 17, weight: .semibold))
                HStack {
                    Spacer()
                    Button { dismiss() } label: {
                        Image("TablerX")
                            .renderingMode(.template)
                            .resizable()
                            .frame(width: 22, height: 22)
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Close comments")
                }
            }
            .frame(height: 56)
            ScrollView {
                if comments.isEmpty {
                    Text("No comments yet. Be the first.")
                        .font(.system(size: 15)).foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, minHeight: 200)
                } else {
                    LazyVStack(alignment: .leading, spacing: 16) {
                        ForEach(comments) { comment in
                            HStack(alignment: .top, spacing: 12) {
                                Image("TablerUserFilled")
                                    .renderingMode(.template)
                                    .resizable()
                                    .frame(width: 20, height: 20)
                                    .foregroundStyle(.secondary)
                                    .frame(width: 36, height: 36)
                                    .background(Color(.systemGray5), in: Circle())
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack(spacing: 8) {
                                        Text(comment.author).fontWeight(.semibold)
                                        Text(comment.when).foregroundStyle(.secondary)
                                    }
                                    .font(.system(size: 13))
                                    Text(comment.text).font(.system(size: 15))
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 4)
                }
            }
            HStack(spacing: 8) {
                TextField("Add a comment…", text: $draft)
                    .font(.system(size: 17))
                    .padding(.horizontal, 16)
                    .frame(height: 44)
                    .background(Color.black.opacity(0.08), in: Capsule())
                    .accessibilityIdentifier("ootd.commentInput")
                Button {
                    onSend(draft.trimmingCharacters(in: .whitespacesAndNewlines))
                    draft = ""
                } label: {
                    Image("TablerArrowUp")
                        .renderingMode(.template)
                        .resizable()
                        .frame(width: 22, height: 22)
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(.black, in: Circle())
                }
                .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .opacity(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.25 : 1)
                .accessibilityLabel("Post comment")
                .accessibilityIdentifier("ootd.sendComment")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }
}

private struct OOTDItemsSheet: View {
    let post: Post
    @State private var category: String?
    @State private var sort: OOTDItemSort = .bestMatch
    @State private var savedItemIDs: Set<String> = []

    private var items: [OOTDShopItem] {
        if post.id == "demo_post_1" { return OOTDShopItem.prototypeItems }
        return post.outfitSnapshot.items.map { item in
            OOTDShopItem(id: item.sourceItemId, name: item.name, category: item.category,
                         brand: nil, price: nil, rating: nil, reviews: nil, sales: nil,
                         verified: false, productURL: item.productURL)
        }
    }

    private var categories: [String] {
        var result: [String] = []
        for item in items where !result.contains(item.categoryLabel) {
            result.append(item.categoryLabel)
        }
        return result
    }

    private var visible: [OOTDShopItem] {
        let filtered = items.filter { category == nil || $0.categoryLabel == category }
        switch sort {
        case .bestMatch: return filtered
        case .priceLow: return filtered.sorted { ($0.price ?? .greatestFiniteMagnitude) < ($1.price ?? .greatestFiniteMagnitude) }
        case .priceHigh: return filtered.sorted { ($0.price ?? 0) > ($1.price ?? 0) }
        case .bestSellers: return filtered.sorted { ($0.sales ?? 0) > ($1.sales ?? 0) }
        case .customerReview: return filtered.sorted { ($0.rating ?? 0) > ($1.rating ?? 0) }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Menu {
                    ForEach(post.id == "demo_post_1" ? OOTDItemSort.allCases : [.bestMatch]) { option in
                        Button(option.title) { sort = option }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text("Sort by: \(sort.title)")
                        Image(systemName: "chevron.down")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 16, height: 16)
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .padding(.horizontal, 12)
                    .frame(height: 36)
                    .background(Color.black.opacity(0.07), in: Capsule())
                    .frame(height: 44)
                }
                .tint(.primary)
                .accessibilityIdentifier("ootd.itemsSort")
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        chip("All", value: nil)
                        ForEach(categories, id: \.self) { value in
                            chip(value, value: value)
                        }
                    }
                    .padding(.trailing, 20)
                }
            }
            .padding(.leading, 20)
            .padding(.top, 24)
            .padding(.bottom, 4)

            ScrollView {
                if visible.isEmpty {
                    ContentUnavailableView("No pieces in this post", systemImage: "hanger",
                                           description: Text("The author did not include a clothing breakdown."))
                } else {
                    LazyVStack(spacing: 10) {
                        ForEach(visible) { item in
                            itemRow(item)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 4)
                    .padding(.bottom, 46)
                }
            }
        }
        .background(.white)
        .preferredColorScheme(.light)
    }

    private func chip(_ title: String, value: String?) -> some View {
        Button { category = value } label: {
            Text(title).font(.system(size: 13, weight: .semibold))
                .foregroundStyle(category == value ? .white : .black)
                .padding(.horizontal, 14)
                .frame(height: 36)
                .background(category == value ? .black : Color.black.opacity(0.07), in: Capsule())
                .frame(height: 44)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("ootd.category.\(title)")
    }

    private func itemRow(_ item: OOTDShopItem) -> some View {
        HStack(alignment: .top, spacing: 12) {
            // TODO: Replace vector artwork with the item's approved public product image.
            GarmentArtwork(category: item.category)
                .padding(10)
                .frame(width: 96, height: 96)
                .background(.white, in: RoundedRectangle(cornerRadius: 8))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 0) {
                if let brand = item.brand {
                    Text(brand)
                        .font(.system(size: 13))
                        .foregroundStyle(.black.opacity(0.55))
                }
                itemName(item)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.black)
                    .lineLimit(2)
                    .padding(.top, item.brand == nil ? 0 : 2)
                if let rating = item.rating, let reviews = item.reviews {
                    HStack(spacing: 4) {
                        Image(systemName: "star")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 13, height: 13)
                        Text(rating.formatted(.number.precision(.fractionLength(1))))
                        Text("(\(reviews))").foregroundStyle(.black.opacity(0.55))
                    }
                    .font(.system(size: 13))
                    .padding(.top, 2)
                }
                Spacer(minLength: 0)
                if let price = item.price {
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Text(price.formatted(.currency(code: "USD").precision(.fractionLength(0))))
                            .font(.system(size: 17, weight: .semibold))
                        if item.verified {
                            Label("Verified by creator", systemImage: "checkmark.seal")
                                .font(.system(size: 13))
                                .foregroundStyle(.black.opacity(0.55))
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                    }
                    .padding(.top, 6)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 96, alignment: .topLeading)
            .padding(.trailing, 36)
        }
        .padding(12)
        .background(Color.black.opacity(0.07), in: RoundedRectangle(cornerRadius: 12))
        .overlay(alignment: .topTrailing) {
            Button {
                if !savedItemIDs.insert(item.id).inserted { savedItemIDs.remove(item.id) }
            } label: {
                Image(systemName: savedItemIDs.contains(item.id) ? "bookmark.fill" : "bookmark")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 22, height: 22)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(savedItemIDs.contains(item.id) ? "Saved" : "Save") \(item.name)")
            .accessibilityIdentifier("ootd.saveItem.\(item.id)")
            .padding(2)
        }
    }

    @ViewBuilder private func itemName(_ item: OOTDShopItem) -> some View {
        if let url = item.productURL, url.scheme == "https", url.host != nil,
           url.host?.hasSuffix(".example") != true {
            Link(item.name, destination: url)
        } else {
            Text(item.name)
        }
    }
}

private enum OOTDItemSort: String, CaseIterable, Identifiable {
    case bestMatch, priceLow, priceHigh, bestSellers, customerReview

    var id: Self { self }
    var title: String {
        switch self {
        case .bestMatch: "Best match"
        case .priceLow: "Price: Low to high"
        case .priceHigh: "Price: High to low"
        case .bestSellers: "Best sellers"
        case .customerReview: "Avg customer review"
        }
    }
}

private struct OOTDShopItem: Identifiable {
    let id: String
    let name: String
    let category: ClothingCategory
    let brand: String?
    let price: Double?
    let rating: Double?
    let reviews: Int?
    let sales: Int?
    let verified: Bool
    let productURL: URL?

    var categoryLabel: String {
        if id.hasPrefix("jacket-") { return "Jacket" }
        return switch category {
        case .outerwear:
            name.localizedCaseInsensitiveContains("jacket") || name.localizedCaseInsensitiveContains("blazer")
                ? "Jacket" : "Outerwear"
        case .pants: "Pants"
        case .accessories: name.localizedCaseInsensitiveContains("belt") ? "Belt" : "Accessories"
        case .shoes: "Shoes"
        default: category.rawValue.capitalized
        }
    }

    private static func sample(_ id: String, _ name: String, _ category: ClothingCategory,
                               _ brand: String, _ price: Double, _ rating: Double,
                               _ reviews: Int, _ sales: Int, verified: Bool = false) -> Self {
        .init(id: id, name: name, category: category, brand: brand, price: price,
              rating: rating, reviews: reviews, sales: sales, verified: verified, productURL: nil)
    }

    // Fixture values mirror the prototype sheet. They are not fetched offers or publishable post data.
    static let prototypeItems: [Self] = [
        sample("jacket-1", "Vintage leather jacket", .outerwear, "Arlo & Finch", 189, 4.6, 212, 540, verified: true),
        sample("jacket-2", "Oversized moto jacket", .outerwear, "Northline", 245, 4.3, 98, 310),
        sample("jacket-3", "Washed suede bomber", .outerwear, "Hale", 168, 4.7, 340, 720),
        sample("pants-1", "Pleated wool trousers", .pants, "Maison Verde", 98, 4.5, 164, 480, verified: true),
        sample("pants-2", "Wide-leg tailored pants", .pants, "Hale", 84, 4.2, 120, 390),
        sample("pants-3", "Relaxed pleat trouser", .pants, "Arlo & Finch", 112, 4.7, 271, 610),
        sample("belt-1", "Leather belt", .accessories, "Hale", 48, 4.6, 305, 910, verified: true),
        sample("belt-2", "Woven leather belt", .accessories, "Studio Kiln", 56, 4.4, 142, 430),
        sample("belt-3", "Classic dress belt", .accessories, "Maison Verde", 64, 4.8, 410, 780),
        sample("shoes-1", "Chunky loafers", .shoes, "Arlo & Finch", 156, 4.5, 233, 520, verified: true),
        sample("shoes-2", "Penny loafer", .shoes, "Hale", 128, 4.3, 176, 350),
        sample("shoes-3", "Derby shoe", .shoes, "Maison Verde", 174, 4.7, 289, 640)
    ]
}

private struct OOTDCreatePostView: View {
    let canSharePreview: Bool
    let onShare: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var caption = ""
    @State private var songIndex = 0
    @State private var detailsOpen = false
    private let songs = ["song here", "autumn breeze", "midnight walk", "street symphony"]

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                Button { dismiss() } label: {
                    Image("TablerChevronLeft")
                        .renderingMode(.template)
                        .resizable()
                        .frame(width: 24, height: 24)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Back")
                Text("New post").font(.system(size: 17, weight: .semibold))
                Spacer()
            }
            .padding(.top, 12)
            .padding(.bottom, 6)

            // TODO: Replace the prototype outfit artwork with a selected, publishable outfit snapshot.
            Image("OutfitPostPlaceholder")
                .resizable()
                .scaledToFit()
                .padding(.all, 28)
                .frame(maxWidth: .infinity)
                .aspectRatio(5 / 4, contentMode: .fit)
                .background(Color(red: 222 / 255, green: 222 / 255, blue: 222 / 255),
                            in: RoundedRectangle(cornerRadius: 16))
                .shadow(color: .black.opacity(0.05), radius: 4, y: 1)
                .accessibilityLabel("Outfit preview image")

            TextField("Write a caption…", text: $caption, axis: .vertical)
                .lineLimit(2...4)
                .font(.body)
                .frame(minHeight: 48, alignment: .topLeading)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color.black.opacity(0.07), in: RoundedRectangle(cornerRadius: 12))
                .padding(.top, 16)
                .accessibilityIdentifier("ootd.newPostCaption")

            row("Audio", icon: "music.note", value: songs[songIndex]) {
                songIndex = (songIndex + 1) % songs.count
            }
            .padding(.top, 8)
            row("Outfit details", icon: "hanger", value: detailsOpen ? "3 items tagged" : "Tag items") {
                detailsOpen.toggle()
            }
            .padding(.top, 8)
            Spacer()
            Button("Share") { onShare(caption.trimmingCharacters(in: .whitespacesAndNewlines)) }
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(.black, in: RoundedRectangle(cornerRadius: 12))
                .disabled(!canSharePreview)
                .accessibilityIdentifier("ootd.sharePreview")
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 16)
        .background(.white)
        .toolbar(.hidden, for: .navigationBar)
    }

    private func row(_ title: String, icon: String, value: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                HStack(spacing: 10) {
                    Image(systemName: icon)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 22, height: 22)
                    Text(title)
                }
                Spacer()
                Text(value)
                    .foregroundStyle(.black.opacity(0.55))
                    .lineLimit(1)
                Image(systemName: "chevron.right")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 16, height: 16)
                    .frame(width: 20, height: 20)
                    .foregroundStyle(.black.opacity(0.55))
            }
            .font(.body)
            .padding(.leading, 16)
            .padding(.trailing, 12)
            .frame(height: 52)
            .background(Color.black.opacity(0.07), in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("ootd.newPost.\(title)")
    }
}

/// Published media is not connected yet. Demo posts show garment artwork; live posts show a clear fallback.
struct PostArtwork: View {
    let post: Post
    var cornerRadius: CGFloat = 12

    var body: some View {
        ZStack {
            Color(red: 0.85, green: 0.85, blue: 0.85)
            if !post.id.hasPrefix("demo_post_") {
                VStack(spacing: 8) {
                    Image("TablerPhoto")
                        .renderingMode(.template)
                        .resizable()
                        .frame(width: 32, height: 32)
                    Text("Post image unavailable").font(.caption)
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
    NavigationStack { OOTDFeedView(service: DemoPostFunctions()) }
}

#Preview("New post") {
    NavigationStack { OOTDCreatePostView(canSharePreview: true) { _ in } }
}
