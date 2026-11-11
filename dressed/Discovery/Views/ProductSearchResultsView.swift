import SwiftUI

/// Keeps the two import screens' integration to one action each.
struct FindSimilarProductsButton: View {
    let candidate: ImportCandidate
    let sourceImage: Data
    let ownerId: String
    @State private var crop: ReviewImage?
    @State private var errorMessage: String?

    var body: some View {
        #if DEBUG && targetEnvironment(simulator)
        Button("Find similar products", systemImage: "magnifyingglass") {
            do {
                let data = try SharedImportDraftStore.imageData(for: candidate, in: sourceImage)
                crop = ReviewImage(id: UUID().uuidString, data: data, source: candidate.name, isShared: false)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
        .accessibilityIdentifier("productSearch.open.\(candidate.id)")
        .sheet(item: $crop) { image in
            ProductSearchResultsView(image: image, ownerId: ownerId)
        }
        .alert("Could not prepare crop", isPresented: Binding(
            get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "Adjust the image region and retry.")
        }
        #endif
    }
}

struct ProductSearchResultsView: View {
    let image: ReviewImage
    let ownerId: String
    @StateObject private var model = ProductSearchViewModel()
    @State private var attempt = 0
    @State private var reviewLink: ReviewProductLink?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("Review search photo") {
                    if let preview = UIImage(data: image.data) {
                        Image(uiImage: preview).resizable().scaledToFit()
                            .frame(maxWidth: .infinity, maxHeight: 150)
                    }
                    Text("Search sends this crop to SerpAPI / Google Lens. Use development photos only. Close to adjust the region first.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                results
            }
            .navigationTitle("Similar products")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .task(id: attempt) {
                guard attempt > 0 else { return }
                await model.search(image: image.data)
            }
            .sheet(item: $reviewLink) { link in
                ProductLinkReviewView(link: link, ownerId: ownerId,
                                      onLater: { reviewLink = nil }, onSaved: { reviewLink = nil })
            }
        }
    }

    @ViewBuilder private var results: some View {
        switch model.state {
        case .idle:
            Button("Search this crop") { attempt += 1 }
                .accessibilityIdentifier("productSearch.search")
        case .loading:
            ProgressView("Searching for similar products…")
        case .failed(let message):
            Text(message).foregroundStyle(.secondary)
            Button("Retry search") { attempt += 1 }
        case .loaded(let response):
            Section {
                Text(response.provider).font(.caption).foregroundStyle(.secondary)
                Text("Visual resemblance does not identify the exact product. Check price and availability on the retailer's page.")
                    .font(.footnote)
                if response.matches.isEmpty {
                    ContentUnavailableView("No similar products found", systemImage: "magnifyingglass",
                                           description: Text("Close and adjust the crop, or continue entering details manually."))
                }
                ForEach(response.matches) { match in
                    resultRow(match)
                }
            }
        }
    }

    private func resultRow(_ match: ProductSearchMatch) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            CatalogProductRowLayout {
                AsyncImage(url: match.imageURL) { phase in
                    if let image = phase.image {
                        image.resizable().scaledToFit()
                    } else {
                        Image(systemName: "photo").foregroundStyle(.secondary)
                    }
                }
            } details: {
                VStack(alignment: .leading, spacing: 4) {
                    Text(match.title).font(.headline)
                    Text(match.source).font(.subheadline)
                    if let price = match.price { Text("Listed price: \(price)") }
                    Text("Similar · source not verified").font(.caption).foregroundStyle(.secondary)
                }
            }
            Link("Open source page", destination: match.productURL)
            Button("Review for Wishlist") {
                reviewLink = ReviewProductLink(id: match.id, url: match.productURL, isShared: false)
            }
        }
    }
}
