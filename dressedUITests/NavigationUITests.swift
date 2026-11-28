import XCTest

final class NavigationUITests: XCTestCase {
    /// Fixture-backed publishing checks UI wiring only; Firebase is covered by emulator tests.
    func testPostComposerSelectsPhotoAndSavedOutfitThenShowsSnapshotInFeed() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-mockSignedIn", "-showDiscovery"]
        app.launch()
        if app.buttons["sharedImport.close"].waitForExistence(timeout: 2) { app.buttons["sharedImport.close"].tap() }
        XCTAssertTrue(app.buttons["infinite.post.infinite_0"].waitForExistence(timeout: 15))
        let create = app.buttons["ootd.createPost"]
        XCTAssertTrue(create.waitForExistence(timeout: 5))
        create.tapWhenStable()
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
        details.tapWhenStable()
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
        if app.buttons["sharedImport.close"].waitForExistence(timeout: 2) {
            app.buttons["sharedImport.close"].tap()
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
        // The header circle shows the account initial and opens the user's own profile.
        let profileButton = app.buttons["app.profileButton"]
        XCTAssertEqual(profileButton.label, "Profile")
        profileButton.tap()
        XCTAssertTrue(app.otherElements["profile.header"].waitForExistence(timeout: 5)
            || app.staticTexts["Preview"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["profile.signOut"].exists)
        let profileShot = XCTAttachment(screenshot: app.screenshot())
        profileShot.name = "Profile screen"
        profileShot.lifetime = .keepAlways
        add(profileShot)
        XCTAssertTrue(app.buttons["tab.discovery"].isSelected)
        app.buttons["Back, Profile"].tap()
        XCTAssertTrue(profileButton.waitForExistence(timeout: 5))

        app.buttons["tab.avatar"].tap()
        XCTAssertTrue(app.buttons["tab.avatar"].isSelected)
        XCTAssertTrue(app.otherElements["tryon.canvas"].waitForExistence(timeout: 10))
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

    func testUploadOffersPhotoAndLinkAndPickerOpens() {
        let app = XCUIApplication()
        app.launchArguments = ["-mockSignedIn", "-skipDemoCloset", "-showCamera"]
        allowCameraAccess()
        app.launch()

        let upload = app.buttons["Upload"]
        XCTAssertTrue(upload.waitForExistence(timeout: 10))
        upload.tap()
        XCTAssertTrue(app.buttons["Photo"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Product Link"].exists)
        XCTAssertFalse(app.buttons["Photos of One Item"].exists)
        XCTAssertFalse(app.buttons["Photos of a Full Outfit"].exists)
        let choices = XCTAttachment(screenshot: app.screenshot())
        choices.name = "Upload choices"; choices.lifetime = .keepAlways; add(choices)
        app.buttons["Photo"].tap()
        let cancelPicker = app.buttons["Cancel"]
        XCTAssertTrue(cancelPicker.waitForExistence(timeout: 5))
        cancelPicker.tap()
        XCTAssertTrue(upload.waitForExistence(timeout: 5))
    }

    /// One tap on a library photo picks it; there is no multi-selection step.
    func testPickedPhotoOpensPieceReviewAndCloseDiscards() {
        let app = XCUIApplication()
        app.launchArguments = ["-mockSignedIn", "-skipDemoCloset", "-showCamera"]
        allowCameraAccess()
        app.launch()

        let upload = app.buttons["Upload"]
        XCTAssertTrue(upload.waitForExistence(timeout: 10))
        upload.tap()
        app.buttons["Photo"].tap()
        let photo = app.images.matching(NSPredicate(format: "label BEGINSWITH %@", "Photo,")).firstMatch
        XCTAssertTrue(photo.waitForExistence(timeout: 10), "Seed a synthetic photo in this test simulator first.")
        // The picker is hosted out of process and reports its photos as not hittable, so tap by coordinate.
        photo.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()

        let close = app.buttons["sharedImport.close"]
        XCTAssertTrue(close.waitForExistence(timeout: 15))
        close.tap()
        XCTAssertTrue(upload.waitForExistence(timeout: 5))
        XCTAssertFalse(close.exists)
    }

    /// Uses the Debug demo closet, which seeds two outfits into a fresh install.
    func testDeleteOutfitFromDetailKeepsItsPieces() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-mockSignedIn"]
        app.launch()
        XCTAssertTrue(app.buttons["closet.filter.Outfits"].waitForExistence(timeout: 10))
        app.buttons["closet.filter.Outfits"].tap()
        let outfit = app.buttons["Cozy Weekend"]
        XCTAssertTrue(outfit.waitForExistence(timeout: 5), "Run on a fresh install so the demo outfit exists.")
        outfit.tap()

        let options = app.buttons["Outfit options"]
        XCTAssertTrue(options.waitForExistence(timeout: 5))
        options.tap()
        let deleteItem = app.buttons["Delete Outfit"]
        XCTAssertTrue(deleteItem.waitForExistence(timeout: 5))
        deleteItem.tap()
        let alert = app.alerts["Delete this outfit?"]
        XCTAssertTrue(alert.waitForExistence(timeout: 5))
        alert.buttons["Cancel"].tap()
        XCTAssertTrue(options.waitForExistence(timeout: 5), "Cancel keeps the outfit open")

        options.tap()
        XCTAssertTrue(deleteItem.waitForExistence(timeout: 5))
        let menu = XCTAttachment(screenshot: app.screenshot())
        menu.name = "Outfit menu"; menu.lifetime = .keepAlways; add(menu)
        deleteItem.tap()
        XCTAssertTrue(alert.waitForExistence(timeout: 5))
        alert.buttons["Delete"].tap()
        XCTAssertTrue(app.buttons["Easy Denim"].waitForExistence(timeout: 5))
        XCTAssertFalse(outfit.exists)
        app.buttons["closet.filter.All"].tap()
        XCTAssertTrue(app.buttons["Brown Wool Sweater"].waitForExistence(timeout: 5))

        app.terminate()
        app.launch()
        app.buttons["closet.filter.Outfits"].tap()
        XCTAssertTrue(app.buttons["Easy Denim"].waitForExistence(timeout: 5))
        XCTAssertFalse(outfit.exists)
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

// Wait for a hittable element to keep the same frame across consecutive samples.
// Keyboard/tab-bar and navigation transitions can otherwise move it after event resolution.
extension XCUIElement {
    func tapWhenStable(timeout: TimeInterval = 15) {
        var lastFrame: CGRect?
        let stable = NSPredicate { _, _ in
            guard self.exists, self.isHittable else { lastFrame = nil; return false }
            let current = self.frame
            defer { lastFrame = current }
            return !current.isEmpty && lastFrame == current
        }
        let ready = XCTNSPredicateExpectation(predicate: stable, object: self)
        let result = XCTWaiter.wait(for: [ready], timeout: timeout)
        XCTAssertEqual(result, .completed, "Control did not become stable: \(identifier)")
        guard result == .completed else { return }
        tap()
    }
}
