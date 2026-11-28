import UIKit
import XCTest
@testable import dressed

final class CatalogIndexTests: XCTestCase {
    private var directory: URL!

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try FileManager.default.removeItem(at: directory)
    }

    private func writePack(_ items: [(id: String, category: String, vector: [Float])],
                           model: String = CatalogEmbedding.model,
                           imagePath: String? = nil) throws {
        let products = items.map { item -> [String: Any] in
            ["id": item.id, "category": item.category, "retailer": "Fixture", "title": "Item \(item.id)",
             "productURL": "https://shop.example/\(item.id)", "source": "fixture", "status": "needsReview",
             "cutoutImageURL": imagePath ?? "cutouts/\(item.id).png",
             "retailProduct": [
                "id": item.id, "schemaVersion": 1, "sourceURL": "https://shop.example/\(item.id)",
                "identifiers": [String: String](), "attributes": [String: String](), "photos": [Any](),
                "variants": [Any](), "variantOptions": [String: Any](), "offers": [Any](),
                "evidence": [String: Any](), "warnings": [String](), "observedAt": "2026-11-27T00:00:00Z",
                "requiresReview": true,
             ]]
        }
        let index: [String: Any] = ["model": model, "dimension": 2, "products": products]
        try JSONSerialization.data(withJSONObject: index)
            .write(to: directory.appendingPathComponent("index.json"))
        let vectors = items.flatMap(\.vector)
        try vectors.withUnsafeBufferPointer { Data(buffer: $0) }
            .write(to: directory.appendingPathComponent("vectors.bin"))
    }

    func testNearestSearchesCategoryFirstThenFillsFromOthers() throws {
        try writePack([("far", "tops", [0, 1]), ("shoe", "shoes", [1, 0]),
                       ("near", "tops", [0.9, 0.436]), ("hat", "accessories", [0.8, 0.6])])
        let index = try CatalogIndex(directory: directory)
        XCTAssertEqual(index.nearest(to: [1, 0], category: .tops).map(\.product.id), ["near", "far", "shoe"])
        XCTAssertEqual(index.nearest(to: [1, 0], category: .other).first?.product.id, "shoe")
        XCTAssertTrue(index.nearest(to: [1, 0, 0], category: .tops).isEmpty, "Wrong vector size")
        XCTAssertEqual(index.search("item hat").map(\.product.id), ["hat"])
        let product = try XCTUnwrap(index.entries.first?.product)
        XCTAssertEqual(product.displayImageURL, directory.appendingPathComponent("cutouts/far.png"))
    }

    func testRejectsOtherModelsBadSizesAndEscapingImagePaths() throws {
        try writePack([("a", "tops", [1, 0])], model: "other-model")
        XCTAssertThrowsError(try CatalogIndex(directory: directory))
        try writePack([("a", "tops", [1])])
        XCTAssertThrowsError(try CatalogIndex(directory: directory))
        try writePack([("a", "tops", [1, 0])], imagePath: "../secret.png")
        XCTAssertThrowsError(try CatalogIndex(directory: directory))
    }

    func testHostedRecordsOnlyUseSecureCutoutURLs() throws {
        try writePack([("a", "tops", [1, 0])])
        let data = try Data(contentsOf: directory.appendingPathComponent("index.json"))
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        var record = try XCTUnwrap((json["products"] as? [[String: Any]])?.first)
        for (value, expected) in [("https://img.example/a.png", "https://img.example/a.png"),
                                  ("http://img.example/a.png", nil), ("cutouts/a.png", nil)] {
            record["cutoutImageURL"] = value
            let decoded = try JSONDecoder().decode(
                RetailCatalogRecord.self, from: JSONSerialization.data(withJSONObject: record))
            XCTAssertEqual(decoded.catalogProduct.cutoutImageURL?.absoluteString, expected)
        }
    }

    /// Canonical preparation hides the background, so only the cutout is compared.
    func testCanonicalImageCentersTheCutoutOnWhite() throws {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let tall = UIGraphicsImageRenderer(size: CGSize(width: 20, height: 80), format: format).image { context in
            UIColor.black.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 20, height: 80))
        }
        let canonical = try XCTUnwrap(CatalogEmbedding.canonicalImage(XCTUnwrap(tall.cgImage), side: 100))
        XCTAssertEqual(canonical.width, 100)
        XCTAssertEqual(canonical.height, 100)
        XCTAssertEqual(CatalogEmbedding.normalized([3, 4]), [0.6, 0.8])
        XCTAssertNil(CatalogEmbedding.normalized([0, 0]))
    }
}
