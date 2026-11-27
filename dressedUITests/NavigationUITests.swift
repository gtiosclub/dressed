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
        XCTAssertTrue(app.buttons["avatar.settings"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["avatar.outfit"].exists)
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

    /// Closet outfit → Try On Outfit → Avatar tab shows a generated look. Uses the mock generator and a
    /// rendered reference photo, so no network or real photo is involved; not a real sign-in check.
    func testTryOnOutfitGeneratesAvatarLook() {
        continueAfterFailure = false
        let app = XCUIApplication()
        // AVATAR_BRIDGE=1 (TEST_RUNNER_AVATAR_BRIDGE=1 with xcodebuild) uses the Mac bridge instead of the
        // in-app mock; start backend/avatar/avatar_service.py first (--fixture for no paid calls).
        let usesBridge = ProcessInfo.processInfo.environment["AVATAR_BRIDGE"] == "1"
        // AVATAR_REFERENCE_PATH points at a consented test photo on the Mac (simulator only).
        let referencePath = ProcessInfo.processInfo.environment["AVATAR_REFERENCE_PATH"]
        let reference = referencePath.map { ["-avatarReferencePath", $0] } ?? ["-avatarReferenceFixture"]
        app.launchArguments = ["-mockSignedIn"] + reference + (usesBridge ? [] : ["-mockAvatarGenerator"])
        app.launch()
        openDemoOutfitAndTryOn(app)

        XCTAssertTrue(app.buttons["tab.avatar"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["tab.avatar"].isSelected)
        if app.otherElements["avatar.generating"].waitForExistence(timeout: 5) {
            let generating = XCTAttachment(screenshot: app.screenshot())
            generating.name = "Avatar generating"; generating.lifetime = .keepAlways; add(generating)
        }
        XCTAssertTrue(app.otherElements["avatar.look"].waitForExistence(timeout: usesBridge ? 200 : 15),
                      "The generated look should appear")
        let early = XCTAttachment(screenshot: app.screenshot())
        early.name = "Avatar look appeared"; early.lifetime = .keepAlways; add(early)
        sleep(3) // let the mosaic-and-blur reveal finish before the screenshot
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "Avatar generated look"; shot.lifetime = .keepAlways; add(shot)

        app.buttons["avatar.settings"].tap()
        XCTAssertTrue(app.staticTexts["Avatar Settings"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Remove Photo"].exists)
        let settings = XCTAttachment(screenshot: app.screenshot())
        settings.name = "Avatar settings"; settings.lifetime = .keepAlways; add(settings)
    }

    func testTryOnOutfitWithoutPhotoAsksForOne() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-mockSignedIn", "-mockAvatarGenerator", "-avatarNoReference"]
        app.launch()
        openDemoOutfitAndTryOn(app)

        XCTAssertTrue(app.buttons["avatar.addPhoto"].waitForExistence(timeout: 10))
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "Avatar asks for a photo"; shot.lifetime = .keepAlways; add(shot)
        app.buttons["Add Photo"].tap()
        XCTAssertTrue(app.staticTexts["Avatar Settings"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["avatar.settings.upload"].exists)
    }

    /// The outfit button opens the piece picker; choosing a piece and closing the picker generates a look.
    func testPiecePickerChoosesPiecesAndGeneratesOnClose() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-mockSignedIn", "-mockAvatarGenerator", "-avatarReferenceFixture"]
        app.launch()
        if app.buttons["sharedImport.close"].waitForExistence(timeout: 2) {
            app.buttons["sharedImport.close"].tap()
        }
        app.buttons["tab.avatar"].tap()
        XCTAssertTrue(app.buttons["avatar.outfit"].waitForExistence(timeout: 10))
        app.buttons["avatar.outfit"].tap()
        XCTAssertTrue(app.buttons["avatar.picker.Outfits"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["avatar.picker.Outfits"].isSelected)
        app.buttons["avatar.picker.Tops"].tap()
        let tee = app.otherElements["avatar.picker"].buttons["Navy Tee"]
        XCTAssertTrue(tee.waitForExistence(timeout: 5))
        tee.tap()
        XCTAssertTrue(tee.isSelected)
        let picker = XCTAttachment(screenshot: app.screenshot())
        picker.name = "Avatar piece picker"; picker.lifetime = .keepAlways; add(picker)

        app.buttons["avatar.picker.searchButton"].tap()
        XCTAssertTrue(app.textFields["avatar.picker.search"].waitForExistence(timeout: 5))
        let search = XCTAttachment(screenshot: app.screenshot())
        search.name = "Avatar picker search"; search.lifetime = .keepAlways; add(search)
        app.buttons["Cancel"].tap()

        app.buttons["avatar.outfit"].tap()
        XCTAssertTrue(app.otherElements["avatar.look"].waitForExistence(timeout: 15))
        sleep(2)
        let look = XCTAttachment(screenshot: app.screenshot())
        look.name = "Avatar look after picker"; look.lifetime = .keepAlways; add(look)
    }

    /// Real Firebase session (no mock flags): the picker's Shop section lists `catalogProducts`, and trying
    /// on a product generates a look. Opt-in, because it needs a signed-in simulator and makes a paid call
    /// through the bridge: AVATAR_SHOP_LIVE=1 and AVATAR_REFERENCE_PATH (TEST_RUNNER_ prefix with xcodebuild).
    func testShopCatalogProductCanBeTriedOnWithRealSession() throws {
        let environment = ProcessInfo.processInfo.environment
        guard environment["AVATAR_SHOP_LIVE"] == "1", let reference = environment["AVATAR_REFERENCE_PATH"] else {
            throw XCTSkip("Set AVATAR_SHOP_LIVE=1 and AVATAR_REFERENCE_PATH on a signed-in simulator")
        }
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-avatarReferencePath", reference]
        app.launch()
        if app.buttons["sharedImport.close"].waitForExistence(timeout: 2) {
            app.buttons["sharedImport.close"].tap()
        }
        XCTAssertTrue(app.buttons["tab.avatar"].waitForExistence(timeout: 20), "Sign in on this simulator first")
        app.buttons["tab.avatar"].tap()
        app.buttons["avatar.outfit"].tap()
        let shop = app.buttons["avatar.picker.Shop"]
        XCTAssertTrue(shop.waitForExistence(timeout: 20), "Shop needs catalogProducts from Firebase")
        shop.tap()
        let picker = app.otherElements["avatar.picker"]
        let first = picker.buttons.matching(NSPredicate(format: "isEnabled == true AND label != 'Search' AND NOT (identifier BEGINSWITH 'avatar.picker.')")).firstMatch
        XCTAssertTrue(first.waitForExistence(timeout: 20), "A catalog photo should download")
        sleep(2)
        let grid = XCTAttachment(screenshot: app.screenshot())
        grid.name = "Avatar Shop section"; grid.lifetime = .keepAlways; add(grid)
        first.tap()
        app.buttons["avatar.outfit"].tap()
        XCTAssertTrue(app.otherElements["avatar.look"].waitForExistence(timeout: 200))
        sleep(3)
        let look = XCTAttachment(screenshot: app.screenshot())
        look.name = "Avatar look from Shop"; look.lifetime = .keepAlways; add(look)
    }

    /// Opens the demo closet's "Easy Denim" outfit (the delete test removes "Cozy Weekend").
    private func openDemoOutfitAndTryOn(_ app: XCUIApplication) {
        if app.buttons["sharedImport.close"].waitForExistence(timeout: 2) {
            app.buttons["sharedImport.close"].tap()
        }
        XCTAssertTrue(app.buttons["closet.filter.Outfits"].waitForExistence(timeout: 10))
        app.buttons["closet.filter.Outfits"].tap()
        let outfit = app.buttons["Easy Denim"]
        XCTAssertTrue(outfit.waitForExistence(timeout: 5), "Run on a fresh install so the demo outfit exists.")
        outfit.tap()
        let tryOn = app.buttons["Try On Outfit"]
        XCTAssertTrue(tryOn.waitForExistence(timeout: 5))
        tryOn.tap()
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
