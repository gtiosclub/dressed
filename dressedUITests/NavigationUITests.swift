import XCTest

final class NavigationUITests: XCTestCase {
    func testThreeTabsClosetSectionsAndAvatarEntry() {
        let app = XCUIApplication()
        app.launchArguments = ["-mockSignedIn"]
        app.launch()
        if app.buttons["Later"].waitForExistence(timeout: 2) {
            app.buttons["Later"].tap()
        }
        // DSTabBar replaces the system tab bar, so tabs are found by identifier.
        XCTAssertTrue(app.buttons["tab.closet"].waitForExistence(timeout: 10))
        app.buttons["tab.closet"].tap()
        XCTAssertTrue(app.buttons["tab.closet"].isSelected)
        XCTAssertTrue(app.buttons["tab.discovery"].exists)
        XCTAssertTrue(app.buttons["tab.avatar"].exists)
        XCTAssertTrue(app.buttons["tab.camera"].exists)
        XCTAssertEqual(app.buttons["tab.closet"].label, "Closet")

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
}
