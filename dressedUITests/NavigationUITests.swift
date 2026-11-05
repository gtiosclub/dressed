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
}
