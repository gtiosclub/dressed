//
//  WardrobeView.swift
//  dressed
//

import SwiftUI

struct WardrobeView: View {
    @State private var selectedCategory: ClothingCategory?
    @State private var searchText = ""

    private let columns = [GridItem(.adaptive(minimum: 110), spacing: 16)]

    private var items: [ClothingItem] {
        ClothingItem.samples.filter { item in
            (selectedCategory == nil || item.category == selectedCategory)
            && (searchText.isEmpty || item.name.localizedCaseInsensitiveContains(searchText))
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                categoryFilter
                    .padding(.bottom, 8)

                if items.isEmpty {
                    ContentUnavailableView("No items", systemImage: "square.grid.2x2", description: Text("Nothing matches that filter yet."))
                        .padding(.top, 60)
                } else {
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(items) { item in
                            ItemTile(item: item)
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .searchable(text: $searchText, prompt: "Search your closet")
            .navigationTitle("Wardrobe")
            .toolbar {
                Button {
                    // TODO: hook up the add-item flow
                } label: {
                    Label("Add item", systemImage: "plus")
                }
            }
        }
    }

    private var categoryFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chip(title: "All", isSelected: selectedCategory == nil) { selectedCategory = nil }

                ForEach(ClothingCategory.allCases) { category in
                    chip(title: category.rawValue, isSelected: selectedCategory == category) {
                        selectedCategory = selectedCategory == category ? nil : category
                    }
                }
            }
            .padding(.horizontal)
        }
    }

    private func chip(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(isSelected ? Color.accentColor : Color(.secondarySystemBackground),
                            in: Capsule())
                .foregroundStyle(isSelected ? Color.white : Color.primary)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    WardrobeView()
}
