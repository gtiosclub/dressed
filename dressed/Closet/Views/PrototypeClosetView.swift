import SwiftUI

struct PrototypeClosetView: View {
    @ObservedObject var closet: PrototypeClosetStore
    @State private var category: ClothingCategory?
    @State private var searchText = ""

    private var visibleItems: [ClothingItem] {
        closet.items.filter { item in
            (category == nil || item.category == category)
                && (searchText.isEmpty || item.name.localizedCaseInsensitiveContains(searchText))
        }
    }

    var body: some View {
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
        .navigationTitle("My Closet")
        .searchable(text: $searchText, prompt: "Search pieces")
        .navigationDestination(for: String.self) { id in
            PrototypeItemDetailView(closet: closet, itemID: id)
        }
        .onAppear { closet.reload() }
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

private struct PrototypeItemDetailView: View {
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
