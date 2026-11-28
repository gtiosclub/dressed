import XCTest
@testable import dressed

@MainActor
final class OutfitStoreTests: XCTestCase {
    private let owner = "outfit-store-test-\(UUID().uuidString)"

    override func tearDown() async throws {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.removeItem(at: base.appendingPathComponent("PrototypeCloset/\(owner)"))
    }

    private func save(_ name: String, in store: PrototypeOutfitStore) throws -> Outfit {
        let item = TestSupport.item("shirt", .tops, owner: owner)
        let placement = OutfitPlacement(itemId: item.id, centerX: 0.5, centerY: 0.5,
                                        width: 0.4, rotationDegrees: 0, layer: 0)
        return try store.save(id: UUID().uuidString, name: name, placements: [placement], availableItems: [item])
    }

    func testDeleteRemovesOnlyThatOutfitAndPersists() throws {
        let store = PrototypeOutfitStore(ownerId: owner)
        let first = try save("First", in: store)
        let second = try save("Second", in: store)
        try store.delete(id: first.id)
        XCTAssertEqual(store.outfits.map(\.id), [second.id])
        XCTAssertEqual(PrototypeOutfitStore(ownerId: owner).outfits.map(\.id), [second.id])
        XCTAssertNoThrow(try store.delete(id: first.id), "Deleting again is harmless")
    }

    /// The import review saves through its own store while the closet's store is already loaded.
    func testDeleteKeepsOutfitsSavedByAnotherStore() throws {
        let closetStore = PrototypeOutfitStore(ownerId: owner)
        let old = try save("Old", in: closetStore)
        let imported = try save("Imported", in: PrototypeOutfitStore(ownerId: owner))
        try closetStore.delete(id: old.id)
        XCTAssertEqual(PrototypeOutfitStore(ownerId: owner).outfits.map(\.id), [imported.id])
    }
}
