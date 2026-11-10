import XCTest
@testable import dressed

@MainActor
final class PrototypeOutfitStoreTests: XCTestCase {
    private var ownerId = ""
    private var items: [ClothingItem] = []

    override func setUp() {
        super.setUp()
        ownerId = "test-\(UUID().uuidString)"
        items = [
            TestSupport.item("shirt", .tops, owner: ownerId),
            TestSupport.item("tee", .tops, owner: ownerId),
            TestSupport.item("jeans", .pants, owner: ownerId),
            TestSupport.item("boots", .shoes, owner: ownerId)
        ]
    }

    override func tearDown() {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.removeItem(
            at: base.appendingPathComponent("PrototypeCloset").appendingPathComponent(ownerId)
        )
        super.tearDown()
    }

    @discardableResult
    private func save(_ store: PrototypeOutfitStore, _ name: String, _ ids: String...) throws -> Outfit {
        try store.save(
            id: UUID().uuidString, name: name,
            placements: ids.enumerated().map { layer, id in
                OutfitPlacement(itemId: id, centerX: 0.5, centerY: 0.5, width: 0.5, rotationDegrees: 0, layer: layer)
            },
            availableItems: items
        )
    }

    func testSavedOutfitPersistsAcrossReload() throws {
        let store = PrototypeOutfitStore(ownerId: ownerId)
        let saved = try save(store, "Look", "shirt", "jeans")

        let reloaded = PrototypeOutfitStore(ownerId: ownerId)
        XCTAssertEqual(reloaded.outfits.map(\.id), [saved.id])
        XCTAssertEqual(reloaded.outfits.first?.itemIds, ["shirt", "jeans"])
    }

    func testDeleteRemovesOnlyThatOutfitAndPersists() throws {
        let store = PrototypeOutfitStore(ownerId: ownerId)
        let first = try save(store, "One", "shirt")
        let second = try save(store, "Two", "tee", "boots")

        try store.delete(id: first.id)

        XCTAssertEqual(store.outfits.map(\.id), [second.id])
        XCTAssertEqual(PrototypeOutfitStore(ownerId: ownerId).outfits.map(\.id), [second.id])
    }

    func testDeletingAnUnknownIdChangesNothing() throws {
        let store = PrototypeOutfitStore(ownerId: ownerId)
        let saved = try save(store, "One", "shirt")

        XCTAssertNoThrow(try store.delete(id: "does-not-exist"))

        XCTAssertEqual(store.outfits.map(\.id), [saved.id])
    }

    func testDeletingFromAnEmptyStoreIsFine() {
        let store = PrototypeOutfitStore(ownerId: ownerId)
        XCTAssertNoThrow(try store.delete(id: "anything"))
        XCTAssertTrue(store.outfits.isEmpty)
    }

    func testMatchingIgnoresOrderAndNeedsTheExactSameItems() throws {
        let store = PrototypeOutfitStore(ownerId: ownerId)
        try save(store, "Look", "shirt", "jeans")

        XCTAssertEqual(store.outfits(matching: ["jeans", "shirt"]).count, 1)
        XCTAssertTrue(store.outfits(matching: ["shirt"]).isEmpty)
        XCTAssertTrue(store.outfits(matching: ["shirt", "jeans", "boots"]).isEmpty)
        XCTAssertTrue(store.outfits(matching: ["tee", "jeans"]).isEmpty)
    }

    func testEmptyItemSetMatchesNothing() throws {
        let store = PrototypeOutfitStore(ownerId: ownerId)
        try save(store, "Look", "shirt")
        XCTAssertTrue(store.outfits(matching: []).isEmpty)
        XCTAssertNoThrow(try store.deleteOutfits(matching: []))
        XCTAssertEqual(store.outfits.count, 1)
    }

    func testDeleteOutfitsMatchingRemovesDuplicatesAndLeavesOthers() throws {
        let store = PrototypeOutfitStore(ownerId: ownerId)
        try save(store, "Look", "shirt", "jeans")
        try save(store, "Look again", "jeans", "shirt")
        let other = try save(store, "Other", "tee", "jeans")

        try store.deleteOutfits(matching: ["shirt", "jeans"])

        XCTAssertEqual(store.outfits.map(\.id), [other.id])
        XCTAssertEqual(PrototypeOutfitStore(ownerId: ownerId).outfits.map(\.id), [other.id])
    }

    func testSaveThenUnsaveThenSaveAgainWorks() throws {
        let store = PrototypeOutfitStore(ownerId: ownerId)
        try save(store, "Look", "shirt")
        try store.deleteOutfits(matching: ["shirt"])
        XCTAssertTrue(store.outfits.isEmpty)

        try save(store, "Look", "shirt")
        XCTAssertEqual(store.outfits(matching: ["shirt"]).count, 1)
    }

    func testDeleteFailsWhenSavedOutfitsCouldNotBeLoaded() throws {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let directory = base.appendingPathComponent("PrototypeCloset").appendingPathComponent(ownerId)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data("not json".utf8).write(to: directory.appendingPathComponent("outfits.json"))

        let store = PrototypeOutfitStore(ownerId: ownerId)
        XCTAssertNotNil(store.error)

        XCTAssertThrowsError(try store.delete(id: "x")) { error in
            XCTAssertEqual(error as? PrototypeOutfitError, .unavailableStorage)
        }
    }

    func testSaveStillRejectsAnEmptyOutfit() {
        let store = PrototypeOutfitStore(ownerId: ownerId)
        XCTAssertThrowsError(
            try store.save(id: UUID().uuidString, name: "Empty", placements: [], availableItems: items)
        )
    }
}
