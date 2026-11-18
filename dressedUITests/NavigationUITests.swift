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
        XCTAssertTrue(app.staticTexts["Seen in 2 photos"].waitForExistence(timeout: 30))
        XCTAssertTrue(app.buttons["Cancel"].exists)
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Multi-photo item review"
        screenshot.lifetime = .keepAlways
        add(screenshot)
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
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Full-outfit review starts unselected"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    private func selectTwoSimulatorPhotos(in app: XCUIApplication) {
        app.buttons["Choose from Photos"].tap()
        let photoImages = app.images.matching(NSPredicate(format: "label BEGINSWITH %@", "Photo,"))
        XCTAssertTrue(photoImages.element(boundBy: 1).waitForExistence(timeout: 10), app.debugDescription)
        photoImages.element(boundBy: 0).tap()
        photoImages.element(boundBy: 1).tap()
        app.buttons["Add"].tap()
        XCTAssertTrue(app.buttons["Review 2 Photos"].waitForExistence(timeout: 10))
    }
}

/// Fixture-backed saved-post flows. They use the mock session and the demo saved-post store, so they
/// say nothing about real sign-in or the Firestore rules in #94.
final class SavedPostsUITests: XCTestCase {
    private func launchOOTD(_ arguments: [String]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-mockSignedIn", "-showDiscovery", "-showOOTD"] + arguments
        app.launch()
        return app
    }

    private func toggle(_ postId: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)["savedPostControl.\(postId)"].buttons["savePostToggle.button"]
    }

    private func wait(for element: XCUIElement, value: String) {
        expectation(for: NSPredicate(format: "value == %@", value), evaluatedWith: element)
        waitForExpectations(timeout: 10)
    }

    private func waitForDisappearance(of element: XCUIElement) {
        expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: element)
        waitForExpectations(timeout: 10)
    }

    private func openSavedPosts(in app: XCUIApplication) {
        let saved = app.buttons["ootd.savedPosts"]
        XCTAssertTrue(saved.waitForExistence(timeout: 10))
        saved.tap()
    }

    private func attachScreenshot(_ name: String, of app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testSaveInFeedShowsInSavedPostsSurvivesRelaunchAndUnsaves() {
        let app = launchOOTD(["-resetSavedPosts"])
        let feedToggle = toggle("demo_post_1", in: app)
        XCTAssertTrue(feedToggle.waitForExistence(timeout: 10))
        wait(for: feedToggle, value: "Not saved")
        attachScreenshot("OOTD card, not saved", of: app)

        feedToggle.tap()
        wait(for: feedToggle, value: "Saved")
        attachScreenshot("OOTD card, saved", of: app)
        openSavedPosts(in: app)
        XCTAssertTrue(app.buttons["savedPosts.post.demo_post_1"].waitForExistence(timeout: 10))

        app.terminate()
        app.launchArguments = ["-mockSignedIn", "-showDiscovery", "-showOOTD"]
        app.launch()
        XCTAssertTrue(feedToggle.waitForExistence(timeout: 10))
        wait(for: feedToggle, value: "Saved")
        openSavedPosts(in: app)

        let savedCard = app.buttons["savedPosts.post.demo_post_1"]
        XCTAssertTrue(savedCard.waitForExistence(timeout: 10))
        toggle("demo_post_1", in: app).tap()
        waitForDisappearance(of: savedCard)
        XCTAssertTrue(app.staticTexts["No saved posts yet"].waitForExistence(timeout: 5))
        attachScreenshot("Saved posts, empty", of: app)
    }

    func testDeletedPostIsUnavailableWithoutACardAndCanBeUnsaved() {
        let app = launchOOTD(["-seedSavedPosts"])
        openSavedPosts(in: app)

        let unavailable = app.descendants(matching: .any)["savedPosts.unavailable.demo_post_removed"]
        XCTAssertTrue(unavailable.waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["savedPosts.post.demo_post_removed"].exists)
        XCTAssertTrue(app.buttons["savedPosts.post.demo_post_1"].exists)
        XCTAssertTrue(app.buttons["savedPosts.post.demo_post_2"].exists)
        attachScreenshot("Saved posts with a deleted post", of: app)

        toggle("demo_post_removed", in: app).tap()
        waitForDisappearance(of: unavailable)
        XCTAssertTrue(app.buttons["savedPosts.post.demo_post_1"].exists)
        XCTAssertTrue(app.buttons["savedPosts.post.demo_post_2"].exists)
    }

    func testTappingASavedPostOpensItsPieces() {
        let app = launchOOTD(["-seedSavedPosts"])
        openSavedPosts(in: app)

        let card = app.buttons["savedPosts.post.demo_post_2"]
        XCTAssertTrue(card.waitForExistence(timeout: 10))
        card.tap()
        XCTAssertTrue(app.staticTexts["White shirt"].waitForExistence(timeout: 5))
    }

    func testFailedSaveGoesBackToSaveAndCanBeRetried() {
        let app = launchOOTD(["-resetSavedPosts", "-failNextSavedPostWrite"])
        let feedToggle = toggle("demo_post_1", in: app)
        XCTAssertTrue(feedToggle.waitForExistence(timeout: 10))
        wait(for: feedToggle, value: "Not saved")

        feedToggle.tap()
        let error = app.staticTexts["Couldn't save. Try again."]
        XCTAssertTrue(error.waitForExistence(timeout: 10))
        XCTAssertEqual(feedToggle.value as? String, "Not saved")
        XCTAssertTrue(feedToggle.isEnabled)
        attachScreenshot("OOTD card, save failed", of: app)

        feedToggle.tap()
        wait(for: feedToggle, value: "Saved")
        XCTAssertFalse(error.exists)
    }

    func testFailedFirstLoadOffersRetryInsteadOfAnEmptyList() {
        // The first read is the feed's and the second is the Saved screen's.
        let app = launchOOTD(["-seedSavedPosts", "-failSavedPostReads", "1,2"])
        openSavedPosts(in: app)

        let retry = app.buttons["feedStatus.retry"]
        XCTAssertTrue(retry.waitForExistence(timeout: 10))
        XCTAssertFalse(app.staticTexts["No saved posts yet"].exists)
        attachScreenshot("Saved posts, first load failed", of: app)

        retry.tap()
        XCTAssertTrue(app.buttons["savedPosts.post.demo_post_1"].waitForExistence(timeout: 10))
    }

    func testFailedRefreshKeepsTheGridAndOffersRetry() {
        // The feed's read succeeds; the Saved screen's refresh is the one that fails.
        let app = launchOOTD(["-seedSavedPosts", "-failSavedPostReads", "2"])
        let feedToggle = toggle("demo_post_1", in: app)
        XCTAssertTrue(feedToggle.waitForExistence(timeout: 10))
        wait(for: feedToggle, value: "Saved")
        openSavedPosts(in: app)

        let retry = app.buttons["savedPosts.retry"]
        XCTAssertTrue(retry.waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["savedPosts.post.demo_post_1"].exists)
        // Above the scroll view, the banner hides the large title, though the title still reports as
        // hittable. So this checks where the banner is rather than the title.
        XCTAssertTrue(app.scrollViews["savedPosts.content"].buttons["savedPosts.retry"].exists)
        attachScreenshot("Saved posts, refresh failed", of: app)

        retry.tap()
        waitForDisappearance(of: retry)
        XCTAssertTrue(app.buttons["savedPosts.post.demo_post_1"].exists)
    }
}
