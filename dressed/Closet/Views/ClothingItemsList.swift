//
//  ClothingItemsList.swift
//  dressed
//

import SwiftUI

// Two tabs: Clothing (category chips + item grid) and Outfits (saved outfits as OutfitPreviewCards).
// The parent passes in the data and handles what a tap opens.
struct ClothingItemsList: View {
    enum ListTab: String, CaseIterable, Identifiable {
        case clothing = "Clothing"
        case outfits = "Outfits"
        var id: String { rawValue }
    }

    let items: [ClothingItem]
    let outfits: [SavedOutfit]
    let image: (ClothingItem) -> Image
    let onSelect: (String) -> Void
    let onSelectOutfit: (UUID) -> Void

    @State private var tab: ListTab = .clothing
    @State private var selectedCategory: ClothingCategory? = nil  // nil = All

    // OutfitPreviewCard is a fixed 200 wide, so this is one column on a phone and more on wider screens.
    private let outfitColumns = [GridItem(.adaptive(minimum: 200), spacing: 16)]

    init(
        items: [ClothingItem],
        outfits: [SavedOutfit] = [],
        image: @escaping (ClothingItem) -> Image = { _ in Image(systemName: "photo") },
        onSelect: @escaping (String) -> Void,
        onSelectOutfit: @escaping (UUID) -> Void = { _ in }
    ) {
        self.items = items
        self.outfits = outfits
        self.image = image
        self.onSelect = onSelect
        self.onSelectOutfit = onSelectOutfit
    }

    private var filteredItems: [ClothingItem] {
        guard let selectedCategory else { return items }
        return items.filter { $0.category == selectedCategory }
    }

    var body: some View {
        ScrollView {
            switch tab {
            case .clothing:
                ClosetItemGrid(items: filteredItems, image: image, onSelect: onSelect)
            case .outfits:
                outfitsGrid
            }
        }
        .safeAreaInset(edge: .top) {
            VStack(spacing: 8) {
                Picker("Section", selection: $tab) {
                    ForEach(ListTab.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

                if tab == .clothing {
                    CategorySelector(selection: $selectedCategory)
                }
            }
            .padding(.vertical, 0)
            .background(.background)
        }
    }

    @ViewBuilder
    private var outfitsGrid: some View {
        if outfits.isEmpty {
            Text("No saved outfits yet")
                .font(.headline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, minHeight: 200)
        } else {
            LazyVGrid(columns: outfitColumns, spacing: 16) {
                ForEach(outfits) { outfit in
                    OutfitPreviewCard(
                        name: outfit.name,
                        image: Image(systemName: "figure.stand"),
                        onTap: { onSelectOutfit(outfit.id) }
                    )
                    .buttonStyle(.plain)
                }
            }
            .padding()
        }
    }
}

#Preview {
    ClothingItemsList(
        items: ClothingItem.previewSamples,
        outfits: [
            SavedOutfit(name: "Monday", worn: [:]),
            SavedOutfit(name: "Weekend", worn: [:])
        ],
        onSelect: { print("Tapped item \($0)") },
        onSelectOutfit: { print("Tapped outfit \($0)") }
    )
}
