import Foundation

// A downloaded or bundled catalog pack: products with cut-out images and one matching vector each
// (backend/catalog/build_catalog_pack.py). No pack is committed or bundled yet, because the
// product images' reuse terms are unreviewed.
nonisolated struct CatalogIndex: Sendable {
    struct Entry: Sendable {
        let product: CatalogProduct
        /// Local cut-out image inside the pack.
        let cutout: URL
    }

    let model: String
    let entries: [Entry]
    private let dimension: Int
    private let vectors: [Float]

    enum LoadError: Error {
        case unsupportedModel(String)
        case sizeMismatch
        case unsafeImagePath(String)
    }

    private struct File: Decodable {
        let model: String
        let dimension: Int
        let products: [RetailCatalogRecord]
    }

    init(directory: URL) throws {
        let file = try JSONDecoder().decode(File.self, from:
            Data(contentsOf: directory.appendingPathComponent("index.json")))
        guard file.model == CatalogEmbedding.model else { throw LoadError.unsupportedModel(file.model) }
        let bytes = try Data(contentsOf: directory.appendingPathComponent("vectors.bin"))
        guard file.dimension > 0, file.dimension <= 4096,
              bytes.count == file.products.count * file.dimension * MemoryLayout<Float>.size else {
            throw LoadError.sizeMismatch
        }
        model = file.model
        dimension = file.dimension
        vectors = bytes.withUnsafeBytes { Array($0.bindMemory(to: Float.self)) }
        entries = try file.products.map { record in
            let path = record.cutoutImageURL ?? ""
            guard path == "cutouts/\(record.id).png", !record.id.contains("/"), !record.id.contains("..") else {
                throw LoadError.unsafeImagePath(path)
            }
            let cutout = directory.appendingPathComponent(path)
            var product = record.catalogProduct
            product.cutoutImageURL = cutout
            return Entry(product: product, cutout: cutout)
        }
    }

    /// The most similar products to a unit-length query. The piece's category is searched first;
    /// other categories only fill in when it has fewer than `limit` products.
    func nearest(to query: [Float], category: ClothingCategory, limit: Int = 3) -> [Entry] {
        guard query.count == dimension else { return [] }
        let scored = entries.indices.map { index -> (index: Int, sameCategory: Bool, score: Float) in
            var score: Float = 0
            let start = index * dimension
            for offset in 0..<dimension { score += vectors[start + offset] * query[offset] }
            return (index, category == .other || entries[index].product.category == category, score)
        }
        return scored.sorted { lhs, rhs in
            lhs.sameCategory != rhs.sameCategory ? lhs.sameCategory : lhs.score > rhs.score
        }
        .prefix(limit).map { entries[$0.index] }
    }

    func search(_ query: String, limit: Int = 24) -> [Entry] {
        let terms = query.split(whereSeparator: \.isWhitespace).map(String.init)
        return Array(entries.filter { entry in
            terms.allSatisfy { term in
                [entry.product.title, entry.product.sourceName, entry.product.category.rawValue]
                    .contains { $0.localizedCaseInsensitiveContains(term) }
            }
        }.prefix(limit))
    }
}
