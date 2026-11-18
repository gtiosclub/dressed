import SwiftUI

/// Retail products appear alongside outfits without changing For You / Friends routing.
struct DiscoveryRetailShelf: View {
    @StateObject private var model = CatalogViewModel(service: DiscoveryCatalogSource.current)

    var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.md) {
            HStack {
                Text("Shop retailers").font(DSFont.bodyEmphasis)
                Spacer()
                NavigationLink("See all") { DiscoveryIdeasView() }
                    .font(DSFont.button)
                    .accessibilityIdentifier("catalog.seeAll")
            }
            switch model.state {
            case .idle, .loading:
                ProgressView("Loading products…")
            case .failed:
                Text("Products couldn’t load.").font(DSFont.body)
                Button("Retry") { model.search(query: "", category: nil) }
                    .buttonStyle(.ds(.secondary))
            case .loaded(let products):
                if products.isEmpty {
                    Text("No retailer products yet.").font(DSFont.body)
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(alignment: .top, spacing: DSSpacing.md) {
                            ForEach(featured(products)) { product in
                                NavigationLink { DiscoveryIdeaDetailView(product: product) } label: {
                                    VStack(alignment: .leading, spacing: DSSpacing.xs) {
                                        CatalogProductImage(product: product)
                                            .frame(width: 160, height: 190)
                                            .clipped()
                                        Text(product.title).font(DSFont.bodyEmphasis).lineLimit(2)
                                        Text(product.sourceName).font(DSFont.search)
                                            .foregroundStyle(DSColor.textMuted)
                                        if let price = product.formattedPrice { Text(price).font(DSFont.search) }
                                    }
                                    .frame(width: 160, alignment: .leading)
                                    .foregroundStyle(DSColor.textPrimary)
                                }
                                .buttonStyle(.plain)
                                .accessibilityIdentifier("catalog.product.\(product.id)")
                            }
                        }
                    }
                }
            }
        }
        .accessibilityIdentifier("catalog.retailShelf")
        .task { model.search(query: "", category: nil) }
        .onDisappear { model.cancel() }
    }

    private func featured(_ products: [CatalogProduct]) -> [CatalogProduct] {
        var retailers: Set<String> = []
        return ClothingCategory.allCases.compactMap { category in
            let matches = products.filter { $0.category == category }
            let selected = matches.first { !retailers.contains($0.sourceId) } ?? matches.first
            if let selected { retailers.insert(selected.sourceId) }
            return selected
        }
    }
}
