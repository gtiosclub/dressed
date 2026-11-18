import Foundation

/// The catalog envelope matches the backend seed; all richer source data stays in RetailProduct.
struct RetailCatalogRecord: Decodable {
    let id: String
    let category: ClothingCategory
    let retailer: String
    let productURL: URL
    let title: String
    let imageURL: URL?
    let source: String
    let status: String
    let retailProduct: RetailProduct

    var catalogProduct: CatalogProduct {
        var result = CatalogProduct(
            id: id, sourceId: source, sourceName: retailer,
            externalId: retailProduct.identifiers["shopifyProductId"] ?? id,
            title: title, productURL: productURL, category: category, brand: retailProduct.brand,
            imageURL: imageURL, priceCents: nil, currency: nil,
            availability: retailProduct.offers.contains { $0.availability == "inStock" } ? "inStock" : "unknown",
            status: status, lastCheckedAt: retailProduct.observedAt
        )
        result.retailProduct = retailProduct
        return result
    }
}
