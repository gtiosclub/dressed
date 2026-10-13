import SwiftUI

// VIZ-03 (#74). Arranges ClothingItemCard views (#56) in two columns.
// Inputs: the items to show. Action: a tap sends that item's ID to the parent.
// The parent owns scrolling, data loading, and what a tapped ID opens.
struct ClosetItemGrid: View {
    let items: [ClothingItem]
    let image: (ClothingItem) -> Image
    let onSelect: (String) -> Void

    private let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]

    init(
        items: [ClothingItem],
        image: @escaping (ClothingItem) -> Image = { _ in Image(systemName: "photo") },
        onSelect: @escaping (String) -> Void
    ) {
        self.items = items
        self.image = image
        self.onSelect = onSelect
    }

    var body: some View {
        if items.isEmpty {
            Text("No clothes yet")
                .font(.headline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, minHeight: 200)
        } else {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(items) { item in
                    ClothingItemCard(
                        image: image(item),
                        name: item.name,
                        category: item.category,
                        onTap: { onSelect(item.id) }
                    )
                }
            }
            .padding()
        }
    }
}

private extension ClothingItem {
    static let previewSamples: [ClothingItem] = [
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
}

#Preview("Six items") {
    @Previewable @State var lastTappedID = "None"

    ScrollView {
        Text("Last tapped: \(lastTappedID)")
            .font(.caption)
        ClosetItemGrid(items: ClothingItem.previewSamples) { id in
            lastTappedID = id
        }
    }
}

#Preview("Empty") {
    ClosetItemGrid(items: []) { _ in }
}
