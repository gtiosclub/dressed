import Foundation
import UIKit
import Vision

/// A catalog product that looks similar to a reviewed piece. It is a visual
/// suggestion only; review must never present it as the exact product.
struct ProductMatch: Identifiable {
    let product: CatalogProduct
    let image: UIImage?
    var id: String { product.id }
}

protocol ProductMatching {
    func matches(for crop: Data, category: ClothingCategory) async throws -> [ProductMatch]
    /// Text search behind "None of these? Find it yourself."
    func search(_ query: String) async throws -> [ProductMatch]
}

/// No suggestions: review offers only the piece's own photo.
struct NoProductMatches: ProductMatching {
    func matches(for crop: Data, category: ClothingCategory) async throws -> [ProductMatch] { [] }
    func search(_ query: String) async throws -> [ProductMatch] { [] }
}

/// Ranks the signed-in catalog by on-device Vision feature-print distance to the piece's crop.
/// Products of the piece's category are compared first; other categories fill in when the
/// category has fewer than three. No photo leaves the device; only catalog images are downloaded.
@MainActor
final class CatalogVisualMatcher: ProductMatching {
    static let shared = CatalogVisualMatcher()

    private let catalog: any CatalogSearching
    private let limit = 3
    private let maxCompared = 24
    private var imageCache: [URL: Data] = [:]

    init(catalog: any CatalogSearching = DiscoveryCatalogSource.current) {
        self.catalog = catalog
    }

    func matches(for crop: Data, category: ClothingCategory) async throws -> [ProductMatch] {
        try Task.checkCancellation()
        var products = try await catalog.search(query: "", category: category == .other ? nil : category).products
        if products.count < limit {
            let others = try await catalog.search(query: "", category: nil).products
            let known = Set(products.map(\.id))
            products += others.filter { !known.contains($0.id) }
        }
        try Task.checkCancellation()
        let compared = Array(products.prefix(maxCompared))
        let urls = compared.map(\.imageURL)

        // Download what is not cached yet, concurrently.
        let missing = urls.compactMap { $0 }.filter { imageCache[$0] == nil }
        let downloaded = await Self.download(Array(Set(missing)))
        for (url, data) in downloaded { imageCache[url] = data }
        try Task.checkCancellation()

        let imageData = urls.map { $0.flatMap { imageCache[$0] } }
        let distances = await Self.rank(crop: crop, images: imageData)
        try Task.checkCancellation()

        // Products without a comparable image keep catalog order after the ranked ones.
        let order = compared.indices.sorted { lhs, rhs in
            switch (distances[lhs], distances[rhs]) {
            case let (left?, right?): return left < right
            case (.some, .none): return true
            case (.none, .some): return false
            case (.none, .none): return lhs < rhs
            }
        }
        return order.prefix(limit).map { index in
            ProductMatch(product: compared[index], image: imageData[index].flatMap(UIImage.init(data:)))
        }
    }

    func search(_ query: String) async throws -> [ProductMatch] {
        let products = Array(try await catalog.search(query: query, category: nil).products.prefix(maxCompared))
        let missing = products.compactMap(\.imageURL).filter { imageCache[$0] == nil }
        for (url, data) in await Self.download(Array(Set(missing))) { imageCache[url] = data }
        try Task.checkCancellation()
        return products.map { product in
            ProductMatch(product: product,
                         image: product.imageURL.flatMap { imageCache[$0] }.flatMap(UIImage.init(data:)))
        }
    }

    nonisolated private static func download(_ urls: [URL]) async -> [(URL, Data)] {
        await withTaskGroup(of: (URL, Data)?.self) { group in
            for url in urls where url.scheme == "https" {
                group.addTask {
                    var request = URLRequest(url: url)
                    request.timeoutInterval = 10
                    guard let (data, response) = try? await URLSession.shared.data(for: request),
                          (response as? HTTPURLResponse).map({ (200..<300).contains($0.statusCode) }) ?? false,
                          data.count <= 8_000_000, UIImage(data: data) != nil else { return nil }
                    return (url, data)
                }
            }
            var result: [(URL, Data)] = []
            for await item in group { if let item { result.append(item) } }
            return result
        }
    }

    /// Feature-print distance from the crop to each image; nil where Vision could not compare.
    nonisolated private static func rank(crop: Data, images: [Data?]) async -> [Float?] {
        await Task.detached(priority: .userInitiated) {
            func print(_ data: Data) -> VNFeaturePrintObservation? {
                (try? VisionRequestRunner.perform({ VNGenerateImageFeaturePrintRequest() }, on: data))?
                    .results?.first
            }
            guard let reference = print(crop) else { return images.map { _ in nil } }
            return images.map { data in
                guard let data, let candidate = print(data) else { return nil }
                var distance: Float = 0
                return (try? reference.computeDistance(&distance, to: candidate)) != nil ? distance : nil
            }
        }.value
    }
}
