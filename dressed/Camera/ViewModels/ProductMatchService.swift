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

/// Turns a piece's cutout into the vector the catalog index was built with.
protocol PieceEmbedding: Sendable {
    func vector(for cutout: Data) async throws -> [Float]
}

/// Apple's feature print, computed on the device with the same preparation as ingest.
struct OnDevicePieceEmbedding: PieceEmbedding {
    func vector(for cutout: Data) async throws -> [Float] {
        try await Task.detached(priority: .userInitiated) {
            guard let image = GarmentImage.upright(cutout),
                  let canonical = CatalogEmbedding.canonicalImage(image).flatMap(GarmentImage.png) else {
                throw PrototypeImportError.invalidImage
            }
            let request = try VisionRequestRunner.perform({ CatalogEmbedding.request() }, on: canonical)
            guard let vector = request.results?.first.flatMap(CatalogEmbedding.vector(from:)) else {
                throw PrototypeImportError.invalidImage
            }
            return vector
        }.value
    }
}

#if DEBUG && targetEnvironment(simulator)
/// The simulator cannot compute a feature print, so the local Mac bridge does
/// (backend/recognition/local_service.py --apple-vision). Loopback only.
struct MacBridgePieceEmbedding: PieceEmbedding {
    func vector(for cutout: Data) async throws -> [Float] {
        var request = URLRequest(url: URL(string: "http://127.0.0.1:8765/embed")!)
        request.httpMethod = "POST"
        request.httpBody = cutout
        request.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30
        let (data, response) = try await URLSession.shared.data(for: request)
        struct Reply: Decodable {
            let model: String
            let vector: [Float]
        }
        guard (response as? HTTPURLResponse)?.statusCode == 200,
              let reply = try? JSONDecoder().decode(Reply.self, from: data),
              reply.model == CatalogEmbedding.model,
              let vector = CatalogEmbedding.normalized(reply.vector) else {
            throw LocalRecognitionError.invalidResponse
        }
        return vector
    }
}
#endif

/// Matches pieces against a catalog pack's precomputed vectors, so every product is compared
/// without downloading any image. If the piece cannot be embedded it returns no matches
/// rather than unrelated products.
@MainActor
final class CatalogIndexMatcher: ProductMatching {
    private let index: CatalogIndex
    private let embedding: any PieceEmbedding

    init(index: CatalogIndex, embedding: any PieceEmbedding) {
        self.index = index
        self.embedding = embedding
    }

    /// The pack bundled as `CatalogPack`, or in Debug the one at `-catalogPackPath <folder>`.
    static let configured: CatalogIndexMatcher? = {
        var directory = Bundle.main.url(forResource: "CatalogPack", withExtension: nil)
        #if DEBUG
        if let path = UserDefaults.standard.string(forKey: "catalogPackPath") {
            directory = URL(fileURLWithPath: path, isDirectory: true)
        }
        #endif
        guard let directory else { return nil }
        do {
            #if DEBUG && targetEnvironment(simulator)
            let embedding: any PieceEmbedding = MacBridgePieceEmbedding()
            #else
            let embedding: any PieceEmbedding = OnDevicePieceEmbedding()
            #endif
            return CatalogIndexMatcher(index: try CatalogIndex(directory: directory), embedding: embedding)
        } catch {
            print("Catalog pack could not be loaded: \(error)")
            return nil
        }
    }()

    func matches(for crop: Data, category: ClothingCategory) async throws -> [ProductMatch] {
        let query = try await embedding.vector(for: crop)
        try Task.checkCancellation()
        return index.nearest(to: query, category: category).map(Self.match)
    }

    func search(_ query: String) async throws -> [ProductMatch] {
        index.search(query).map(Self.match)
    }

    private static func match(_ entry: CatalogIndex.Entry) -> ProductMatch {
        ProductMatch(product: entry.product, image: UIImage(contentsOfFile: entry.cutout.path))
    }
}

/// Used when there is no catalog pack. Ranks the signed-in catalog by on-device Vision feature-print distance to the piece's crop.
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
        let urls = compared.map(\.displayImageURL)

        // Download what is not cached yet, concurrently.
        let missing = urls.compactMap { $0 }.filter { imageCache[$0] == nil }
        let downloaded = await Self.download(Array(Set(missing)))
        for (url, data) in downloaded { imageCache[url] = data }
        try Task.checkCancellation()

        let imageData = urls.map { $0.flatMap { imageCache[$0] } }
        let distances = await Self.rank(crop: crop, images: imageData)
        try Task.checkCancellation()

        // If Vision could compare nothing, catalog order would only look like a match.
        if urls.contains(where: { $0 != nil }) && distances.allSatisfy({ $0 == nil }) { return [] }

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
        let missing = products.compactMap(\.displayImageURL).filter { imageCache[$0] == nil }
        for (url, data) in await Self.download(Array(Set(missing))) { imageCache[url] = data }
        try Task.checkCancellation()
        return products.map { product in
            ProductMatch(product: product,
                         image: product.displayImageURL.flatMap { imageCache[$0] }.flatMap(UIImage.init(data:)))
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
        #if DEBUG && targetEnvironment(simulator)
        return await bridgeRank(crop: crop, images: images)
        #else
        return await Task.detached(priority: .userInitiated) {
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
        #endif
    }

    #if DEBUG && targetEnvironment(simulator)
    /// The simulator cannot run Vision's feature print, so the local Mac bridge compares the images.
    nonisolated private static func bridgeRank(crop: Data, images: [Data?]) async -> [Float?] {
        let bridge = MacBridgePieceEmbedding()
        guard images.contains(where: { $0 != nil }),
              let reference = try? await bridge.vector(for: crop) else { return images.map { _ in nil } }
        var distances: [Float?] = []
        for data in images {
            // A smaller copy stays under the bridge's upload limit.
            guard !Task.isCancelled,
                  let image = data.flatMap({ GarmentImage.upright($0, maximumSide: 600) }),
                  let small = UIImage(cgImage: image).jpegData(compressionQuality: 0.85),
                  let vector = try? await bridge.vector(for: small), vector.count == reference.count else {
                distances.append(nil)
                continue
            }
            distances.append(1 - zip(reference, vector).reduce(0) { $0 + $1.0 * $1.1 })
        }
        return distances
    }
    #endif
}
