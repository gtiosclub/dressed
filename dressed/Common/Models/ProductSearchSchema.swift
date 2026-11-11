import Foundation

/// Transient search hits, not verified catalog products or owned clothing.
struct ProductSearchResponse: Decodable {
    let requestId: String
    let provider: String
    let searchedAt: String
    let matches: [ProductSearchMatch]
}

struct ProductSearchMatch: Decodable, Identifiable {
    let id: String
    let title: String
    let source: String
    let productURL: URL
    let imageURL: URL?
    // Preserve the source's display price: "$" alone does not establish USD.
    let price: String?
}
