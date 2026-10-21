import SwiftUI

/// A supplied catalog result. The parent decides what opening the product means.
struct CatalogProductRow: View {
    let product: CatalogProduct
    let onTap: (String) -> Void

    var body: some View {
        Button {
            onTap(product.id)
        } label: {
            CatalogProductRowLayout {
                CatalogProductImage(product: product)
            } details: {
                VStack(alignment: .leading, spacing: 4) {
                    Text(product.title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text(product.brand ?? product.sourceName)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(product.category.rawValue.capitalized)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if let price = product.formattedPrice {
                        Text(price)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                    }
                    Label("View at \(product.sourceName)", systemImage: "arrow.up.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

/// Shared product-style row layout; a published post piece remains a snapshot, not a catalog result.
struct CatalogProductRowLayout<Artwork: View, Details: View>: View {
    let backgroundColor: Color
    let artwork: Artwork
    let details: Details

    init(
        backgroundColor: Color = Color(.secondarySystemBackground),
        @ViewBuilder artwork: () -> Artwork,
        @ViewBuilder details: () -> Details
    ) {
        self.backgroundColor = backgroundColor
        self.artwork = artwork()
        self.details = details()
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            artwork
                .frame(width: 72, height: 72)
            details
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(backgroundColor, in: RoundedRectangle(cornerRadius: 12))
    }
}

struct CatalogProductImage: View {
    let product: CatalogProduct

    var body: some View {
        AsyncImage(url: product.imageURL) { phase in
            if case .success(let image) = phase {
                image.resizable().scaledToFill()
            } else {
                GarmentArtwork(category: product.category)
                    .padding(10)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGray5))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .accessibilityHidden(true)
    }
}

extension CatalogProduct {
    var formattedPrice: String? {
        guard let priceCents, let currency else { return nil }
        return (Double(priceCents) / 100).formatted(.currency(code: currency))
    }
}
