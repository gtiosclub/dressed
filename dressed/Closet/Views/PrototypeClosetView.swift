import SwiftUI

/// My Closet (Figma 915:526, 973:5888): a chip row, a photo grid and a floating search button.
/// Outfits is the first chip; Wishlist keeps its list as the third, so it stays on screen.
struct PrototypeClosetView: View {
    private enum Filter: Hashable {
        case outfits
        case all
        case category(ClothingCategory)
        case wishlist

        var title: String {
            switch self {
            case .outfits: "Outfits"
            case .all: "All"
            case .category(let category): category.rawValue.capitalized
            case .wishlist: "Wishlist"
            }
        }
    }

    @ObservedObject var closet: PrototypeClosetStore
    @ObservedObject var outfits: PrototypeOutfitStore
    @StateObject private var productLinks: ProductLinkStore
    @Binding var isSearching: Bool
    @Binding var searchText: String
    @State private var filter: Filter = .all
    @State private var showingOutfitEditor = false
    let onTryOn: (ClothingItem) -> Void
    let onTryOutfit: (Outfit) -> Void

    private let columns = [GridItem(.flexible(), spacing: DSSpacing.md), GridItem(.flexible(), spacing: DSSpacing.md)]
    private let filters: [Filter] = [.outfits, .all, .wishlist] + ClothingCategory.allCases.map(Filter.category)

    init(
        closet: PrototypeClosetStore,
        outfits: PrototypeOutfitStore,
        ownerId: String,
        isSearching: Binding<Bool> = .constant(false),
        searchText: Binding<String> = .constant(""),
        onTryOn: @escaping (ClothingItem) -> Void,
        onTryOutfit: @escaping (Outfit) -> Void
    ) {
        _closet = ObservedObject(wrappedValue: closet)
        _outfits = ObservedObject(wrappedValue: outfits)
        _isSearching = isSearching
        _searchText = searchText
        self.onTryOn = onTryOn
        self.onTryOutfit = onTryOutfit
        _productLinks = StateObject(wrappedValue: ProductLinkStore(ownerId: ownerId))
    }

    private var trimmedSearch: String { searchText.trimmingCharacters(in: .whitespacesAndNewlines) }

    private var visibleItems: [ClothingItem] {
        closet.items.filter { item in
            switch filter {
            case .category(let category): item.category == category
            default: true
            }
        }
        .filter { trimmedSearch.isEmpty || $0.name.localizedCaseInsensitiveContains(trimmedSearch) }
    }

    private var visibleOutfits: [Outfit] {
        outfits.outfits.filter { trimmedSearch.isEmpty || ($0.name ?? "").localizedCaseInsensitiveContains(trimmedSearch) }
    }

    /// The piece or outfit added in the last day wears the "New" badge.
    private func isNew(_ date: Date, newest: Date?) -> Bool {
        date == newest && Date.now.timeIntervalSince(date) < 24 * 60 * 60
    }

