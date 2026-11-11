import XCTest

final class ShareImportUITests: XCTestCase {
    func testDiscoveryStyleSearchMatchesPrototype() {
        let app = XCUIApplication()
        app.launchArguments = ["-mockSignedIn", "-showDiscovery"]
        app.launch()

        let search = app.textFields["searchField.textField"]
        XCTAssertTrue(search.waitForExistence(timeout: 10))
        search.tap()
        XCTAssertTrue(app.buttons["discovery.style.select.Y2K"].waitForExistence(timeout: 5))
        app.buttons["discovery.style.select.Y2K"].tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["discovery.style.remove.Y2K"].exists)
        XCTAssertTrue(app.buttons["discovery.style.select.Comfortable"].exists)
        XCTAssertTrue(app.buttons["discovery.showResults"].exists)

        let focusedScreenshot = XCTAttachment(screenshot: app.screenshot())
        focusedScreenshot.name = "Discovery focused style search"
        focusedScreenshot.lifetime = .keepAlways
        add(focusedScreenshot)

        app.buttons["discovery.showResults"].tap()
        XCTAssertTrue(app.buttons["discovery.idea.idea_top_1"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["discovery.idea.idea_shoes_1"].exists)
        XCTAssertFalse(app.buttons["discovery.idea.idea_pants_1"].exists)
    }

