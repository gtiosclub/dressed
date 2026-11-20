import XCTest

final class NavigationUITests: XCTestCase {
    /// Fixture-backed publishing checks UI wiring only; Firebase is covered by emulator tests.
    func testPostComposerSelectsPhotoAndSavedOutfitThenShowsSnapshotInFeed() {
        let app = XCUIApplication()
        app.launchArguments = ["-mockSignedIn", "-showDiscovery"]
        app.launch()
        if app.buttons["Later"].waitForExistence(timeout: 2) { app.buttons["Later"].tap() }
        XCTAssertTrue(app.buttons["infinite.post.infinite_0"].waitForExistence(timeout: 15))
        let create = app.buttons["ootd.createPost"]
        XCTAssertTrue(create.waitForExistence(timeout: 5))
        create.tap()
        let share = app.buttons["ootd.sharePreview"]
        XCTAssertTrue(share.waitForExistence(timeout: 5))
        XCTAssertFalse(share.isEnabled)
        app.buttons["ootd.choosePhoto"].tap()
        let photos = app.images.matching(NSPredicate(format: "label BEGINSWITH %@", "Photo,"))
        XCTAssertTrue(photos.firstMatch.waitForExistence(timeout: 10), "Seed a synthetic photo in this test simulator first.")
        photos.firstMatch.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        XCTAssertTrue(app.buttons["ootd.newPost.Outfit details"].waitForExistence(timeout: 10))
        app.buttons["ootd.newPost.Outfit details"].tap()
        let outfit = app.buttons["ootd.outfit.10000000-0000-4000-8000-000000000001"]
        XCTAssertTrue(outfit.waitForExistence(timeout: 5))
        outfit.tap()
        app.buttons["Done"].tap()
        XCTAssertTrue(app.staticTexts["3 items tagged"].waitForExistence(timeout: 5))
        let caption = app.textFields["ootd.newPostCaption"]
        caption.tap()
        caption.typeText("Publication UI fixture")
        XCTAssertTrue(share.isEnabled)
        let composer = XCTAttachment(screenshot: app.screenshot())
        composer.name = "Post photo and selected outfit"
        composer.lifetime = .keepAlways
        add(composer)
        share.tap()
        let details = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "infinite.items.")).firstMatch
        XCTAssertTrue(details.waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Publication UI fixture"].exists)
        details.tap()
        XCTAssertTrue(app.staticTexts["Cozy Weekend"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Brown Wool Sweater"].exists)
        XCTAssertTrue(app.staticTexts["Wide-Leg Jeans"].exists)
        XCTAssertTrue(app.staticTexts["Silver Pendant Necklace"].exists)
        let breakdown = XCTAttachment(screenshot: app.screenshot())
        breakdown.name = "Published outfit snapshot"
        breakdown.lifetime = .keepAlways
        add(breakdown)
    }

    func testDesignSystemTabsClosetSectionsAndAvatarEntry() {
        let app = XCUIApplication()
        app.launchArguments = ["-mockSignedIn", "-skipDemoCloset"]
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

        // Closet chips: Outfits, All, Wishlist, then one per category.
        XCTAssertTrue(app.buttons["closet.filter.All"].waitForExistence(timeout: 5))
        app.buttons["closet.filter.Outfits"].tap()
        XCTAssertTrue(app.buttons["closet.filter.Outfits"].isSelected)
        app.buttons["closet.filter.Wishlist"].tap()
        XCTAssertTrue(app.buttons["closet.filter.Wishlist"].isSelected)

        app.buttons["tab.discovery"].tap()
        XCTAssertTrue(app.buttons["infinite.post.infinite_0"].waitForExistence(timeout: 10))
        app.buttons["app.profileButton"].tap()
        XCTAssertTrue(app.buttons["tab.avatar"].isSelected)
        XCTAssertTrue(app.navigationBars["Avatar Studio"].waitForExistence(timeout: 10))
        allowCameraAccess()
        app.buttons["tab.camera"].tap()
        // The camera is full screen: no tab bar, and Close returns to the tab it was opened from.
        let close = app.buttons["camera.close"]
        XCTAssertTrue(close.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Upload"].exists)
        XCTAssertTrue(app.buttons["Flip camera"].exists)
        XCTAssertTrue(app.buttons["Take photo"].exists)
        XCTAssertFalse(app.buttons["tab.camera"].exists)
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Camera screen"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        close.tap()
        XCTAssertTrue(app.buttons["tab.avatar"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["tab.avatar"].isSelected)
    }

    func testUploadOffersPhotosAndLinkAndPickerOpens() {
        let app = XCUIApplication()
        app.launchArguments = ["-mockSignedIn", "-skipDemoCloset", "-showCamera"]
        allowCameraAccess()
        app.launch()

        let upload = app.buttons["Upload"]
        XCTAssertTrue(upload.waitForExistence(timeout: 10))
        upload.tap()
        XCTAssertTrue(app.buttons["Photos of a Full Outfit"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Product Link"].exists)
        app.buttons["Photos of One Item"].tap()
        let cancelPicker = app.buttons["Cancel"]
        XCTAssertTrue(cancelPicker.waitForExistence(timeout: 5))
        cancelPicker.tap()
        XCTAssertTrue(upload.waitForExistence(timeout: 5))
    }

    func testSelectingMultiplePhotosOpensCombinedReview() {
        let app = XCUIApplication()
        app.launchArguments = ["-mockSignedIn", "-skipDemoCloset", "-showCamera"]
        allowCameraAccess()
        app.launch()

        selectTwoSimulatorPhotos(in: app, choice: "Photos of One Item")

        XCTAssertTrue(app.navigationBars["Review Item"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Seen in 2 photos"].waitForExistence(timeout: 30))
        XCTAssertTrue(app.buttons["Cancel"].exists)
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Multi-photo item review"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    func testFullOutfitMultiPhotoReviewStartsUnselected() {
        let app = XCUIApplication()
        app.launchArguments = ["-mockSignedIn", "-skipDemoCloset", "-showCamera"]
        allowCameraAccess()
        app.launch()

        selectTwoSimulatorPhotos(in: app, choice: "Photos of a Full Outfit")

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
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Full-outfit review starts unselected"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    /// Dismisses the system camera permission prompt the first time the camera opens.
    private func allowCameraAccess() {
        addUIInterruptionMonitor(withDescription: "Camera permission") { alert in
            for label in ["Allow", "OK"] where alert.buttons[label].exists {
                alert.buttons[label].tap()
                return true
            }
            return false
        }
    }

    private func selectTwoSimulatorPhotos(in app: XCUIApplication, choice: String) {
        let upload = app.buttons["Upload"]
        XCTAssertTrue(upload.waitForExistence(timeout: 10))
        upload.tap()
        app.buttons[choice].tap()
        let photoImages = app.images.matching(NSPredicate(format: "label BEGINSWITH %@", "Photo,"))
        XCTAssertTrue(photoImages.element(boundBy: 1).waitForExistence(timeout: 10), app.debugDescription)
        // The picker is hosted out of process and reports its photos as not hittable, so tap by coordinate.
        for index in 0..<2 {
            photoImages.element(boundBy: index).coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        }
        app.buttons["Add"].tap()
    }
}

/// Discovery search (Figma 976:162 pattern): "Search Styles" opens a dimmed sheet with suggestions.
/// Fixture-backed: mock session and demo catalog.
final class DiscoverySearchUITests: XCTestCase {
    func testSearchStylesOpensSuggestionSheetAndCloses() {
        let app = XCUIApplication()
        app.launchArguments = ["-mockSignedIn", "-skipDemoCloset", "-showDiscovery"]
        app.launch()

        let search = app.buttons["discovery.searchButton"]
        XCTAssertTrue(search.waitForExistence(timeout: 10))
        // Posts are photos only: no Save pill and no Saved Posts bookmark.
        XCTAssertFalse(app.buttons["ootd.savedPosts"].exists)
        XCTAssertFalse(app.buttons["savePostToggle.button"].exists)
        search.tap()

        XCTAssertTrue(app.buttons["Close search"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Y2K"].exists)
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Discovery search open"
        screenshot.lifetime = .keepAlways
        add(screenshot)

        app.buttons["Close search"].tap()
        XCTAssertTrue(search.waitForExistence(timeout: 5))
    }
}
