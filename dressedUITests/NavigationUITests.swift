import XCTest

final class NavigationUITests: XCTestCase {
    func testDesignSystemTabsClosetSectionsAndAvatarEntry() {
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

        app.buttons["tab.discovery"].tap()
        XCTAssertTrue(app.buttons["infinite.post.infinite_0"].waitForExistence(timeout: 10))
        app.buttons["app.profileButton"].tap()
        XCTAssertTrue(app.buttons["tab.avatar"].isSelected)
        XCTAssertTrue(app.navigationBars["Avatar Studio"].waitForExistence(timeout: 10))
        app.buttons["tab.camera"].tap()
        XCTAssertTrue(app.buttons["tab.camera"].isSelected)
        XCTAssertTrue(app.buttons["Choose from Photos"].waitForExistence(timeout: 5))
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Design system tabs on Camera"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    // MARK: - SOCIAL-P09 notification inbox (fixture data, mock session)

    func testNotificationInboxOpensOnlyAvailableDestinations() {
        let app = launchDiscovery()
        let bell = app.buttons["discovery.notifications"]
        XCTAssertTrue(bell.waitForExistence(timeout: 10))
        XCTAssertTrue(waitFor(bell, value: "Unread activity"))
        bell.tap()

        // n_001–003 are one unread row; n_004's post was removed before the load.
        let likes = app.buttons["notifications.row.n_003"]
        XCTAssertTrue(likes.waitForExistence(timeout: 10))
        XCTAssertTrue(likes.label.hasPrefix("Unread. maya and 2 others liked your post."), likes.label)
        XCTAssertFalse(app.buttons["notifications.row.n_001"].exists)
        let comment = app.buttons["notifications.row.n_004"]
        XCTAssertTrue(comment.label.hasSuffix("Post removed."), comment.label)
        XCTAssertTrue(app.buttons["notifications.row.n_006"].label.contains("Unavailable account"))
        attachScreenshot(app, "Inbox with New and Earlier")

        comment.tap()
        XCTAssertTrue(app.staticTexts["This post isn't available"].waitForExistence(timeout: 5))
        attachScreenshot(app, "Removed post")
        app.buttons["notifications.unavailable.back"].tap()
        // The opened row moves from New to Earlier and must stop reading as unread.
        XCTAssertTrue(app.buttons["notifications.row.n_004"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["notifications.row.n_004"].label.hasPrefix("Unread"))

        app.buttons["notifications.row.n_006"].tap()
        XCTAssertTrue(app.staticTexts["This account isn't available"].waitForExistence(timeout: 5))
        attachScreenshot(app, "Unavailable profile")
        app.buttons["notifications.unavailable.back"].tap()

        // n_007's post was available at load and removed before the tap.
        let stale = app.buttons["notifications.row.n_007"]
        XCTAssertTrue(stale.waitForExistence(timeout: 5))
        XCTAssertFalse(stale.label.contains("Post removed"))
        stale.tap()
        XCTAssertTrue(app.staticTexts["This post isn't available"].waitForExistence(timeout: 5))
        app.buttons["notifications.unavailable.back"].tap()
        XCTAssertTrue(app.buttons["notifications.row.n_007"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["notifications.row.n_007"].label.hasSuffix("Post removed."))

        // Available destinations open with only the supplied IDs.
        app.buttons["notifications.row.n_005"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["notifications.profile.user_b"].waitForExistence(timeout: 5))
        app.navigationBars.buttons.firstMatch.tap()
        app.buttons["notifications.row.n_003"].tap()
        XCTAssertTrue(app.navigationBars["Post"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Weekend denim"].firstMatch.waitForExistence(timeout: 5))
        app.navigationBars.buttons.firstMatch.tap()

        // Every row has been opened, so the bell no longer shows unread activity.
        XCTAssertTrue(app.buttons["notifications.row.n_003"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["notifications.row.n_003"].label.hasPrefix("Unread"))
        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(bell.waitForExistence(timeout: 5))
        XCTAssertTrue(waitFor(bell, value: ""))
    }

    func testNotificationRefreshFailureKeepsRowsAndRetries() {
        let app = launchDiscovery(extraArguments: ["-failNotificationRefresh"])
        let bell = app.buttons["discovery.notifications"]
        XCTAssertTrue(bell.waitForExistence(timeout: 10))
        bell.tap()
        let row = app.buttons["notifications.row.n_003"]
        XCTAssertTrue(row.waitForExistence(timeout: 10))

        let start = row.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        start.press(forDuration: 0.1, thenDragTo: start.withOffset(CGVector(dx: 0, dy: 400)))
        XCTAssertTrue(app.buttons["notifications.retry"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["notifications.row.n_003"].exists, "Rows stay after a failed refresh")
        attachScreenshot(app, "Failed refresh")

        app.buttons["notifications.retry"].tap()
        XCTAssertTrue(waitForDisappearance(app.buttons["notifications.retry"]))
        XCTAssertTrue(app.buttons["notifications.row.n_003"].exists)
    }

    func testEmptyNotificationInbox() {
        let app = launchDiscovery(extraArguments: ["-emptyNotifications"])
        let bell = app.buttons["discovery.notifications"]
        XCTAssertTrue(bell.waitForExistence(timeout: 10))
        bell.tap()
        XCTAssertTrue(app.staticTexts["No activity yet"].waitForExistence(timeout: 10))
        attachScreenshot(app, "Empty inbox")
    }

    private func launchDiscovery(extraArguments: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-mockSignedIn", "-showDiscovery"] + extraArguments
        app.launch()
        if app.buttons["Later"].waitForExistence(timeout: 2) {
            app.buttons["Later"].tap()
        }
        return app
    }

    /// An empty accessibility value can come back as nil, so compare as a string.
    private func waitFor(_ element: XCUIElement, value: String) -> Bool {
        let deadline = Date().addingTimeInterval(5)
        repeat {
            if (element.value as? String ?? "") == value { return true }
            RunLoop.current.run(until: Date().addingTimeInterval(0.25))
        } while Date() < deadline
        return false
    }

    private func waitForDisappearance(_ element: XCUIElement) -> Bool {
        let predicate = NSPredicate(format: "exists == false")
        return XCTWaiter().wait(for: [expectation(for: predicate, evaluatedWith: element)], timeout: 10) == .completed
    }

    private func attachScreenshot(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
