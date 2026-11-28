import Foundation

@main struct ValidateCatalogSeed {
    static func main() throws {
        let data = try Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1]))
        let records = try JSONDecoder().decode([RetailCatalogRecord].self, from: data)
        precondition(records.count == 80)
        precondition(Set(records.map(\.id)).count == 80)
        for category in ClothingCategory.allCases {
            precondition(records.filter { $0.category == category }.count == 10)
        }
        for record in records {
            let product = record.catalogProduct
            precondition(product.productURL.scheme == "https")
            precondition(product.imageURL?.scheme == "https")
            precondition(product.retailProduct?.photos.isEmpty == false)
            precondition(product.retailProduct?.description?.isEmpty == false)
            precondition(product.retailProduct?.requiresReview == true)
            precondition(product.retailProduct?.variants.allSatisfy { !$0.selected } == true)
            let decoded = try JSONDecoder().decode(CatalogProduct.self, from: JSONEncoder().encode(product))
            precondition(decoded.retailProduct?.id == record.retailProduct.id)
        }
        print("80 catalog records decode, retain rich product data, and cover all eight categories")
    }
}
