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
    }

    func testManualPieceWhenNoSuggestions() {
        let app = XCUIApplication()
        let suffix = String(UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(12))
        app.launchArguments = ["-mockSignedIn", "-showCamera", "-seedShareFixture",
                               "00000000-0000-4000-8000-\(suffix)"]
        app.launch()

        XCTAssertTrue(app.navigationBars["Review Shared Image"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.staticTexts["Finding possible pieces…"].exists)
        app.buttons["Add Piece Manually"].tap()
        XCTAssertTrue(app.navigationBars["Adjust Image Region"].waitForExistence(timeout: 5))
        app.buttons["Use Region"].tap()

        let name = app.textFields["Piece name"].firstMatch
        for _ in 0..<8 where !name.isHittable {
            app.swipeUp()
        }
        XCTAssertTrue(name.isHittable)
        name.tap()
        name.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: "Piece".count) + "Blue sweater")
        app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Blue sweater")).firstMatch.tap()
        app.keyboards.buttons["return"].tap()
        app.collectionViews.firstMatch.swipeUp()
        app.buttons["Save Pieces and Outfit"].tap()

        app.buttons["My Closet"].tap()
        XCTAssertTrue(app.staticTexts["Blue sweater"].waitForExistence(timeout: 5))
    }

    func testSelectTop() {
        let app = XCUIApplication()
        let suffix = String(UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(12))
        app.launchArguments = ["-mockSignedIn", "-showCamera", "-seedShareFixture",
                               "00000000-0000-4000-8000-\(suffix)", "-seedTwoCandidates"]
        app.launch()
        app.collectionViews.firstMatch.swipeUp()
        let top = app.buttons["Top"]
        XCTAssertTrue(top.waitForExistence(timeout: 10))
        top.tap()
        XCTAssertEqual(top.value as? String, "Selected")
        let topName = app.textFields["Piece name"].firstMatch
        topName.tap()
        topName.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 3) + "Blue top")
        XCTAssertEqual(topName.value as? String, "Blue top")
        let pants = app.buttons["Pants"]
        pants.tap()
        XCTAssertEqual(pants.value as? String, "Selected")
    }

    func testReviewSelectTwoSkipOneSaveOutfitAndReopen() {
        let app = XCUIApplication()
        let suffix = String(UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(12))
        let importID = "00000000-0000-4000-8000-\(suffix)"
        let outfitName = "Shared fixture \(suffix)"
        app.launchArguments = ["-mockSignedIn", "-showCamera", "-seedShareFixture",
                               importID, "-seedTwoCandidates"]
        app.launch()

        XCTAssertTrue(app.navigationBars["Review Shared Image"].waitForExistence(timeout: 10))
        app.collectionViews.firstMatch.swipeUp()
        app.buttons["Top"].tap()
        let topName = app.textFields["Piece name"].firstMatch
        topName.tap()
        topName.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 3) + "Blue top")
        app.buttons["Pants"].tap()
        XCTAssertEqual(app.buttons["Hat"].value as? String, "Not selected")

        app.keyboards.buttons["return"].tap()
        for _ in 0..<5 { app.collectionViews.firstMatch.swipeUp() }
        let nameField = app.textFields["Outfit name"]
        nameField.tap()
        nameField.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: "Shared outfit".count) + outfitName)
        app.buttons["Save Pieces and Outfit"].tap()

        XCTAssertTrue(app.buttons["My Closet"].waitForExistence(timeout: 5))
        app.buttons["My Closet"].tap()
        app.segmentedControls.buttons["Outfits"].tap()
        XCTAssertTrue(app.staticTexts[outfitName].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["2 pieces"].exists)

        app.terminate()
        app.launchArguments = ["-mockSignedIn"]
        app.launch()
        app.segmentedControls.buttons["Outfits"].tap()
        XCTAssertTrue(app.staticTexts[outfitName].waitForExistence(timeout: 5))
    }
}
