import SwiftUI

/// Avatar tab (provided mockups, no Figma frame yet): the generated try-on look, centered below the
/// status bar, with settings and outfit buttons at the top right. The outfit button opens a bottom
/// picker; closing it generates the look for the new pieces. The 3D mannequin stands in until then.
struct AvatarTabView: View {
    @ObservedObject var model: AvatarTryOnModel
    @ObservedObject var studio: OutfitStudioModel
    @ObservedObject var closet: PrototypeClosetStore
    @ObservedObject var outfits: PrototypeOutfitStore
    @ObservedObject var catalog: AvatarCatalogStore
    let ownerId: String
    let onSignOut: () -> Void
    let image: (ClothingItem) -> Image
    let closetImage: (ClothingItem) -> UIImage?

    /// Closet photos, then downloaded catalog photos for Shop pieces.
    private var uiImage: (ClothingItem) -> UIImage? {
        { [closetImage, catalog] item in closetImage(item) ?? catalog.image(for: item.id) }
    }

    @State private var showsSettings = false
    @State private var showsPicker = false

    var body: some View {
        ZStack(alignment: .topTrailing) {
            stage
                .padding(.horizontal, DSSpacing.lg)
                .padding(.top, DSSpacing.sm)
                .padding(.bottom, 76)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            VStack(spacing: DSSpacing.sm) {
                Button { showsSettings = true } label: {
                    DSIcon("TablerSettings", size: 24).foregroundStyle(DSColor.iconMuted)
                }
                .buttonStyle(.ds(.tile))
                .accessibilityLabel("Avatar settings")
                .accessibilityIdentifier("avatar.settings")

                Button { setPicker(!showsPicker) } label: {
                    DSIcon("TablerShirt", size: 24).foregroundStyle(DSColor.iconMuted)
                }
                .buttonStyle(.ds(.tile))
                .accessibilityLabel("Choose pieces")
                .accessibilityIdentifier("avatar.outfit")
            }
            .padding(.trailing, DSSpacing.lg)
            .padding(.top, DSSpacing.sm)
        }
        .overlay(alignment: .bottom) {
            bottomBar
                .padding(.horizontal, DSSpacing.lg)
                .padding(.bottom, DSSpacing.lg)
        }
        .overlay {
            if showsPicker {
                DSColor.scrim
                    .ignoresSafeArea()
                    .onTapGesture { setPicker(false) }
                    .transition(.opacity)
                    .accessibilityHidden(true)
            }
        }
        .overlay(alignment: .bottom) {
            if showsPicker {
                AvatarPiecePicker(studio: studio, closet: closet, outfits: outfits, catalog: catalog, uiImage: uiImage)
                    .transition(.move(edge: .bottom))
            }
        }
        .animation(.snappy(duration: 0.3), value: showsPicker)
        .background(DSColor.background)
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showsSettings) {
            AvatarSettingsView(model: model)
        }
    }

    /// Closing the picker generates the look when the pieces changed.
    private func setPicker(_ open: Bool) {
        showsPicker = open
        if !open, !studio.worn.isEmpty, !model.isShowing(studio.worn) {
            model.generate(worn: studio.worn, pieceImage: uiImage)
        }
    }

    // MARK: Stage

    @ViewBuilder private var stage: some View {
        switch model.phase {
        case .ready:
            if let look = model.lookImage {
                AvatarLookImage(image: look)
                    .id(ObjectIdentifier(look))
            } else {
                placeholder
            }
        case .generating:
            AvatarGeneratingView(pieces: model.lookPieces, uiImage: uiImage)
        case .idle, .failed:
            placeholder
        }
    }

    private var placeholder: some View {
        AvatarView(look: studio.look, worn: studio.worn, image: image, uiImage: uiImage, zoom: studio.zoom)
            .accessibilityIdentifier("avatar.placeholder")
    }

    // MARK: Bottom bar

    @ViewBuilder private var bottomBar: some View {
        if !model.hasReference && (!studio.worn.isEmpty || !model.lookPieces.isEmpty) {
            Button { showsSettings = true } label: {
                Label("Add Photo", tabler: "TablerUpload", size: 20).frame(maxWidth: .infinity)
            }
            .buttonStyle(.ds(.primary))
            .accessibilityIdentifier("avatar.addPhoto")
        } else {
            switch model.phase {
            case .failed(let message):
                VStack(spacing: DSSpacing.sm) {
                    Text(message)
                        .font(DSFont.body)
                        .foregroundStyle(DSColor.textStrong)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                    Button {
                        if model.isShowing(studio.worn) || studio.worn.isEmpty {
                            model.retry()
                        } else {
                            model.generate(worn: studio.worn, pieceImage: uiImage)
                        }
                    } label: {
                        Label("Try Again", tabler: "TablerRefresh", size: 20).frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.ds(.primary))
                }
                .accessibilityIdentifier("avatar.error")
            case .generating:
                Button("Cancel") { model.cancel() }
                    .buttonStyle(.ds(.glass))
                    .accessibilityIdentifier("avatar.cancel")
            case .ready:
                AvatarPieceStrip(pieces: model.lookPieces, uiImage: uiImage)
            case .idle:
                EmptyView()
            }
        }
    }
}