    func testDiscoveryIdeasAndOOTDPostsAreSeparate() {
        let app = XCUIApplication()
        app.launchArguments = ["-mockSignedIn", "-showDiscovery"]
        app.launch()

        XCTAssertTrue(app.buttons["discovery.idea.idea_top_1"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["ootd.post.demo_post_1"].exists)
        let discoveryScreenshot = XCTAttachment(screenshot: app.screenshot())
        discoveryScreenshot.name = "Discovery ideas"
        discoveryScreenshot.lifetime = .keepAlways
        add(discoveryScreenshot)

        app.segmentedControls.buttons["OOTD"].tap()
        XCTAssertTrue(app.buttons["ootd.findItems.demo_post_1"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["discovery.idea.idea_top_1"].exists)
        let ootdScreenshot = XCTAttachment(screenshot: app.screenshot())
        ootdScreenshot.name = "OOTD posts"
        ootdScreenshot.lifetime = .keepAlways
        add(ootdScreenshot)

        app.buttons["ootd.pin.demo_post_1.0"].tap()
        let selectedPin = NSPredicate(format: "value == %@", "Selected")
        expectation(for: selectedPin, evaluatedWith: app.buttons["ootd.pin.demo_post_1.0"])
        waitForExpectations(timeout: 5)
        app.buttons["ootd.like.demo_post_1"].tap()
        XCTAssertTrue(app.buttons["ootd.like.demo_post_1"].label.contains("Unlike"))
        XCTAssertFalse(app.navigationBars["Post"].exists)

        app.buttons["ootd.comments.demo_post_1"].tap()
        let comment = app.textFields["ootd.commentInput"]
        XCTAssertTrue(comment.waitForExistence(timeout: 5))
        comment.tap()
        comment.typeText("Nice fit")
        app.buttons["ootd.sendComment"].tap()
        XCTAssertTrue(app.staticTexts["Nice fit"].waitForExistence(timeout: 5))
        app.buttons["Close comments"].tap()
        XCTAssertTrue(app.buttons["ootd.comments.demo_post_1"].label.contains("3"))
        app.buttons["ootd.findItems.demo_post_1"].tap()
        XCTAssertTrue(app.staticTexts["Vintage leather jacket"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Oversized moto jacket"].exists)
    }

    func testOOTDItemsSheetMatchesPrototype() {
        let app = XCUIApplication()
        app.launchArguments = ["-mockSignedIn", "-showDiscovery", "-showOOTD"]
        app.launch()

        let findItems = app.buttons["ootd.findItems.demo_post_1"]
        XCTAssertTrue(findItems.waitForExistence(timeout: 10))
        findItems.tap()
        XCTAssertTrue(app.staticTexts["Vintage leather jacket"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Arlo & Finch"].exists)
        XCTAssertTrue(app.staticTexts["$189"].exists)
        XCTAssertTrue(app.staticTexts["Verified by creator"].exists)
        XCTAssertTrue(app.buttons["ootd.category.All"].exists)
        XCTAssertTrue(app.buttons["ootd.category.Jacket"].exists)
        let itemsScreenshot = XCTAttachment(screenshot: app.screenshot())
        itemsScreenshot.name = "OOTD Find items sheet"
        itemsScreenshot.lifetime = .keepAlways
        add(itemsScreenshot)

        let save = app.buttons["ootd.saveItem.jacket-1"]
        save.tap()
        let savedLabel = NSPredicate(format: "label BEGINSWITH %@", "Saved ")
        expectation(for: savedLabel, evaluatedWith: save)
        waitForExpectations(timeout: 5)
        app.buttons["ootd.itemsSort"].tap()
        app.buttons["Price: Low to high"].tap()
        XCTAssertTrue(app.buttons["ootd.itemsSort"].label.contains("Price: Low to high"))
        app.buttons["ootd.category.Pants"].tap()
        XCTAssertTrue(app.staticTexts["Pleated wool trousers"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["Vintage leather jacket"].exists)
        app.buttons["ootd.category.Jacket"].tap()
        XCTAssertFalse(app.staticTexts["Pleated wool trousers"].exists)
        XCTAssertTrue(app.staticTexts["Washed suede bomber"].exists)
    }

    func testOOTDCreatePostPreviewStaysInFeed() {
        let app = XCUIApplication()
        app.launchArguments = ["-mockSignedIn", "-showDiscovery", "-showOOTD"]
        app.launch()

        XCTAssertTrue(app.buttons["ootd.createPost"].waitForExistence(timeout: 10))
        app.buttons["ootd.createPost"].tap()
        XCTAssertTrue(app.staticTexts["New post"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.images["Outfit preview image"].exists)
        XCTAssertTrue(app.buttons["ootd.newPost.Audio"].exists)
        XCTAssertTrue(app.buttons["ootd.newPost.Outfit details"].exists)
        XCTAssertTrue(app.tabBars.buttons["Discovery"].exists)
        let createScreenshot = XCTAttachment(screenshot: app.screenshot())
        createScreenshot.name = "New post creation"
        createScreenshot.lifetime = .keepAlways
        add(createScreenshot)

        app.buttons["Back"].tap()
        XCTAssertTrue(app.buttons["ootd.createPost"].waitForExistence(timeout: 5))
        app.buttons["ootd.createPost"].tap()
        let caption = app.textFields["ootd.newPostCaption"]
        XCTAssertTrue(caption.waitForExistence(timeout: 5))
        caption.tap()
        caption.typeText("New fit")
        app.buttons["ootd.sharePreview"].tap()
        XCTAssertTrue(app.staticTexts["New fit"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.navigationBars["Post"].exists)
    }

    func testReviewProductURLAndKeepWishlistAfterRelaunch() {
        let app = XCUIApplication()
        let suffix = String(UUID().uuidString.prefix(8))
        let title = "Blue merino sweater \(suffix)"
        app.launchArguments = ["-mockSignedIn", "-showCamera"]
        app.launch()

        let url = app.textFields["productURLField"]
        XCTAssertTrue(url.waitForExistence(timeout: 10))
        for _ in 0..<5 where !url.isHittable {
            app.scrollViews.firstMatch.swipeUp()
        }
        XCTAssertTrue(url.isHittable)
        url.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        url.typeText("https://www.uniqlo.com/us/en/products/E469395-000/00?test=\(suffix)")
        app.keyboards.buttons["Done"].tap()
        app.buttons["Review Product Link"].tap()

        XCTAssertTrue(app.navigationBars["Review Product Link"].waitForExistence(timeout: 5))
        let reviewScreenshot = XCTAttachment(screenshot: app.screenshot())
        reviewScreenshot.name = "Product-link review"
        reviewScreenshot.lifetime = .keepAlways
        add(reviewScreenshot)
        let name = app.textFields["Product name"]
        name.tap()
        name.typeText(title)
        app.keyboards.buttons["Done"].tap()
        let confirmation = app.switches["Save this link to my Wishlist"]
        confirmation.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
        XCTAssertEqual(confirmation.value as? String, "1")
        let save = app.buttons["Save to Wishlist"]
        XCTAssertTrue(save.isEnabled)
        save.tap()
        let reviewDismissed = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == false"),
            object: app.navigationBars["Review Product Link"]
        )
        XCTAssertEqual(XCTWaiter.wait(for: [reviewDismissed], timeout: 5), .completed)

        app.buttons["My Closet"].tap()
        let wishlist = app.buttons["Wishlist"]
        XCTAssertTrue(wishlist.waitForExistence(timeout: 5))
        wishlist.tap()
        XCTAssertTrue(app.staticTexts[title].waitForExistence(timeout: 5))

        app.terminate()
        app.launchArguments = ["-mockSignedIn"]
        app.launch()
        XCTAssertTrue(wishlist.waitForExistence(timeout: 5))
        wishlist.tap()
        XCTAssertTrue(app.staticTexts[title].waitForExistence(timeout: 5))
        let savedScreenshot = XCTAttachment(screenshot: app.screenshot())
        savedScreenshot.name = "Wishlist item after relaunch"
        savedScreenshot.lifetime = .keepAlways
        add(savedScreenshot)
    }

    func testManualPieceWhenNoSuggestions() {
        let app = launchSharedFixture(withCandidates: false)
        XCTAssertTrue(app.staticTexts["No pieces found. Use Find more to add one with lasso, or try recognition again."].exists)
        app.buttons["sharedImport.findMore"].tap()
        XCTAssertTrue(app.navigationBars["Adjust Image Region"].waitForExistence(timeout: 5))
        app.buttons["Use Region"].tap()
        let name = app.textFields["Piece name"].firstMatch
        reveal(name, in: app)
        name.tap()
        name.typeText("Blue sweater")
        app.keyboards.buttons["return"].tap()
        reviewNextPiece(in: app, approve: true)
        let confirm = app.buttons["sharedImport.confirm"]
        reveal(confirm, in: app)
        confirm.tap()
        app.tabBars.buttons["My Closet"].tap()
        XCTAssertTrue(app.staticTexts["Blue sweater"].waitForExistence(timeout: 5))
    }

    func testApproveSkipThenChangeSelection() {
        let app = launchSharedFixture()
        reviewNextPiece(in: app, approve: true)
        reviewNextPiece(in: app, approve: false)
        reviewNextPiece(in: app, approve: false)
        let top = app.buttons["Top"]
        reveal(top, in: app)
        XCTAssertEqual(top.value as? String, "Selected")
        top.tap()
        XCTAssertEqual(top.value as? String, "Not selected")
        let pants = app.buttons["Pants"]
        reveal(pants, in: app)
        pants.tap()
        XCTAssertEqual(pants.value as? String, "Selected")
    }

    func testReviewSelectTwoSkipOneSaveOutfitAndReopen() {
        let app = launchSharedFixture()
        reviewNextPiece(in: app, approve: true)
        reviewNextPiece(in: app, approve: true)
        reviewNextPiece(in: app, approve: false)
        let outfitName = "Shared fixture \(UUID().uuidString.prefix(8))"
        let name = app.textFields["Outfit name"]
        reveal(name, in: app)
        replace(name, with: outfitName)
        app.keyboards.buttons["return"].tap()
        let confirm = app.buttons["sharedImport.confirm"]
        reveal(confirm, in: app)
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Reviewed import confirmation"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        confirm.tap()
        app.tabBars.buttons["My Closet"].tap()
        app.segmentedControls.buttons["Outfits"].tap()
        XCTAssertTrue(app.staticTexts[outfitName].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["2 pieces"].exists)
        app.terminate()
        app.launchArguments = ["-mockSignedIn"]
        app.launch()
        app.segmentedControls.buttons["Outfits"].tap()
        XCTAssertTrue(app.staticTexts[outfitName].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts.matching(identifier: outfitName).count, 1)
    }

    func testLaterRestoresProgressAndIndividualImport() {
        let app = launchSharedFixture()
        let uniqueName = "Reviewed shirt \(UUID().uuidString.prefix(8))"
        let name = app.textFields["Piece name"].firstMatch
        reveal(name, in: app)
        replace(name, with: uniqueName)
        app.keyboards.buttons["return"].tap()
        reviewNextPiece(in: app, approve: true)
        app.buttons["Later"].tap()
        app.tabBars.buttons["My Closet"].tap()
        XCTAssertFalse(app.staticTexts[uniqueName].exists)
        app.terminate()
        app.launchArguments = ["-mockSignedIn", "-showCamera"]
        app.launch()
        XCTAssertTrue(app.navigationBars["Review Shared Image"].waitForExistence(timeout: 10))
        XCTAssertEqual(app.textFields["Piece name"].firstMatch.value as? String, "Pants")
        reviewNextPiece(in: app, approve: false)
        reviewNextPiece(in: app, approve: false)
        let outfitName = app.textFields["Outfit name"]
        reveal(outfitName, in: app)
        replace(outfitName, with: uniqueName)
        app.keyboards.buttons["return"].tap()
        let mode = app.buttons["sharedImport.saveMode"]
        reveal(mode, in: app)
        mode.tap()
        app.buttons["As individual pieces"].tap()
        XCTAssertFalse(app.textFields["Outfit name"].exists)
        app.buttons["Later"].tap()
        app.buttons["Review Share"].tap()
        XCTAssertTrue(app.navigationBars["Review Shared Image"].waitForExistence(timeout: 5))
        let confirm = app.buttons["sharedImport.confirm"]
        reveal(confirm, in: app)
        XCTAssertEqual(confirm.label, "Import as individual pieces")
        confirm.tap()
        app.tabBars.buttons["My Closet"].tap()
        XCTAssertTrue(app.staticTexts[uniqueName].waitForExistence(timeout: 5))
        app.segmentedControls.buttons["Outfits"].tap()
        XCTAssertFalse(app.staticTexts[uniqueName].exists)
        app.terminate()
        app.launchArguments = ["-mockSignedIn"]
        app.launch()
        XCTAssertTrue(app.staticTexts[uniqueName].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts.matching(identifier: uniqueName).count, 1)
    }

    private func launchSharedFixture(withCandidates: Bool = true) -> XCUIApplication {
        let app = XCUIApplication()
        let suffix = String(UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(12))
        app.launchArguments = ["-mockSignedIn", "-showCamera", "-seedShareFixture",
                               "00000000-0000-4000-8000-\(suffix)"]
        if withCandidates { app.launchArguments.append("-seedTwoCandidates") }
        app.launch()
        XCTAssertTrue(app.navigationBars["Review Shared Image"].waitForExistence(timeout: 10))
        return app
    }

    private func reviewNextPiece(in app: XCUIApplication, approve: Bool) {
        let button = app.buttons[approve ? "sharedImport.approve" : "sharedImport.skip"]
        reveal(button, in: app)
        XCTAssertTrue(button.isEnabled)
        button.tap()
    }

    private func reveal(_ element: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<12 where !element.exists { app.swipeUp() }
        XCTAssertTrue(element.waitForExistence(timeout: 5))
        for _ in 0..<12 where !element.isHittable { app.swipeUp() }
        XCTAssertTrue(element.isHittable)
    }

    private func replace(_ field: XCUIElement, with value: String) {
        field.tap()
        let oldValue = field.value as? String ?? ""
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: oldValue.count) + value)
    }
}
