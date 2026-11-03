import XCTest

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