    var body: some View {
        VStack(spacing: 0) {
            chipRow
            switch filter {
            case .outfits: outfitsContent
            case .wishlist: wishlistContent
            default: piecesContent
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DSColor.background)
        .overlay(alignment: .bottom) {
            if filter != .wishlist { floatingBar }
        }
        .toolbar(.hidden, for: .navigationBar)
        .navigationDestination(isPresented: $showingOutfitEditor) {
            PrototypeOutfitEditorView(closet: closet, outfits: outfits)
        }
        .onAppear {
            closet.reload()
            outfits.reload()
            productLinks.reload()
        }
    }

    private var chipRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DSSpacing.sm) {
                ForEach(filters, id: \.self) { option in
                    DSChip(title: option.title, isSelected: filter == option) { filter = option }
                        .accessibilityIdentifier("closet.filter.\(option.title)")
                }
            }
            .padding(.horizontal, DSSpacing.lg)
            .padding(.vertical, DSSpacing.md)
        }
    }

    private var floatingBar: some View {
        HStack(spacing: DSSpacing.sm) {
            DSFloatingSearchButton(title: trimmedSearch.isEmpty ? "Search Your Closet" : trimmedSearch) {
                isSearching = true
            }
            .accessibilityIdentifier("closet.searchButton")
            if filter == .outfits {
                DSFloatingActionButton(accessibilityLabel: "New Outfit") { showingOutfitEditor = true }
                    .disabled(closet.items.isEmpty || closet.error != nil)
                    .accessibilityIdentifier("closet.newOutfit")
            }
        }
        .padding(.horizontal, DSSpacing.lg)
        .padding(.bottom, DSSpacing.sm)
    }

    /// Room for the floating bar so the last row can scroll clear of it.
    private var bottomInset: CGFloat { DSFloatingSearchButton.height + 2 * DSSpacing.lg }

    @ViewBuilder
    private var wishlistContent: some View {
        if let error = productLinks.error {
            ContentUnavailableView("Could not load Wishlist", tabler: "TablerAlertTriangle",
                                   description: Text(error))
        } else if productLinks.links.isEmpty {
            ContentUnavailableView("No saved links", tabler: "TablerHeart",
                                   description: Text("Paste a product link in Camera or share one to Dressed."))
        } else {
            List {
                ForEach(productLinks.links) { item in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(item.name).font(DSFont.bodyEmphasis)
                        Text(item.category.rawValue.capitalized)
                            .foregroundStyle(DSColor.textMuted)
                        Text(item.productURL.host ?? "Product link")
                            .font(.footnote)
                            .foregroundStyle(DSColor.textMuted)
                        Link("Open product page", destination: item.productURL)
                    }
                    .accessibilityElement(children: .contain)
                }
                .onDelete { offsets in
                    for index in offsets {
                        try? productLinks.delete(id: productLinks.links[index].id)
                    }
                }
            }
            .listStyle(.plain)
        }
    }

    @ViewBuilder
    private var piecesContent: some View {
        Group {
            if let error = closet.error {
                ContentUnavailableView {
                    Label("Could not load closet", tabler: "TablerAlertTriangle", size: 48)
                } description: {
                    Text(error)
                } actions: {
                    Button("Try Again") { closet.reload() }
                }
            } else if closet.items.isEmpty {
                ContentUnavailableView(
                    "Your closet is empty",
                    tabler: "TablerHanger2",
                    description: Text("Add a piece from Camera or share an image to Dressed.")
                )
            } else if visibleItems.isEmpty {
                ContentUnavailableView("No matching pieces", tabler: "TablerSearch",
                                       description: Text("Try another name or category."))
            } else {
                let newest = closet.items.map(\.createdAt).max()
                ScrollView {
                    LazyVGrid(columns: columns, spacing: DSSpacing.md) {
                        ForEach(visibleItems) { item in
                            let highlighted = isNew(item.createdAt, newest: newest)
                            NavigationLink(value: item.id) {
                                DSTile(isHighlighted: highlighted) { pieceImage(item) }
                                    .overlay(alignment: .topLeading) {
                                        if highlighted { DSBadge(text: "New").padding(14) }
                                    }
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(item.name)
                            .accessibilityIdentifier("closet.piece.\(item.id)")
                        }
                    }
                    .padding(.horizontal, DSSpacing.lg)
                    .padding(.bottom, bottomInset)
                }
            }
        }
        .navigationDestination(for: String.self) { id in
            PrototypeItemDetailView(closet: closet, itemID: id, onTryOn: onTryOn)
        }
    }

    @ViewBuilder
    private var outfitsContent: some View {
        if let error = outfits.error {
            ContentUnavailableView {
                Label("Could not load outfits", tabler: "TablerAlertTriangle", size: 48)
            } description: {
                Text(error)
            } actions: {
                Button("Try Again") { outfits.reload() }
            }
        } else if outfits.outfits.isEmpty {
            ContentUnavailableView {
                Label("No outfits yet", tabler: "TablerCopy", size: 48)
            } description: {
                Text("Choose pieces from your closet to make an outfit.")
            } actions: {
                Button("New Outfit") { showingOutfitEditor = true }
                    .disabled(closet.items.isEmpty)
            }
        } else if visibleOutfits.isEmpty {
            ContentUnavailableView("No matching outfits", tabler: "TablerSearch",
                                   description: Text("Try another name."))
        } else {
            let newest = outfits.outfits.map(\.createdAt).max()
            ScrollView {
                LazyVGrid(columns: columns, spacing: DSSpacing.md) {
                    ForEach(visibleOutfits) { outfit in
                        let pieces = outfit.placements.compactMap { closet.item(id: $0.itemId) }
                        NavigationLink {
                            PrototypeOutfitDetailView(outfit: outfit, closet: closet,
                                                      onTryOutfit: onTryOutfit, onTryOn: onTryOn)
                        } label: {
                            DSOutfitCollage(count: min(4, pieces.count),
                                            isHighlighted: isNew(outfit.createdAt, newest: newest)) { index in
                                pieceImage(pieces[index])
                            }
                            .overlay(alignment: .topLeading) {
                                if isNew(outfit.createdAt, newest: newest) { DSBadge(text: "New").padding(14) }
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(outfit.name ?? "Outfit")
                        .accessibilityIdentifier("closet.outfit.\(outfit.id)")
                    }
                }
                .padding(.horizontal, DSSpacing.lg)
                .padding(.bottom, bottomInset)
            }
        }
    }

    @ViewBuilder
    private func pieceImage(_ item: ClothingItem) -> some View {
        if let image = closet.image(for: item) {
            Image(uiImage: image).resizable().scaledToFit()
        } else {
            DSIcon("TablerPhoto", size: 40).foregroundStyle(DSColor.textMuted)
        }
    }
}

struct PrototypeItemDetailView: View {
    @ObservedObject var closet: PrototypeClosetStore
    let itemID: String
    let onTryOn: (ClothingItem) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var isEditing = false
    @State private var name = ""
    @State private var category: ClothingCategory = .other
    @State private var confirmsDeletion = false
    @State private var actionError: String?

    private var item: ClothingItem? { closet.item(id: itemID) }

    var body: some View {
        Group {
            if let item {
                Form {
                    Section {
                        if let image = closet.image(for: item) {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFit()
                                .frame(maxWidth: .infinity)
                                .frame(maxHeight: 340)
                                .accessibilityLabel("Photo of \(item.name)")
                        } else {
                            ContentUnavailableView("Photo unavailable", tabler: "TablerPhoto")
                                .frame(maxWidth: .infinity)
                        }
                    }

                    Section("Piece Details") {
                        if isEditing {
                            TextField("Name", text: $name)
                            Picker("Category", selection: $category) {
                                ForEach(ClothingCategory.allCases, id: \.self) { option in
                                    Text(option.rawValue.capitalized).tag(option)
                                }
                            }
                        } else {
                            LabeledContent("Name", value: item.name)
                            LabeledContent("Category", value: item.category.rawValue.capitalized)
                            LabeledContent("Added", value: item.createdAt.formatted(date: .abbreviated, time: .omitted))
                        }
                    }

                    if isEditing {
                        Section {
                            Button("Save Changes", action: saveChanges)
                                .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            Button("Cancel", role: .cancel) { isEditing = false }
                        }
                    } else {
                        Section {
                            Button("Edit Item Details") {
                                name = item.name
                                category = item.category
                                isEditing = true
                            }
                            Button {
                                onTryOn(item)
                                dismiss()
                            } label: {
                                Label("Try On", tabler: "TablerUserCircle")
                            }
                            Button("Delete Piece", role: .destructive) { confirmsDeletion = true }
                        }
                    }
                }
                .confirmationDialog("Delete this piece?", isPresented: $confirmsDeletion) {
                    Button("Delete Piece", role: .destructive, action: deletePiece)
                } message: {
                    Text("The piece and its private photo will be removed from this device.")
                }
            } else {
                ContentUnavailableView("Piece unavailable", tabler: "TablerHanger2",
                                       description: Text("It may have been deleted."))
            }
        }
        .navigationTitle(isEditing ? "Edit Item Details" : "Piece Details")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Could not update piece", isPresented: Binding(
            get: { actionError != nil },
            set: { if !$0 { actionError = nil } }
        )) {
            Button("OK", role: .cancel) { actionError = nil }
        } message: {
            Text(actionError ?? "Please try again.")
        }
    }

    private func saveChanges() {
        do {
            try closet.updateDetails(id: itemID, name: name, category: category)
            isEditing = false
        } catch {
            actionError = error.localizedDescription
        }
    }

    private func deletePiece() {
        do {
            try closet.delete(id: itemID)
            dismiss()
        } catch {
            actionError = error.localizedDescription
            if closet.item(id: itemID) == nil { dismiss() }
        }
    }
}
