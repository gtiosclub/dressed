import SwiftUI

/// Retail products appear in the For You grid as photos only, like the outfit photos (Figma 915:933, 1380:337).
/// Titles, retailers and prices live on the product page that opens on tap.
struct DiscoveryRetailPhotoTile: View {
    let product: CatalogProduct

    var body: some View {
        NavigationLink { DiscoveryIdeaDetailView(product: product) } label: {
            Color.clear
                .aspectRatio(1, contentMode: .fit)
                .overlay { CatalogProductImage(product: product) }
                .clipShape(RoundedRectangle(cornerRadius: DSRadius.lg, style: .continuous))
        }
        .buttonStyle(.dsPress(0.98))
        .accessibilityLabel("\(product.title), \(product.sourceName)")
        .accessibilityIdentifier("catalog.product.\(product.id)")
    }
}

enum DiscoveryRetailPhotos {
    /// One product per category, preferring a retailer not yet shown, so the grid stays varied.
    static func featured(_ products: [CatalogProduct]) -> [CatalogProduct] {
        var retailers: Set<String> = []
        return ClothingCategory.allCases.compactMap { category in
            let matches = products.filter { $0.category == category && $0.displayImageURL != nil }
            let selected = matches.first { !retailers.contains($0.sourceId) } ?? matches.first
            if let selected { retailers.insert(selected.sourceId) }
            return selected
        }
    }
}
