import XCTest
@testable import dressed

@MainActor
final class OutfitStudioModelTests: XCTestCase {
    private let shirt = TestSupport.item("shirt", .tops)
    private let tee = TestSupport.item("tee", .tops)
    private let jeans = TestSupport.item("jeans", .pants)
    private let boots = TestSupport.item("boots", .shoes)

    private func ids(_ model: OutfitStudioModel) -> [ClothingCategory: String] {
        model.worn.mapValues(\.id)
    }

    func testFreshModelHasNothingToUndoOrRedo() {
        let model = OutfitStudioModel()
        XCTAssertFalse(model.canUndo)
        XCTAssertFalse(model.canRedo)
        model.undo()
        model.redo()
        XCTAssertTrue(model.worn.isEmpty)
    }

    func testEachWornChangeIsOneUndoStep() {
        let model = OutfitStudioModel()
        model.toggle(shirt)            // put on
        model.worn[.pants] = jeans     // put on
        model.worn[.tops] = tee        // replace in the same category
        model.worn[.pants] = nil       // take off
        XCTAssertEqual(ids(model), [.tops: "tee"])

        model.undo()
        XCTAssertEqual(ids(model), [.tops: "tee", .pants: "jeans"])
        model.undo()
        XCTAssertEqual(ids(model), [.tops: "shirt", .pants: "jeans"])
        model.undo()
        XCTAssertEqual(ids(model), [.tops: "shirt"])
        model.undo()
        XCTAssertTrue(model.worn.isEmpty)
        XCTAssertFalse(model.canUndo)
        XCTAssertTrue(model.canRedo)
    }

    func testRedoReplaysUndoneChanges() {
        let model = OutfitStudioModel()
        model.worn[.tops] = shirt
        model.worn[.pants] = jeans
        model.undo()
        model.undo()

        model.redo()
        XCTAssertEqual(ids(model), [.tops: "shirt"])
        model.redo()
        XCTAssertEqual(ids(model), [.tops: "shirt", .pants: "jeans"])
        XCTAssertFalse(model.canRedo)
        XCTAssertTrue(model.canUndo)
    }

    func testNewChangeAfterUndoClearsRedo() {
        let model = OutfitStudioModel()
        model.worn[.tops] = shirt
        model.worn[.pants] = jeans
        model.undo()
        XCTAssertTrue(model.canRedo)

        model.worn[.shoes] = boots

        XCTAssertFalse(model.canRedo)
        model.redo()
        XCTAssertEqual(ids(model), [.tops: "shirt", .shoes: "boots"])
    }

    func testUndoAndRedoDoNotCreateHistoryEntries() {
        let model = OutfitStudioModel()
        model.worn[.tops] = shirt
        model.undo()
        model.redo()
        model.undo()
        // One real change, so exactly one step back to empty and one forward.
        XCTAssertFalse(model.canUndo)
        XCTAssertTrue(model.canRedo)
        model.redo()
        XCTAssertTrue(model.canUndo)
        XCTAssertFalse(model.canRedo)
    }

    func testWearingASavedOutfitIsOneStep() {
        let model = OutfitStudioModel()
        model.worn[.tops] = shirt

        model.worn = [.tops: tee, .pants: jeans, .shoes: boots]   // what tapping a saved fit does
        XCTAssertEqual(model.worn.count, 3)

        model.undo()
        XCTAssertEqual(ids(model), [.tops: "shirt"])
    }

    func testPuttingOnWhatIsAlreadyWornAddsNoStep() {
        let model = OutfitStudioModel()
        model.worn[.tops] = shirt
        model.worn[.tops] = shirt
        model.undo()
        XCTAssertTrue(model.worn.isEmpty)
        XCTAssertFalse(model.canUndo)
    }

    func testLookAndZoomAreNotPartOfHistory() {
        let model = OutfitStudioModel()
        model.worn[.tops] = shirt
        model.look[.gender] = 1
        model.zoom = 1.5

        model.undo()

        XCTAssertTrue(model.worn.isEmpty)
        XCTAssertEqual(model.look[.gender], 1)
        XCTAssertEqual(model.zoom, 1.5)
    }

    func testUndoLeavesOutPiecesNoLongerInTheCloset() {
        let model = OutfitStudioModel()
        model.worn[.tops] = shirt
        model.worn[.pants] = jeans
        model.worn[.shoes] = boots
        model.worn[.shoes] = nil   // current: shirt + jeans

        // The boots were deleted from the closet after being worn.
        model.undo(available: ["shirt", "jeans"])

        // The step that only brought the boots back is skipped, so undo moves on to the previous one.
        XCTAssertEqual(ids(model), [.tops: "shirt"])
        XCTAssertTrue(model.canUndo)
        XCTAssertTrue(model.canRedo)
    }

    func testRestoredPiecesThatStillExistAreKept() {
        let model = OutfitStudioModel()
        model.worn[.tops] = shirt
        model.worn[.pants] = jeans
        model.worn[.pants] = nil

        model.undo(available: ["shirt", "jeans"])

        XCTAssertEqual(ids(model), [.tops: "shirt", .pants: "jeans"])
    }

    func testSnapshotEqualityIsByItemId() {
        let renamed = ClothingItem(
            id: "shirt", ownerId: "owner", name: "Renamed", category: .tops,
            imagePath: "other.png", createdAt: Date()
        )
        XCTAssertEqual(OutfitSnapshot([.tops: shirt]), OutfitSnapshot([.tops: renamed]))
        XCTAssertNotEqual(OutfitSnapshot([.tops: shirt]), OutfitSnapshot([.tops: tee]))
        XCTAssertNotEqual(OutfitSnapshot([.tops: shirt]), OutfitSnapshot())
    }
}