// MARK: - Piece strip

/// Thumbnails of the pieces in the look (the item chips in the reference video).
private struct AvatarPieceStrip: View {
    let pieces: [ClothingItem]
    let uiImage: (ClothingItem) -> UIImage?

    var body: some View {
        HStack(spacing: DSSpacing.xs) {
            ForEach(pieces) { item in
                Group {
                    if let photo = uiImage(item) {
                        Image(uiImage: photo).resizable().scaledToFit()
                    } else {
                        DSIcon("TablerShirt", size: 20).foregroundStyle(DSColor.iconMuted)
                    }
                }
                .frame(width: 36, height: 36)
                .accessibilityLabel(item.name)
            }
        }
        .padding(.horizontal, DSSpacing.md)
        .frame(minHeight: 50)
        .background(DSColor.tile, in: Capsule())
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("avatar.pieces")
    }
}

// MARK: - Piece picker

/// Bottom picker from the Avatar mockups: a search button and flat chips (Outfits, then one per
/// category in the closet) over a two-column grid. Tapping a piece wears or removes it; tapping an
/// outfit wears all of its pieces. The search button swaps the chips for a field and Cancel.
private struct AvatarPiecePicker: View {
    private enum Section: Hashable {
        case outfits
        case shop
        case category(ClothingCategory)

        var title: String {
            switch self {
            case .outfits: "Outfits"
            case .shop: "Shop"
            case .category(let category): category.pickerTitle
            }
        }
    }

    @ObservedObject var studio: OutfitStudioModel
    @ObservedObject var closet: PrototypeClosetStore
    @ObservedObject var outfits: PrototypeOutfitStore
    @ObservedObject var catalog: AvatarCatalogStore
    let uiImage: (ClothingItem) -> UIImage?

    @State private var section: Section = .outfits
    @State private var isSearching = false
    @State private var query = ""
    @FocusState private var searchFocused: Bool

    private let columns = [GridItem(.flexible(), spacing: DSSpacing.md), GridItem(.flexible(), spacing: DSSpacing.md)]

    private var sections: [Section] {
        let present = Set(closet.items.map(\.category))
        // Shop appears once the shared catalog has products with photos (it needs a real sign-in).
        let shop: [Section] = catalog.products.isEmpty ? [] : [.shop]
        return [.outfits] + shop + ClothingCategory.pickerOrder.filter(present.contains).map(Section.category)
    }

