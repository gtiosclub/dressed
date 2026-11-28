import Foundation

/// Reviewable retailer data, separate from owned ClothingItem and private Wishlist records.
/// Missing fields remain nil; a resolved URL does not verify a product or variant.
struct RetailProduct: Codable, Identifiable {
    let id: String
    let schemaVersion: Int
    let sourceURL: URL?
    let productURL: URL?
    let title: String?
    let brand: String?
    let description: String?
    let sourceCategory: String?
    let identifiers: [String: String]
    let attributes: [String: String]
    let photos: [RetailProductPhoto]
    let variants: [RetailProductVariant]
    let variantOptions: [String: [String]]
    let offers: [RetailProductOffer]
    let evidence: [String: RetailFieldEvidence]
    let warnings: [String]
    let observedAt: String
    let requiresReview: Bool
}

struct RetailProductPhoto: Codable {
    let url: URL
    let sourceURL: URL?
    let role: String
    let reuseStatus: String
}

struct RetailFieldEvidence: Codable {
    let method: String
    let sourceURL: URL?
}

struct RetailProductVariant: Codable {
    let sourceId: String?
    let title: String?
    let productURL: URL?
    let attributes: [String: String]
    let imageURLs: [URL]
    let selected: Bool
}

struct RetailProductOffer: Codable {
    let merchant: String?
    let productURL: URL?
    let redirectURL: URL?
    let priceText: String?
    let amount: String?
    let lowPrice: String?
    let highPrice: String?
    let currency: String?
    let availability: String
    let condition: String?
    let observedAt: String
    let variantVerified: Bool
}
