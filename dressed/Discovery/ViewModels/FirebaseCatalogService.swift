import Foundation
import FirebaseFirestore

/// Read-only, signed-in access to the curated retailer seed. Private closet records are separate.
struct FirebaseCatalogService: CatalogSearching {
    func search(query: String, category: ClothingCategory?) async throws -> CatalogSearchResponse {
        try Task.checkCancellation()
        let snapshot = try await Firestore.firestore().collection("catalogProducts")
            .limit(to: 200).getDocuments()
        try Task.checkCancellation()
        let terms = query.split(whereSeparator: \.isWhitespace).map(String.init)
        let products = try snapshot.documents.map { document in
            try document.data(as: RetailCatalogRecord.self).catalogProduct
        }.filter { product in
            (category == nil || category == product.category) && terms.allSatisfy { term in
                [product.title, product.sourceName, product.brand ?? "", product.category.rawValue]
                    .contains { $0.localizedCaseInsensitiveContains(term) }
            }
        }.sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
        return CatalogSearchResponse(products: products, total: products.count, nextOffset: nil)
    }
}

