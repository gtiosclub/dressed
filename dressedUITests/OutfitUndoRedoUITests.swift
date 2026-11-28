import XCTest

/// Undo/redo of clothing selections on the Avatar tab full-screen try-on (#240).
/// These launch with `-mockSignedIn` and the debug closet fixture, so they do not exercise real sign-in.
final class OutfitUndoRedoUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-mockSignedIn", "-skipDemoCloset", "-seedClosetFixture"]
        app.launch()
        if app.buttons["sharedImport.close"].waitForExistence(timeout: 2) {
            app.buttons["sharedImport.close"].tap()
        }
        app.buttons["tab.avatar"].tap()
        XCTAssertTrue(app.otherElements["tryon.canvas"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["studio.undo"].waitForExistence(timeout: 10))
    }

    private var undo: XCUIElement { app.buttons["studio.undo"] }
    private var redo: XCUIElement { app.buttons["studio.redo"] }

    private func wear(_ name: String, zone: String) {
        app.buttons["Change \(zone)"].tap()
        let card = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", name)).firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 5), "\(name) should be in the picker")
        card.tap()
        app.buttons["Done"].tap()
    }

    private func zoneHasWornPiece(_ zone: String) -> Bool {
        app.buttons["Change \(zone)"].tap()
        defer { app.buttons["Done"].tap() }
        return app.buttons["Take off"].waitForExistence(timeout: 2)
    }

    func testUndoAndRedoStartDisabled() {
        XCTAssertFalse(undo.isEnabled)
        XCTAssertFalse(redo.isEnabled)
    }

    func testUndoAndRedoWalkThroughClothingChanges() {
        wear("Blue Tee", zone: "Top")
        XCTAssertTrue(undo.isEnabled)
        XCTAssertFalse(redo.isEnabled)

        wear("Black Jeans", zone: "Bottom")
        XCTAssertTrue(undo.isEnabled)

        undo.tap()
        XCTAssertFalse(zoneHasWornPiece("Bottom"))
        XCTAssertTrue(zoneHasWornPiece("Top"))
        XCTAssertTrue(redo.isEnabled)

        undo.tap()
        XCTAssertFalse(zoneHasWornPiece("Top"))
        XCTAssertFalse(undo.isEnabled)
        XCTAssertTrue(redo.isEnabled)

        redo.tap()
        XCTAssertTrue(zoneHasWornPiece("Top"))
        redo.tap()
        XCTAssertTrue(zoneHasWornPiece("Bottom"))
        XCTAssertFalse(redo.isEnabled)
        XCTAssertTrue(undo.isEnabled)
    }

    func testNewChangeAfterUndoClearsRedo() {
        wear("Blue Tee", zone: "Top")
        wear("Black Jeans", zone: "Bottom")
        undo.tap()
        XCTAssertTrue(redo.isEnabled)

        wear("Red Shirt", zone: "Top")
        XCTAssertFalse(redo.isEnabled)

        undo.tap()
        XCTAssertTrue(zoneHasWornPiece("Top"))
        XCTAssertFalse(zoneHasWornPiece("Bottom"))
    }

    func testRemovingAWornPieceCanBeUndone() {
        wear("Blue Tee", zone: "Top")
        XCTAssertTrue(zoneHasWornPiece("Top"))
        app.buttons["Change Top"].tap()
        app.buttons["Take off"].tap()
        app.buttons["Done"].tap()
        XCTAssertFalse(zoneHasWornPiece("Top"))

        undo.tap()
        XCTAssertTrue(zoneHasWornPiece("Top"))
    }
}