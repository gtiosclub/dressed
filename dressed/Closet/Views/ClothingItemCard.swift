import SwiftUI

// Starter for VIZ-01 (#56). The parent decides what a tap opens.
struct ClothingItemCard: View {
    let image: Image
    let name: String
    let category: ClothingCategory
    let onTap: () -> Void

    var body: some View {
        // TODO(#56): Display the image, name, and a readable category label.
        // Let long names wrap or truncate, and call onTap when tapped.
        EmptyView()
    }
}

#Preview {
    ClothingItemCard(
        image: Image(systemName: "photo"),
        name: "Blue shirt",
        category: .tops,
        onTap: {}
    )
}
