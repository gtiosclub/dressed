import XCTest

final class NavigationUITests: XCTestCase {
    func testThreeTabsClosetSectionsAndAvatarEntry() {
        let app = XCUIApplication()
        app.launchArguments = ["-mockSignedIn"]
        app.launch()
        if app.buttons["Later"].waitForExistence(timeout: 2) {
            app.buttons["Later"].tap()
        }
        app.tabBars.buttons["My Closet"].tap()

        XCTAssertTrue(app.tabBars.buttons["My Closet"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.tabBars.buttons["Discovery"].exists)
        XCTAssertTrue(app.tabBars.buttons["Camera"].exists)
        XCTAssertEqual(app.tabBars.buttons.count, 3)

        XCTAssertTrue(app.segmentedControls.buttons["Pieces"].waitForExistence(timeout: 5))
        app.segmentedControls.buttons["Outfits"].tap()
        XCTAssertTrue(app.segmentedControls.buttons["Outfits"].isSelected)
        app.segmentedControls.buttons["Wishlist"].tap()
        XCTAssertTrue(app.segmentedControls.buttons["Wishlist"].isSelected)

        app.buttons["app.profileButton"].tap()
        XCTAssertTrue(app.navigationBars["Profile"].waitForExistence(timeout: 10))
        app.buttons["Open studio"].tap()
        XCTAssertTrue(app.navigationBars["Avatar Studio"].waitForExistence(timeout: 10))
    }

    func testPhotoLibraryImportModeAndPickerEntry() {
        let app = XCUIApplication()
        app.launchArguments = ["-mockSignedIn", "-showCamera"]
        app.launch()

        let modePicker = app.segmentedControls.firstMatch
        XCTAssertTrue(modePicker.waitForExistence(timeout: 10))
        let fullOutfit = modePicker.buttons["Full Outfit"]
        fullOutfit.tap()
        XCTAssertTrue(fullOutfit.isSelected)
        XCTAssertTrue(app.staticTexts["Choose photos of the same outfit."].exists)

        let oneItem = modePicker.buttons["One Item"]
        oneItem.tap()
        XCTAssertTrue(oneItem.isSelected)

        let choosePhotos = app.buttons["Choose from Photos"]
        XCTAssertTrue(choosePhotos.exists)
        choosePhotos.tap()
        let cancelPicker = app.buttons["Cancel"]
        XCTAssertTrue(cancelPicker.waitForExistence(timeout: 5))
        cancelPicker.tap()
        XCTAssertTrue(choosePhotos.waitForExistence(timeout: 5))
    }

    func testSelectingMultiplePhotosOpensCombinedReview() {
        let app = XCUIApplication()
        app.launchArguments = ["-mockSignedIn", "-showCamera"]
        app.launch()

        selectTwoSimulatorPhotos(in: app)

        let reviewPhotos = app.buttons["Review 2 Photos"]
        XCTAssertTrue(reviewPhotos.waitForExistence(timeout: 10))
        reviewPhotos.tap()

        XCTAssertTrue(app.navigationBars["Review Item"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Selected Photos"].exists)
        XCTAssertTrue(app.staticTexts["Seen in 2 photos"].waitForExistence(timeout: 30))
        XCTAssertTrue(app.buttons["Cancel"].exists)
    }

    func testFullOutfitMultiPhotoReviewStartsUnselected() {
        let app = XCUIApplication()
        app.launchArguments = ["-mockSignedIn", "-showCamera"]
        app.launch()

        app.segmentedControls.firstMatch.buttons["Full Outfit"].tap()
        selectTwoSimulatorPhotos(in: app)
        app.buttons["Review 2 Photos"].tap()

        XCTAssertTrue(app.navigationBars["Review Outfit"].waitForExistence(timeout: 10))
        let selections = app.switches.matching(identifier: "Select this piece")
        XCTAssertTrue(selections.firstMatch.waitForExistence(timeout: 30))
        for index in 0..<selections.count {
            XCTAssertEqual(selections.element(boundBy: index).value as? String, "0")
        }

        let saveSelectedPieces = app.buttons["Save Selected Pieces"]
        for _ in 0..<5 where !saveSelectedPieces.exists {
            app.swipeUp()
        }
        XCTAssertTrue(saveSelectedPieces.exists, app.debugDescription)
        XCTAssertFalse(saveSelectedPieces.isEnabled)
    }

    private func selectTwoSimulatorPhotos(in app: XCUIApplication) {
        app.buttons["Choose from Photos"].tap()
        let photoImages = app.images.matching(NSPredicate(format: "label BEGINSWITH %@", "Photo,"))
        XCTAssertTrue(photoImages.element(boundBy: 1).waitForExistence(timeout: 10), app.debugDescription)
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.16, dy: 0.56)).tap()
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.56)).tap()
        app.buttons["Add"].tap()
        XCTAssertTrue(app.buttons["Review 2 Photos"].waitForExistence(timeout: 10))
    }
}
