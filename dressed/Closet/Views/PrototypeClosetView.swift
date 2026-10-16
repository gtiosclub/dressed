import SwiftUI

struct PrototypeClosetView: View {
    @ObservedObject var closet: PrototypeClosetStore
    @StateObject private var outfits: PrototypeOutfitStore
    @StateObject private var productLinks: ProductLinkStore
    @State private var category: ClothingCategory?
    @State private var searchText = ""
    @State private var section = 0
    @State private var showingOutfitEditor = false

    init(closet: PrototypeClosetStore, ownerId: String) {
        self.closet = closet
        _outfits = StateObject(wrappedValue: PrototypeOutfitStore(ownerId: ownerId))
        _productLinks = StateObject(wrappedValue: ProductLinkStore(ownerId: ownerId))
    }

    private var visibleItems: [ClothingItem] {
        closet.items.filter { item in
            (category == nil || item.category == category)
                && (searchText.isEmpty || item.name.localizedCaseInsensitiveContains(searchText))
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker("Closet Section", selection: $section) {
                Text("Pieces").tag(0)
                Text("Outfits").tag(1)
                Text("Wishlist").tag(2)
            }
            .pickerStyle(.segmented)
            .padding()

            if section == 0 {
                piecesContent
            } else if section == 1 {
                outfitsContent
            } else {
                wishlistContent
            }
        }
        .navigationTitle("My Closet")
        .toolbar {
            if section == 1 {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("New Outfit", systemImage: "plus") { showingOutfitEditor = true }
                        .disabled(closet.items.isEmpty || closet.error != nil)
                }
            }
        }
        .sheet(isPresented: $showingOutfitEditor) {
            PrototypeOutfitEditorView(closet: closet, outfits: outfits)
        }
        .onAppear {
            closet.reload()
            outfits.reload()
            productLinks.reload()
        }
    }

    @ViewBuilder
    private var wishlistContent: some View {
        if let error = productLinks.error {
            ContentUnavailableView("Could not load Wishlist", systemImage: "exclamationmark.triangle",
                                   description: Text(error))
        } else if productLinks.links.isEmpty {
            ContentUnavailableView("No saved links", systemImage: "heart",
                                   description: Text("Paste a product link in Camera or share one to Dressed."))
        } else {
            List {
                ForEach(productLinks.links) { item in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(item.name).font(.headline)
                        Text(item.category.rawValue.capitalized)
                            .foregroundStyle(.secondary)
                        Text(item.productURL.host ?? "Product link")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
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
        }
    }

    @ViewBuilder
    private var piecesContent: some View {
        Group {
            if let error = closet.error {
                ContentUnavailableView {
                    Label("Could not load closet", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(error)
                } actions: {
                    Button("Try Again") { closet.reload() }
                }
            } else if closet.items.isEmpty {
                ContentUnavailableView(
                    "Your closet is empty",
                    systemImage: "hanger",
                    description: Text("Add a piece from Camera or share an image to Dressed.")
                )
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text("Pieces")
                                .font(.title2.bold())
                            Spacer()
                            Menu {
                                Button("All Categories") { category = nil }
                                ForEach(ClothingCategory.allCases, id: \.self) { option in
                                    Button(option.rawValue.capitalized) { category = option }
                                }
                            } label: {
                                Label(category?.rawValue.capitalized ?? "All Categories", systemImage: "line.3.horizontal.decrease")
                                    .font(.subheadline)
                            }
                            .accessibilityLabel("Filter pieces by category")
                        }

                        if visibleItems.isEmpty {
                            ContentUnavailableView("No matching pieces", systemImage: "magnifyingglass",
                                                   description: Text("Try another name or category."))
                                .frame(maxWidth: .infinity)
                                .frame(minHeight: 300)
                        } else {
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 145), spacing: 12)], spacing: 12) {
                                ForEach(visibleItems) { item in
                                    NavigationLink(value: item.id) {
                                        pieceCard(item)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                    .padding()
                }
            }
        }
        .searchable(text: $searchText, prompt: "Search pieces")
        .navigationDestination(for: String.self) { id in
            PrototypeItemDetailView(closet: closet, itemID: id)
        }
    }

    @ViewBuilder
    private var outfitsContent: some View {
        if let error = outfits.error {
            ContentUnavailableView {
                Label("Could not load outfits", systemImage: "exclamationmark.triangle")
            } description: {
                Text(error)
            } actions: {
                Button("Try Again") { outfits.reload() }
            }
        } else if outfits.outfits.isEmpty {
            ContentUnavailableView {
                Label("No outfits yet", systemImage: "square.on.square")
            } description: {
                Text("Choose pieces from your closet to make an outfit.")
            } actions: {
                Button("New Outfit") { showingOutfitEditor = true }
                    .disabled(closet.items.isEmpty)
            }
        } else {
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 155), spacing: 12)], spacing: 12) {
                    ForEach(outfits.outfits) { outfit in
                        NavigationLink {
                            PrototypeOutfitDetailView(outfit: outfit, closet: closet)
                        } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                Image(systemName: "square.on.square")
                                    .font(.largeTitle)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 100)
                                Text(outfit.name ?? "Outfit")
                                    .font(.headline)
                                Text("\(outfit.placements.count) pieces")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)
                            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding()
            }
        }
    }

    private func pieceCard(_ item: ClothingItem) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Group {
                if let image = closet.image(for: item) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    Image(systemName: "photo")
                        .resizable()
                        .scaledToFit()
                        .padding(40)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(height: 160)
            .frame(maxWidth: .infinity)
            .clipped()
            Text(item.name)
                .font(.headline)
                .lineLimit(2)
            Text(item.category.rawValue.capitalized)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
        .accessibilityElement(children: .combine)
    }
}

struct PrototypeItemDetailView: View {
    @ObservedObject var closet: PrototypeClosetStore
    let itemID: String

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
                            ContentUnavailableView("Photo unavailable", systemImage: "photo")
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
                ContentUnavailableView("Piece unavailable", systemImage: "hanger",
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