    private var trimmedQuery: String { query.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.horizontal, DSSpacing.lg)
                .padding(.top, DSSpacing.lg)
                .padding(.bottom, DSSpacing.md)
            ScrollView {
                LazyVGrid(columns: columns, spacing: DSSpacing.md) {
                    switch section {
                    case .outfits: outfitTiles
                    case .shop: shopTiles
                    case .category(let category): pieceTiles(category)
                    }
                }
                .padding(.horizontal, DSSpacing.lg)
                .padding(.bottom, DSSpacing.lg)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 440)
        .background(
            UnevenRoundedRectangle(topLeadingRadius: DSRadius.lg, topTrailingRadius: DSRadius.lg, style: .continuous)
                .fill(DSColor.background)
                .ignoresSafeArea(edges: .bottom)
        )
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("avatar.picker")
        .task { await catalog.load() }
    }

    @ViewBuilder private var header: some View {
        if isSearching {
            HStack(spacing: DSSpacing.md) {
                DSSearchField(prompt: "Search \(section.title)", query: $query)
                    .focused($searchFocused)
                    .accessibilityIdentifier("avatar.picker.search")
                Button("Cancel") {
                    query = ""
                    isSearching = false
                }
                .font(DSFont.body)
                .foregroundStyle(DSColor.textPrimary)
            }
            .onAppear { searchFocused = true }
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DSSpacing.sm) {
                    Button { isSearching = true } label: {
                        DSIcon("TablerSearch", size: 22).foregroundStyle(DSColor.textPrimary)
                            .frame(width: 44, height: 44)
                            .background(DSColor.tile, in: Circle())
                    }
                    .buttonStyle(.dsPress)
                    .accessibilityLabel("Search")
                    .accessibilityIdentifier("avatar.picker.searchButton")
                    ForEach(sections, id: \.self) { option in
                        DSChip(title: option.title, isSelected: section == option, style: .flat) { section = option }
                            .accessibilityIdentifier("avatar.picker.\(option.title)")
                    }
                }
            }
            .scrollClipDisabled()
        }
    }

    @ViewBuilder private var outfitTiles: some View {
        let wornIds = Set(studio.worn.values.map(\.id))
        ForEach(outfits.outfits.filter { trimmedQuery.isEmpty || ($0.name ?? "").localizedCaseInsensitiveContains(trimmedQuery) }) { outfit in
            let pieces = outfit.placements.compactMap { closet.item(id: $0.itemId) }
            let isWorn = !pieces.isEmpty && Set(pieces.map(\.id)) == wornIds
            Button {
                var worn: [ClothingCategory: ClothingItem] = [:]
                for item in pieces { worn[item.category] = item }
                studio.worn = isWorn ? [:] : worn
            } label: {
                DSOutfitCollage(count: min(4, pieces.count), isHighlighted: isWorn) { index in
                    pieceImage(pieces[index])
                }
                .overlay(alignment: .topLeading) {
                    if isWorn { DSSelectionMark(isChecked: true).padding(14) }
                }
            }
            .buttonStyle(.dsPress(0.98))
            .accessibilityLabel(outfit.name ?? "Outfit")
            .accessibilityAddTraits(isWorn ? .isSelected : [])
        }
    }

    /// Catalog products, shown once their photo has downloaded; tapping wears or removes one.
    @ViewBuilder private var shopTiles: some View {
        ForEach(catalog.products.filter { trimmedQuery.isEmpty || $0.title.localizedCaseInsensitiveContains(trimmedQuery) }) { product in
            let item = catalog.item(for: product)
            let isWorn = studio.worn[item.category]?.id == item.id
            let photo = catalog.image(for: item.id)
            Button { studio.toggle(item) } label: {
                DSTile(isHighlighted: isWorn, isChecked: isWorn ? true : nil) {
                    if let photo {
                        Image(uiImage: photo).resizable().scaledToFit()
                    } else {
                        ProgressView()
                    }
                }
            }
            .buttonStyle(.dsPress(0.98))
            .disabled(photo == nil)
            .accessibilityLabel(product.title)
            .accessibilityAddTraits(isWorn ? .isSelected : [])
            .task { await catalog.loadImage(for: product) }
        }
    }

    @ViewBuilder private func pieceTiles(_ category: ClothingCategory) -> some View {
        ForEach(closet.items.filter { $0.category == category && (trimmedQuery.isEmpty || $0.name.localizedCaseInsensitiveContains(trimmedQuery)) }) { item in
            let isWorn = studio.worn[item.category]?.id == item.id
            Button { studio.toggle(item) } label: {
                DSTile(isHighlighted: isWorn, isChecked: isWorn ? true : nil) { pieceImage(item) }
            }
            .buttonStyle(.dsPress(0.98))
            .accessibilityLabel(item.name)
            .accessibilityAddTraits(isWorn ? .isSelected : [])
        }
    }

    @ViewBuilder private func pieceImage(_ item: ClothingItem) -> some View {
        if let photo = uiImage(item) {
            Image(uiImage: photo).resizable().scaledToFit()
        } else {
            DSIcon("TablerPhoto", size: 40).foregroundStyle(DSColor.textMuted)
        }
    }
}

private extension ClothingCategory {
    static let pickerOrder: [ClothingCategory] = [.tops, .outerwear, .pants, .skirts, .dresses, .shoes, .accessories, .other]

    /// Chip titles from the Avatar mockups ("Jackets" for outerwear).
    var pickerTitle: String {
        switch self {
        case .outerwear: "Jackets"
        default: rawValue.capitalized
        }
    }
}

#Preview {
    let model = AvatarTryOnModel(ownerId: nil, generator: MockAvatarImageGenerator())
    return AvatarTabView(
        model: model,
        studio: OutfitStudioModel(),
        closet: PrototypeClosetStore(ownerId: "preview"),
        outfits: PrototypeOutfitStore(ownerId: "preview"),
        catalog: AvatarCatalogStore(ownerId: "preview", service: DemoCatalogService()),
        ownerId: "preview",
        onSignOut: {},
        image: { _ in Image("TablerShirt") },
        closetImage: { _ in nil }
    )
}
