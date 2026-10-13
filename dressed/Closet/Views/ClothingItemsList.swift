//
//  ClothingItemsList.swift
//  dressed
//
//  Created by Developer on 10/13/26.
//

import SwiftUI

// Combines CategorySelector + category filtering + ClosetItemGrid.
// The parent passes in all items and handles what a tapped ID opens.
struct ClothingItemsList: View {
    let items: [ClothingItem]
    let image: (ClothingItem) -> Image
    let onSelect: (String) -> Void

    @State private var selectedCategory: ClothingCategory? = nil  // nil = All

    init(
        items: [ClothingItem],
        image: @escaping (ClothingItem) -> Image = { _ in Image(systemName: "photo") },
        onSelect: @escaping (String) -> Void
    ) {
        self.items = items
        self.image = image
        self.onSelect = onSelect
    }

    private var filteredItems: [ClothingItem] {
        guard let selectedCategory else { return items }
        return items.filter { $0.category == selectedCategory }
    }

    var body: some View {
        ScrollView {
            ClosetItemGrid(items: filteredItems, image: image, onSelect: onSelect)
        }
        .safeAreaInset(edge: .top) {
            CategorySelector(selection: $selectedCategory)
                .padding(.vertical, 8)
                .background(.background)
        }
    }
}

#Preview {
    let samples: [ClothingItem] = [
        ("item-1", "Blue shirt", ClothingCategory.tops),
        ("item-2", "Black jeans", .pants),
        ("item-3", "Pleated skirt", .skirts),
        ("item-4", "Summer dress", .dresses),
        ("item-5", "White sneakers", .shoes),
        ("item-6", "Denim jacket", .outerwear)
    ].map { id, name, category in
        ClothingItem(
            id: id,
            ownerId: "preview-owner",
            name: name,
            category: category,
            imagePath: "users/preview-owner/items/\(id).jpg",
            createdAt: .now
        )
    }

    return ClothingItemsList(items: samples) { id in
        print("Tapped \(id)")
    }
}
