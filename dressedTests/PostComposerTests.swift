import XCTest
import UIKit
@testable import dressed

@MainActor
final class PostComposerTests: XCTestCase {
    private struct Source: PostCompositionSource {
        let item = TestSupport.item("piece_1", .tops)
        func load() throws -> (items: [ClothingItem], outfits: [Outfit]) { ([item], []) }
        func image(for item: ClothingItem) throws -> UIImage {
            UIGraphicsImageRenderer(size: CGSize(width: 80, height: 80)).image { context in
                UIColor.blue.setFill(); context.fill(CGRect(x: 0, y: 0, width: 80, height: 80))
            }
        }
    }

    func testRequiresPhotoAndItemsAndRetainsFrozenDraftAfterFailure() async throws {
        let source = Source()
        let model = PostComposerModel(source: source)
        model.load()
        XCTAssertFalse(model.canSubmit)
        try model.selectPhoto(source.image(for: source.item))
        XCTAssertFalse(model.canSubmit)
        model.toggle(source.item)
        model.caption = "First caption"
        XCTAssertTrue(model.canSubmit)
        var attempts: [PostPublicationDraft] = []
        await model.submit { draft in
            attempts.append(draft)
            throw NSError(domain: "network", code: 1)
        }
        XCTAssertNotNil(model.error)
        XCTAssertTrue(model.isLocked)
        model.caption = "An edit cannot alter a pending retry"
        model.toggle(source.item)
        await model.submit { attempts.append($0) }
        XCTAssertEqual(attempts.count, 2)
        XCTAssertEqual(attempts[0].id, attempts[1].id)
        XCTAssertEqual(attempts[1].caption, "First caption")
        XCTAssertEqual(attempts[1].items.first?.category, .tops)
        XCTAssertEqual(attempts[0].photo, attempts[1].photo)
        XCTAssertEqual(model.selectedIds, ["piece_1"])
    }

    func testSavedOutfitWithMissingPieceDoesNotSilentlyPublishPartialOutfit() {
        let source = Source()
        let model = PostComposerModel(source: source)
        model.load()
        let outfit = Outfit(id: "outfit", schemaVersion: 1, ownerId: "owner", name: "Missing", placementSchemaVersion: 1,
                            placements: [OutfitPlacement(itemId: "gone", centerX: 0.5, centerY: 0.5, width: 0.5, rotationDegrees: 0, layer: 0)],
                            createdAt: .now, updatedAt: .now)
        model.select(outfit)
        XCTAssertTrue(model.selectedIds.isEmpty)
        XCTAssertNotNil(model.error)
    }
}
