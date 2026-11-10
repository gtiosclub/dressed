import XCTest

/// Undo/redo of clothing selections in Avatar Studio → Try On (#240).
/// These launch with `-mockSignedIn` and the debug closet fixture, so they do not exercise real sign-in.
final class OutfitUndoRedoUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-mockSignedIn", "-seedClosetFixture"]
        app.launch()
        if app.buttons["Later"].waitForExistence(timeout: 2) {
            app.buttons["Later"].tap()
        }
        app.tabBars.buttons["Avatar"].tap()
        XCTAssertTrue(app.navigationBars["Avatar Studio"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["studio.undo"].waitForExistence(timeout: 10))
    }

    private var undo: XCUIElement { app.buttons["studio.undo"] }
    private var redo: XCUIElement { app.buttons["studio.redo"] }

    private func chip(_ category: String) -> XCUIElement { app.buttons["studio.worn.\(category)"] }

    /// Picks a category chip, then taps the named piece in the tray.
    private func wear(_ name: String, in category: String) {
        app.buttons[category].firstMatch.tap()
        let card = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", name)).firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 5), "\(name) should be in the tray")
        card.tap()
    }

    func testUndoAndRedoStartDisabled() {
        XCTAssertFalse(undo.isEnabled)
        XCTAssertFalse(redo.isEnabled)
    }

    func testUndoAndRedoWalkThroughClothingChanges() {
        wear("Blue Tee", in: "tops")
        XCTAssertTrue(chip("tops").waitForExistence(timeout: 5))
        XCTAssertTrue(undo.isEnabled)
        XCTAssertFalse(redo.isEnabled)

        wear("Black Jeans", in: "pants")
        XCTAssertTrue(chip("pants").waitForExistence(timeout: 5))

        undo.tap()
        XCTAssertFalse(chip("pants").exists)
        XCTAssertTrue(chip("tops").exists)
        XCTAssertTrue(redo.isEnabled)

        undo.tap()
        XCTAssertFalse(chip("tops").exists)
        XCTAssertFalse(undo.isEnabled)
        XCTAssertTrue(redo.isEnabled)

        redo.tap()
        XCTAssertTrue(chip("tops").exists)
        redo.tap()
        XCTAssertTrue(chip("pants").exists)
        XCTAssertFalse(redo.isEnabled)
        XCTAssertTrue(undo.isEnabled)
    }

    func testNewChangeAfterUndoClearsRedo() {
        wear("Blue Tee", in: "tops")
        wear("Black Jeans", in: "pants")
        undo.tap()
        XCTAssertTrue(redo.isEnabled)

        wear("Red Shirt", in: "tops")   // replaces the Blue Tee
        XCTAssertTrue(chip("tops").label.contains("Red Shirt"))

        XCTAssertFalse(redo.isEnabled)
        undo.tap()
        XCTAssertTrue(chip("tops").label.contains("Blue Tee"))
        XCTAssertFalse(chip("pants").exists)
    }

    func testRemovingAWornPieceCanBeUndone() {
        wear("Blue Tee", in: "tops")
        XCTAssertTrue(chip("tops").waitForExistence(timeout: 5))
        chip("tops").tap()
        XCTAssertFalse(chip("tops").exists)

        undo.tap()
        XCTAssertTrue(chip("tops").waitForExistence(timeout: 5))
    }
}
