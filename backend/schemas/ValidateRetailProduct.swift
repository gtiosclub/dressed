import Foundation

@main
struct ValidateRetailProduct {
    static func main() throws {
        let data = try Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1]))
        let record = try JSONDecoder().decode(RetailProduct.self, from: data)
        let encoded = try JSONEncoder().encode(record)
        let again = try JSONDecoder().decode(RetailProduct.self, from: encoded)
        guard record.id == again.id, !record.photos.isEmpty,
              record.requiresReview, record.variants.allSatisfy({ !$0.selected }),
              record.offers.allSatisfy({ !$0.variantVerified }) else {
            throw NSError(domain: "RetailSchema", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "Invalid review contract"])
        }
        print("RetailProduct Codable round trip passed")
    }
}
