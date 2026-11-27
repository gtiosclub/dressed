import UIKit
import XCTest
@testable import dressed

/// Counts calls so tests can tell a cache hit from a generation.
private final class CountingGenerator: AvatarImageGenerating, @unchecked Sendable {
    var calls = 0
    var lastRequest: AvatarGenerationRequest?
    var error: AvatarGenerationError?
    var delay: Duration = .zero
    private let mock = MockAvatarImageGenerator(delay: .zero)

    func generate(_ request: AvatarGenerationRequest) async throws -> Data {
        calls += 1
        lastRequest = request
        try await Task.sleep(for: delay)
        if let error { throw error }
        return try await mock.generate(request)
    }
}

@MainActor
final class AvatarTryOnModelTests: XCTestCase {
    private var directory: URL!
    private let tee = TestSupport.item("tee", .tops)
    private let jeans = TestSupport.item("jeans", .pants)
    private let jacket = TestSupport.item("jacket", .outerwear)

    override func setUp() {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: directory)
    }

    private func photo(_ white: CGFloat = 0.5) -> UIImage {
        UIGraphicsImageRenderer(size: CGSize(width: 40, height: 60)).image { context in
            UIColor(white: white, alpha: 1).setFill()
            context.fill(CGRect(x: 0, y: 0, width: 40, height: 60))
        }
    }

    private func model(_ generator: CountingGenerator, reference: Bool = true) async -> AvatarTryOnModel {
        let model = AvatarTryOnModel(ownerId: "owner", generator: generator, baseDirectory: directory)
        if reference { await model.saveReference(photo(0.2).jpegData(compressionQuality: 0.9)!) }
        return model
    }

    private func waitForPhase(_ model: AvatarTryOnModel, where done: (AvatarTryOnModel.Phase) -> Bool) async {
        for _ in 0..<200 where !done(model.phase) {
            try? await Task.sleep(for: .milliseconds(10))
        }
    }

    func testPiecesAreOrderedByLayerAndCapped() {
        let worn: [ClothingCategory: ClothingItem] = [.outerwear: jacket, .tops: tee, .pants: jeans]
        XCTAssertEqual(AvatarTryOnModel.ordered(worn).map(\.id), ["jeans", "tee", "jacket"])
        XCTAssertEqual(AvatarTryOnModel.label(for: jacket), "Item jacket (jacket, worn over the top)")
    }

    func testCacheKeyIgnoresOrderButNotContent() {
        let a = Data("a".utf8), b = Data("b".utf8), reference = Data("me".utf8)
        let key = AvatarMediaStore.cacheKey(reference: reference, pieces: [("1", a), ("2", b)])
        XCTAssertEqual(key, AvatarMediaStore.cacheKey(reference: reference, pieces: [("2", b), ("1", a)]))
        XCTAssertNotEqual(key, AvatarMediaStore.cacheKey(reference: reference, pieces: [("1", b), ("2", a)]))
        XCTAssertNotEqual(key, AvatarMediaStore.cacheKey(reference: Data("you".utf8), pieces: [("1", a), ("2", b)]))
    }

    func testGeneratesOnceThenUsesCache() async {
        let generator = CountingGenerator()
        let model = await model(generator)
        let worn: [ClothingCategory: ClothingItem] = [.tops: tee, .pants: jeans]

        model.generate(worn: worn, pieceImage: { _ in self.photo() })
        await waitForPhase(model) { $0 == .ready }
        XCTAssertEqual(model.phase, .ready)
        XCTAssertNotNil(model.lookImage)
        XCTAssertEqual(generator.calls, 1)
        XCTAssertEqual(generator.lastRequest?.pieces.map(\.label), ["Item jeans (pants)", "Item tee (top)"])
        XCTAssertTrue(model.isShowing(worn))

        model.generate(worn: worn, pieceImage: { _ in self.photo() })
        await waitForPhase(model) { $0 == .ready }
        try? await Task.sleep(for: .milliseconds(50))
        XCTAssertEqual(generator.calls, 1, "the same outfit should come from the cache")

        model.retry(force: true)
        await waitForPhase(model) { $0 == .generating }
        await waitForPhase(model) { $0 == .ready }
        XCTAssertEqual(generator.calls, 2, "Generate again bypasses the cache")
    }

    func testWithoutReferencePhotoWaitsThenResumesWhenPhotoIsAdded() async {
        let generator = CountingGenerator()
        let model = await model(generator, reference: false)
        model.generate(worn: [.tops: tee], pieceImage: { _ in self.photo() })
        XCTAssertEqual(model.phase, .idle)
        XCTAssertFalse(model.hasReference)
        XCTAssertEqual(generator.calls, 0)

        await model.saveReference(photo(0.2).jpegData(compressionQuality: 0.9)!)
        await waitForPhase(model) { $0 == .ready }
        XCTAssertEqual(generator.calls, 1)
    }

    func testFailureShowsMessageAndPiecesWithoutPhotosFail() async {
        let generator = CountingGenerator()
        generator.error = .contentPolicy
        let model = await model(generator)
        model.generate(worn: [.tops: tee], pieceImage: { _ in self.photo() })
        await waitForPhase(model) { if case .failed = $0 { true } else { false } }
        XCTAssertEqual(model.phase, .failed(AvatarGenerationError.contentPolicy.localizedDescription))

        model.generate(worn: [.tops: tee], pieceImage: { _ in nil })
        await waitForPhase(model) { $0 == .failed("These pieces have no photos to try on.") }
        XCTAssertEqual(model.phase, .failed("These pieces have no photos to try on."))
    }

    func testCancelStopsGenerationWithoutError() async {
        let generator = CountingGenerator()
        generator.delay = .seconds(5)
        let model = await model(generator)
        model.generate(worn: [.tops: tee], pieceImage: { _ in self.photo() })
        await waitForPhase(model) { $0 == .generating }
        model.cancel()
        try? await Task.sleep(for: .milliseconds(100))
        XCTAssertEqual(model.phase, .idle)
        XCTAssertNil(model.lookImage)
    }

    func testRemovingPhotoClearsReferenceAndLooks() async {
        let generator = CountingGenerator()
        let model = await model(generator)
        model.generate(worn: [.tops: tee], pieceImage: { _ in self.photo() })
        await waitForPhase(model) { $0 == .ready }

        model.removeReference()
        XCTAssertFalse(model.hasReference)
        XCTAssertNil(model.lookImage)
        let reopened = AvatarTryOnModel(ownerId: "owner", generator: generator, baseDirectory: directory)
        XCTAssertFalse(reopened.hasReference)
        XCTAssertFalse(FileManager.default.fileExists(
            atPath: directory.appendingPathComponent("owner/avatar-looks").path))
    }
}

