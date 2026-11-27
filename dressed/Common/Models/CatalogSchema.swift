import Foundation

// Public retailer offers are separate from owner-private ClothingItem records.
struct CatalogProduct: Codable, Identifiable {
    let id: String
    let sourceId: String
    let sourceName: String
    let externalId: String
    let title: String
    let productURL: URL
    let category: ClothingCategory
    let brand: String?
    let imageURL: URL?
    let priceCents: Int?
    let currency: String?
    let availability: String
    let status: String
    let lastCheckedAt: String
    var retailProduct: RetailProduct? = nil
    /// The product alone on a transparent background, when ingest made one. Preferred for display.
    var cutoutImageURL: URL? = nil

    var displayImageURL: URL? { cutoutImageURL ?? imageURL }
}

struct CatalogSearchResponse: Decodable {
    let products: [CatalogProduct]
    let total: Int
    let nextOffset: Int?
}
