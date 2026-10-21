import SwiftUI

struct PrototypeCatalogView: View {
    @StateObject private var model: CatalogViewModel
    @State private var query = ""
    @State private var category: ClothingCategory?

    init(service: any CatalogSearching = HTTPCatalogService(baseURL: CatalogConfiguration.baseURL)) {
        _model = StateObject(wrappedValue: CatalogViewModel(service: service))
    }

    var body: some View {
        VStack(spacing: 0) {
            SearchField(query: $query, placeholder: "Search products")
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 12)

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Menu {
                        Button("All Categories") { category = nil }
                        ForEach(ClothingCategory.allCases, id: \.self) { option in
                            Button(option.rawValue.capitalized) { category = option }
                        }
                    } label: {
                        Label(category?.rawValue.capitalized ?? "All Categories", systemImage: "line.3.horizontal.decrease")
                    }
                    .accessibilityLabel("Filter catalog by category")

                    switch model.state {
                    case .idle, .loading:
                        ProgressView("Loading products…")
                            .frame(maxWidth: .infinity, minHeight: 260)
                    case .loaded(let products) where products.isEmpty:
                        ContentUnavailableView(
                            "No matching products",
                            systemImage: "magnifyingglass",
                            description: Text("Try another name or category.")
                        )
                        .frame(maxWidth: .infinity, minHeight: 260)
                    case .loaded(let products):
                        LazyVStack(spacing: 10) {
                            ForEach(products) { product in productRow(product) }
                        }
                    case .failed(let message):
                        ContentUnavailableView {
                            Label("Catalog unavailable", systemImage: "wifi.exclamationmark")
                        } description: {
                            Text(message)
                        } actions: {
                            Button("Retry") { reload() }
                        }
                        .frame(maxWidth: .infinity, minHeight: 260)
                    }
                }
                .padding()
            }
        }
        .task(id: SearchInput(query: query, category: category)) {
            if !query.isEmpty { try? await Task.sleep(for: .milliseconds(300)) }
            guard !Task.isCancelled else { return }
            reload()
        }
        .onDisappear { model.cancel() }
    }

    private func reload() {
        model.search(query: query, category: category)
    }

    private func productRow(_ product: CatalogProduct) -> some View {
        Link(destination: product.productURL) {
            HStack(alignment: .top, spacing: 12) {
                AsyncImage(url: product.imageURL) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Image(systemName: "tag")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
                .frame(width: 48, height: 56)
                .clipped()
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
                VStack(alignment: .leading, spacing: 4) {
                    Text(product.title)
                        .font(.headline)
                    Text(product.brand ?? product.sourceName)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    HStack {
                        Text(product.category.rawValue.capitalized)
                        Spacer()
                        if let cents = product.priceCents, let currency = product.currency {
                            Text((Double(cents) / 100).formatted(.currency(code: currency)))
                        }
                    }
                    .font(.subheadline)
                    Text("View at \(product.sourceName)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
    }
}

private struct SearchInput: Hashable {
    let query: String
    let category: ClothingCategory?
}