private struct StubCatalog: CatalogSearching {
    let products: [CatalogProduct]
    func search(query: String, category: ClothingCategory?) async throws -> CatalogSearchResponse {
        CatalogSearchResponse(products: products, total: products.count, nextOffset: nil)
    }
}

@MainActor
final class AvatarCatalogStoreTests: XCTestCase {
    private func product(_ id: String, _ title: String, _ category: ClothingCategory, image: String?) -> CatalogProduct {
        CatalogProduct(id: id, sourceId: "seed", sourceName: "Seed", externalId: id, title: title,
                       productURL: URL(string: "https://shop.example/\(id)")!, category: category, brand: nil,
                       imageURL: image.flatMap(URL.init(string:)), priceCents: nil, currency: nil,
                       availability: "in_stock", status: "needsReview", lastCheckedAt: "")
    }

    func testKeepsHTTPSPhotosSortsByCategoryAndPrefixesIds() async {
        let store = AvatarCatalogStore(ownerId: "owner", service: StubCatalog(products: [
            product("p1", "Wide Jeans", .pants, image: "https://cdn.example/p1.jpg"),
            product("t2", "B Tee", .tops, image: "https://cdn.example/t2.jpg"),
            product("t1", "A Tee", .tops, image: "https://cdn.example/t1.jpg"),
            product("x", "No Photo", .tops, image: nil),
            product("h", "Plain HTTP", .tops, image: "http://cdn.example/h.jpg")
        ]))
        await store.load()
        XCTAssertEqual(store.state, .loaded)
        XCTAssertEqual(store.products.map(\.id), ["t1", "t2", "p1"])
        let item = store.item(for: store.products[0])
        XCTAssertEqual(item.id, "catalog-t1")
        XCTAssertEqual(item.ownerId, "owner")
        XCTAssertEqual(item.category, .tops)
        XCTAssertNil(store.image(for: item.id))
    }
}
