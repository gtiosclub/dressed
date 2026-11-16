import XCTest

/// Heart (save outfit) and screenshot buttons in Avatar Studio → Full Body (#239).
/// These launch with `-mockSignedIn` and the debug closet fixture, so they do not exercise real sign-in.
final class OutfitHeartUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        launch(seed: true)
    }

    private func launch(seed: Bool) {
        app = XCUIApplication()
        app.launchArguments = ["-mockSignedIn"] + (seed ? ["-seedClosetFixture"] : [])
        app.launch()
        if app.buttons["Later"].waitForExistence(timeout: 2) {
            app.buttons["Later"].tap()
        }
        app.tabBars.buttons["Avatar"].tap()
        XCTAssertTrue(app.navigationBars["Avatar Studio"].waitForExistence(timeout: 10))
    }

    private var heart: XCUIElement { app.buttons["studio.heart"] }
    private var screenshot: XCUIElement { app.buttons["studio.screenshot"] }

    private func showMode(_ name: String) {
        app.segmentedControls.buttons[name].tap()
    }

    private func wear(_ name: String, in category: String) {
        showMode("Try On")
        app.segmentedControls.buttons["Closet Pieces"].tap()
        app.buttons[category].firstMatch.tap()
        let card = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", name)).firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 5), "\(name) should be in the tray")
        card.tap()
    }

    private func showFullBody() {
        showMode("Full Body")
        XCTAssertTrue(heart.waitForExistence(timeout: 5))
    }

    private func savedFitsAreEmpty() -> Bool {
        showMode("Try On")
        app.segmentedControls.buttons["Saved Fits"].tap()
        return app.staticTexts["No items available"].waitForExistence(timeout: 3)
    }

    func testBottomBarHasHeartOnTheLeftAndScreenshotOnTheRight() {
        showFullBody()
        XCTAssertTrue(screenshot.exists)
        XCTAssertLessThan(heart.frame.minX, screenshot.frame.minX)
        XCTAssertEqual(heart.frame.midY, screenshot.frame.midY, accuracy: 2)
    }

    func testHeartIsDisabledWhenNothingIsWorn() {
        showFullBody()
        XCTAssertFalse(heart.isEnabled)
        XCTAssertEqual(heart.value as? String, "Not saved")
    }

    func testOldToolbarHeartIsGone() {
        XCTAssertFalse(app.navigationBars["Avatar Studio"].buttons["Save Outfit"].exists)
    }

    func testHeartSavesTheOutfitAndTappingAgainRemovesIt() {
        XCTAssertTrue(savedFitsAreEmpty())
        wear("Blue Tee", in: "tops")
        showFullBody()
        XCTAssertTrue(heart.isEnabled)
        XCTAssertEqual(heart.value as? String, "Not saved")

        heart.tap()
        XCTAssertEqual(heart.value as? String, "Saved")

        showMode("Try On")
        app.segmentedControls.buttons["Saved Fits"].tap()
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Unnamed Outfit 1")).firstMatch
            .waitForExistence(timeout: 5))

        showFullBody()
        heart.tap()
        XCTAssertEqual(heart.value as? String, "Not saved")
        XCTAssertTrue(savedFitsAreEmpty())
    }

    func testHeartFollowsTheWornOutfit() {
        wear("Blue Tee", in: "tops")
        showFullBody()
        heart.tap()
        XCTAssertEqual(heart.value as? String, "Saved")

        wear("Red Shirt", in: "tops")        // a different outfit
        showFullBody()
        XCTAssertEqual(heart.value as? String, "Not saved")

        wear("Blue Tee", in: "tops")         // back to the saved one
        showFullBody()
        XCTAssertEqual(heart.value as? String, "Saved")

        heart.tap()                           // clean up
        XCTAssertEqual(heart.value as? String, "Not saved")
    }

    func testSavedOutfitSurvivesRelaunch() {
        wear("Blue Tee", in: "tops")
        showFullBody()
        heart.tap()
        XCTAssertEqual(heart.value as? String, "Saved")

        app.terminate()
        launch(seed: false)   // keeps the closet and saved outfits on disk
        wear("Blue Tee", in: "tops")
        showFullBody()
        XCTAssertEqual(heart.value as? String, "Saved")

        heart.tap()           // clean up
        XCTAssertEqual(heart.value as? String, "Not saved")
    }

    func testScreenshotButtonOpensTheSnapshotSheet() {
        wear("Blue Tee", in: "tops")
        showFullBody()
        screenshot.tap()
        XCTAssertTrue(app.navigationBars["Snapshot"].waitForExistence(timeout: 5))
        app.buttons["Done"].tap()
        XCTAssertTrue(heart.waitForExistence(timeout: 5))
    }
}
