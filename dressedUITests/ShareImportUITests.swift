import XCTest

/// The camera is full screen with no tab bar; close it first when a test launched into it.
private func openCloset(in app: XCUIApplication) {
    let close = app.buttons["camera.close"]
    if close.waitForExistence(timeout: 2) { close.tap() }
    app.buttons["tab.closet"].tap()
}

final class ShareImportUITests: XCTestCase {
    func testSingleDiscoveryHeaderSwitchesFeedLayouts() {
        let app = XCUIApplication()
        app.launchArguments = ["-mockSignedIn", "-skipDemoCloset", "-showDiscovery"]
        app.launch()

        let forYou = app.buttons["For You"]
        let friends = app.buttons["Friends"]
        XCTAssertTrue(app.buttons["infinite.post.infinite_0"].waitForExistence(timeout: 10))
        XCTAssertEqual(app.buttons.matching(identifier: "For You").count, 1)
        XCTAssertEqual(app.buttons.matching(identifier: "Friends").count, 1)
        XCTAssertFalse(app.segmentedControls["infinite.sections"].exists)
        XCTAssertTrue(forYou.isSelected)
        let gridScreenshot = XCTAttachment(screenshot: app.screenshot())
        gridScreenshot.name = "Single header - For You outfit grid"
        gridScreenshot.lifetime = .keepAlways
        add(gridScreenshot)

        friends.tap()
        XCTAssertTrue(app.descendants(matching: .any)["infinite.card.infinite_0"].firstMatch.waitForExistence(timeout: 5))
        XCTAssertTrue(friends.isSelected)
        XCTAssertFalse(app.buttons["infinite.post.infinite_0"].exists)
        let friendsScreenshot = XCTAttachment(screenshot: app.screenshot())
        friendsScreenshot.name = "Single header - Friends outfit cards"
        friendsScreenshot.lifetime = .keepAlways
        add(friendsScreenshot)

        forYou.tap()
        XCTAssertTrue(app.buttons["infinite.post.infinite_0"].waitForExistence(timeout: 5))
        XCTAssertTrue(forYou.isSelected)
    }

    func testCommentsSubmitAndReopenFromBothFeedLayouts() {
        let app = XCUIApplication()
        app.launchArguments = ["-mockSignedIn", "-skipDemoCloset", "-showDiscovery"]
        app.launch()
        XCTAssertTrue(app.buttons["infinite.post.infinite_0"].waitForExistence(timeout: 10))
        app.buttons["infinite.post.infinite_0"].tap()
        app.buttons["infinite.comments.infinite_0"].tap()
        let input = app.textFields["comments.input"]
        // A vertically growing TextField is exposed as a text view on newer iOS.
        let editor = input.waitForExistence(timeout: 3) ? input : app.textViews["comments.input"]
        XCTAssertTrue(editor.waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["comments.send"].isEnabled)
        editor.tap()
        editor.typeText("Nice fit")
        app.buttons["comments.send"].tap()
        XCTAssertTrue(app.staticTexts["Nice fit"].waitForExistence(timeout: 5))
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Comments - submitted in preview"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        app.buttons["Close comments"].tap()
        app.buttons["Done"].tap()
        app.buttons["Friends"].tap()
        app.buttons["infinite.comments.infinite_0"].tap()
        XCTAssertTrue(app.staticTexts["Nice fit"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["Demo comments · saved only for this preview"].exists)
    }

    func testDiscoveryIdeasAndOOTDPostsAreSeparate() {
        let app = XCUIApplication()
        app.launchArguments = ["-mockSignedIn", "-skipDemoCloset", "-showDiscovery"]
        app.launch()

        XCTAssertTrue(app.buttons["discovery.idea.idea_top_1"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["ootd.post.demo_post_1"].exists)
        let discoveryScreenshot = XCTAttachment(screenshot: app.screenshot())
        discoveryScreenshot.name = "Discovery ideas"
        discoveryScreenshot.lifetime = .keepAlways
        add(discoveryScreenshot)

        app.buttons["Friends"].tap()
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
        app.launchArguments = ["-mockSignedIn", "-skipDemoCloset", "-showDiscovery", "-showOOTD"]
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

    func testNewPostRequiresPhotoAndItemsAndCanCancel() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-mockSignedIn", "-skipDemoCloset", "-showDiscovery", "-showOOTD"]
        app.launch()
        XCTAssertTrue(app.buttons["infinite.items.infinite_0"].waitForExistence(timeout: 15))
        app.buttons["ootd.createPost"].tapWhenStable()
        XCTAssertTrue(app.buttons["ootd.choosePhoto"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["ootd.sharePreview"].isEnabled)
        XCTAssertFalse(app.buttons["ootd.newPost.Audio"].exists)
        XCTAssertTrue(app.buttons["ootd.newPost.Outfit details"].exists)
        let caption = app.textFields["ootd.newPostCaption"]
        caption.tap()
        caption.typeText("Caption alone cannot create a post")
        XCTAssertFalse(app.buttons["ootd.sharePreview"].isEnabled)
        app.buttons["Back, New post"].tap()
        XCTAssertTrue(app.buttons["ootd.createPost"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["Caption alone cannot create a post"].exists)
    }

    /// `-importDemo` queues a generated flat-lay photo with three detected pieces.
    func testImportDemoFlowAcceptsTwoPiecesAndImportsAsOutfit() {
        let app = XCUIApplication()
        app.launchArguments = ["-mockSignedIn", "-skipDemoCloset", "-showCamera", "-importDemo"]
        app.launch()
        let option = app.buttons["sharedImport.option"]
        XCTAssertTrue(option.waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["1 of 3"].exists)
        XCTAssertTrue(app.buttons["sharedImport.skip"].exists)
        XCTAssertFalse(app.buttons["sharedImport.approve"].exists)
        let first = XCTAttachment(screenshot: app.screenshot())
        first.name = "Demo piece 1 browsing"; first.lifetime = .keepAlways; add(first)

        option.tap()
        let next = app.buttons["sharedImport.approve"]
        XCTAssertTrue(next.waitForExistence(timeout: 3))
        let chosen = XCTAttachment(screenshot: app.screenshot())
        chosen.name = "Demo piece 1 selected"; chosen.lifetime = .keepAlways; add(chosen)
        next.tap()

        XCTAssertTrue(app.staticTexts["2 of 3"].waitForExistence(timeout: 3))
        app.buttons["sharedImport.back"].tap()
        XCTAssertTrue(app.staticTexts["1 of 3"].waitForExistence(timeout: 3))
        option.tap()
        app.buttons["sharedImport.approve"].tap()
        XCTAssertTrue(app.staticTexts["2 of 3"].waitForExistence(timeout: 3))
        option.tap()
        app.buttons["sharedImport.approve"].tap()
        XCTAssertTrue(app.staticTexts["3 of 3"].waitForExistence(timeout: 3))
        app.buttons["sharedImport.skip"].tap()

        let confirm = app.buttons["sharedImport.confirm"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 3))
        XCTAssertTrue(confirm.isEnabled)
        XCTAssertTrue(app.buttons["sharedImport.confirmIndividual"].exists)
        XCTAssertTrue(app.buttons["sharedImport.findMore"].exists)
        XCTAssertTrue(app.staticTexts["Brown Wool Sweater"].exists)
        XCTAssertTrue(app.staticTexts["Silver Pendant Necklace"].exists)
        XCTAssertFalse(app.staticTexts["Wide-Leg Jeans"].exists)
        let summary = XCTAttachment(screenshot: app.screenshot())
        summary.name = "Demo import summary"; summary.lifetime = .keepAlways; add(summary)
        confirm.tap()
        let dismissed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: confirm)
        XCTAssertEqual(XCTWaiter.wait(for: [dismissed], timeout: 10), .completed)
    }

    /// `-demoMatches` ranks the Debug demo catalog: each piece offers three similar products.
    func testPieceReviewOffersThreeMatchesAndChosenMatchNamesPiece() {
        let app = XCUIApplication()
        app.launchArguments = ["-mockSignedIn", "-skipDemoCloset", "-showCamera", "-importDemo", "-demoMatches"]
        app.launch()
        let match = app.buttons.matching(identifier: "sharedImport.match")
        XCTAssertTrue(match.firstMatch.waitForExistence(timeout: 15))
        XCTAssertEqual(match.count, 3)
        XCTAssertTrue(app.staticTexts["1 of 3"].exists)
        XCTAssertFalse(app.buttons["sharedImport.approve"].exists)
        let browsing = XCTAttachment(screenshot: app.screenshot())
        browsing.name = "Piece 1 with matches"; browsing.lifetime = .keepAlways; add(browsing)

        let title = match.element(boundBy: 0).staticTexts.element(boundBy: 0).label
        match.element(boundBy: 0).tap()
        XCTAssertTrue(match.element(boundBy: 0).isSelected)
        let selected = XCTAttachment(screenshot: app.screenshot())
        selected.name = "Piece 1 match selected"; selected.lifetime = .keepAlways; add(selected)
        app.buttons["sharedImport.approve"].tap()
        XCTAssertTrue(app.staticTexts["2 of 3"].waitForExistence(timeout: 3))
        app.buttons["sharedImport.skip"].tap()
        XCTAssertTrue(app.staticTexts["3 of 3"].waitForExistence(timeout: 3))
        app.buttons["sharedImport.skip"].tap()

        XCTAssertTrue(app.buttons["sharedImport.confirm"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts[title].exists, "The chosen match names the piece in the summary")
        let summary = XCTAttachment(screenshot: app.screenshot())
        summary.name = "Summary after match"; summary.lifetime = .keepAlways; add(summary)
    }

    func testReviewCloseAndSearchCloseControls() {
        let app = launchSharedFixture()
        let close = app.buttons["sharedImport.close"]
        // The same 50 pt control as the camera.
        XCTAssertEqual(close.frame.width, 50, accuracy: 1)
        XCTAssertEqual(close.frame.height, 50, accuracy: 1)
        XCTAssertEqual(close.frame.minX, 9, accuracy: 1)
        let piece = XCTAttachment(screenshot: app.screenshot())
        piece.name = "Piece close control"; piece.lifetime = .keepAlways; add(piece)

        app.buttons["sharedImport.findYourself"].tap()
        let searchClose = app.buttons["sharedImport.searchClose"]
        XCTAssertTrue(searchClose.waitForExistence(timeout: 5))
        XCTAssertTrue(app.textFields["sharedImport.search"].exists)
        XCTAssertFalse(app.buttons["Cancel"].exists)
        let search = XCTAttachment(screenshot: app.screenshot())
        search.name = "Search sheet"; search.lifetime = .keepAlways; add(search)
        searchClose.tap()
        XCTAssertTrue(app.staticTexts["1 of 3"].waitForExistence(timeout: 5))

        reviewNextPiece(in: app, approve: true)
        reviewNextPiece(in: app, approve: true)
        reviewNextPiece(in: app, approve: false)
        XCTAssertTrue(app.buttons["sharedImport.confirm"].waitForExistence(timeout: 5))
        let summary = XCTAttachment(screenshot: app.screenshot())
        summary.name = "Summary close control"; summary.lifetime = .keepAlways; add(summary)
        // One tap discards: no menu or confirmation, and nothing comes back after a relaunch.
        close.tap()
        XCTAssertTrue(close.waitForNonExistence(timeout: 5))
        XCTAssertFalse(app.buttons["Later"].exists)
        XCTAssertFalse(app.buttons["Discard Image"].exists)
        app.terminate()
        app.launchArguments = ["-mockSignedIn", "-skipDemoCloset", "-showCamera"]
        app.launch()
        XCTAssertTrue(app.buttons["camera.close"].waitForExistence(timeout: 10))
        XCTAssertFalse(close.waitForExistence(timeout: 3))
    }

    /// Real photo through the real parsing model. Set TEST_RUNNER_CLOTHES_MODEL_PATH and
    /// TEST_RUNNER_CLOTHES_PHOTO_PATH; TEST_RUNNER_CATALOG_PACK_PATH also shows catalog matches.
    func testParsedPhotoPiecesImportAsCutouts() throws {
        let environment = ProcessInfo.processInfo.environment
        guard let model = environment["CLOTHES_MODEL_PATH"], let photo = environment["CLOTHES_PHOTO_PATH"] else {
            throw XCTSkip("No parsing model configured")
        }
        let app = XCUIApplication()
        app.launchArguments = ["-mockSignedIn", "-skipDemoCloset", "-showCamera",
                               "-clothesModelPath", model, "-importPhoto", photo]
        if let pack = environment["CATALOG_PACK_PATH"] {
            app.launchArguments += ["-demoMatches", "-catalogPackPath", pack]
        }
        app.launch()
        XCTAssertTrue(app.buttons["sharedImport.close"].waitForExistence(timeout: 10))
        let skip = app.buttons["sharedImport.skip"]
        XCTAssertTrue(skip.waitForExistence(timeout: 90))
        var reviewed = 0
        while skip.waitForExistence(timeout: 5), reviewed < 8 {
            reviewed += 1
            let match = app.buttons["sharedImport.match"].firstMatch
            let own = app.buttons["sharedImport.option"]
            if environment["CATALOG_PACK_PATH"] != nil {
                XCTAssertTrue(match.waitForExistence(timeout: 90))
            } else {
                XCTAssertTrue(own.waitForExistence(timeout: 10))
            }
            let browsing = XCTAttachment(screenshot: app.screenshot())
            browsing.name = "Parsed piece \(reviewed)"; browsing.lifetime = .keepAlways; add(browsing)
            (match.exists ? match : own).tap()
            let next = app.buttons["sharedImport.approve"]
            XCTAssertTrue(next.waitForExistence(timeout: 5))
            next.tap()
        }
        XCTAssertGreaterThanOrEqual(reviewed, 2)
        let confirm = app.buttons["sharedImport.confirmIndividual"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 5))
        let summary = XCTAttachment(screenshot: app.screenshot())
        summary.name = "Parsed summary"; summary.lifetime = .keepAlways; add(summary)
        confirm.tap()
        openCloset(in: app)
        let closet = XCTAttachment(screenshot: app.screenshot())
        closet.name = "Parsed closet"; closet.lifetime = .keepAlways; add(closet)
    }

    func testInterruptedSharedDraftRestartsAndKeepsManualSelectionAfterRelaunch() {
        let app = XCUIApplication()
        let suffix = String(UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(12))
        app.launchArguments = ["-mockSignedIn", "-skipDemoCloset", "-showCamera", "-seedShareFixture",
                               "00000000-0000-4000-8000-\(suffix)",
                               "-seedInterruptedManual", "-delaySharedRecognition"]
        app.launch()
        XCTAssertTrue(app.buttons["sharedImport.close"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Finding possible pieces…"].waitForExistence(timeout: 5))
        app.terminate()

        // Do not reseed or delay on return. The app must load the persisted
        // processing draft and run its real on-device recognition service.
        app.launchArguments = ["-mockSignedIn", "-skipDemoCloset", "-showCamera"]
        app.launch()
        XCTAssertTrue(app.buttons["sharedImport.close"].waitForExistence(timeout: 10))
        let completed = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == false"),
            object: app.staticTexts["Finding possible pieces…"])
        XCTAssertEqual(XCTWaiter.wait(for: [completed], timeout: 30), .completed)
        XCTAssertTrue(app.staticTexts["Manual scarf"].exists,
                      "Recognition must merge without losing the manual piece")
        XCTAssertEqual(app.staticTexts.matching(identifier: "Manual scarf").count, 1)
        XCTAssertTrue(app.buttons["sharedImport.confirm"].isEnabled)

        app.terminate()
        app.launch()
        XCTAssertTrue(app.buttons["sharedImport.findMore"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Manual scarf"].exists)
        app.buttons["sharedImport.close"].tap()
    }

    func testOnDeviceBenchmarkCompletesAndShowsMeasuredResults() {
        let app = XCUIApplication()
        app.launchArguments = ["-recognitionLab", "-syntheticRecognition", "-runRecognitionBenchmark"]
        app.launch()
        XCTAssertTrue(app.navigationBars["On-device speed test"].waitForExistence(timeout: 10))
        let progress = app.staticTexts["recognition.progress"]
        for _ in 0..<3 where !progress.isHittable { app.collectionViews.firstMatch.swipeUp() }
        let finished = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label BEGINSWITH 'Finished'"), object: progress)
        XCTAssertEqual(XCTWaiter.wait(for: [finished], timeout: 90), .completed)
        let medians = app.staticTexts.containing(NSPredicate(format: "label CONTAINS 'ms median'"))
        for _ in 0..<6 where medians.count < 2 {
            app.collectionViews.firstMatch.swipeUp(velocity: .slow)
        }
        XCTAssertEqual(medians.count, 2)
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    func testOnDeviceBenchmarkCancellationKeepsControlsUsable() {
        let app = XCUIApplication()
        app.launchArguments = ["-recognitionLab", "-syntheticRecognition", "-runRecognitionBenchmark", "-benchmarkRepeats", "5"]
        app.launch()
        let stop = app.buttons["Stop comparison"]
        for _ in 0..<3 where !stop.isHittable { app.collectionViews.firstMatch.swipeUp() }
        XCTAssertTrue(stop.waitForExistence(timeout: 10))
        stop.tap()
        let progress = app.staticTexts["recognition.progress"]
        let stopped = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label BEGINSWITH 'Stopped'"), object: progress)
        XCTAssertEqual(XCTWaiter.wait(for: [stopped], timeout: 30), .completed)
        XCTAssertTrue(app.buttons["Run comparison"].isEnabled)
    }

    func testReviewProductURLAndKeepWishlistAfterRelaunch() {
        let app = XCUIApplication()
        let suffix = String(UUID().uuidString.prefix(8))
        let title = "Blue merino sweater \(suffix)"
        app.launchArguments = ["-mockSignedIn", "-skipDemoCloset", "-showCamera"]
        app.launch()

        // A prior interrupted shared-image check can leave a queued draft.
        if app.navigationBars["Review Shared Image"].waitForExistence(timeout: 2) {
            app.buttons["Later"].tap()
        }

        app.buttons["Upload"].tap()
        app.buttons["Product Link"].tap()
        // Alert text fields do not keep their accessibility identifier, so find the field inside the alert.
        let url = app.alerts.textFields.firstMatch
        XCTAssertTrue(url.waitForExistence(timeout: 5))
        url.typeText("https://www.uniqlo.com/us/en/products/E469395-000/00?test=\(suffix)")
        app.alerts.buttons["Review Product Link"].tap()

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

        openCloset(in: app)
        let wishlist = app.buttons["Wishlist"]
        XCTAssertTrue(wishlist.waitForExistence(timeout: 5))
        wishlist.tap()
        XCTAssertTrue(app.staticTexts[title].waitForExistence(timeout: 5))

        app.terminate()
        app.launchArguments = ["-mockSignedIn", "-skipDemoCloset"]
        app.launch()
        if app.navigationBars["Review Shared Image"].waitForExistence(timeout: 2) {
            app.buttons["Later"].tap()
        }
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
        // With no detections, the whole photo is offered as one framed piece; skip it to add a piece by hand.
        XCTAssertTrue(app.staticTexts["1 of 1"].waitForExistence(timeout: 30))
        reviewNextPiece(in: app, approve: false)
        XCTAssertTrue(app.staticTexts["No pieces selected. Use Back to review them again or Find More to add one."]
            .waitForExistence(timeout: 5))
        addManualPiece(in: app)
        let confirm = app.buttons["sharedImport.confirm"]
        reveal(confirm, in: app)
        confirm.tap()
        openCloset(in: app)
        // Closet pieces are buttons labeled with the piece name.
        XCTAssertTrue(app.buttons["Piece"].firstMatch.waitForExistence(timeout: 5))
    }

    func testAddManualPieceAlongsideAutomaticSuggestions() {
        let app = launchSharedFixture()
        reviewNextPiece(in: app, approve: true)
        reviewNextPiece(in: app, approve: false)
        reviewNextPiece(in: app, approve: false)
        addManualPiece(in: app)
        XCTAssertTrue(app.staticTexts["Top"].exists)
        XCTAssertTrue(app.staticTexts["Piece"].exists)
        let confirm = app.buttons["sharedImport.confirm"]
        reveal(confirm, in: app)
        confirm.tap()
        openCloset(in: app)
        XCTAssertTrue(app.buttons["Piece"].firstMatch.waitForExistence(timeout: 5))
    }

    func testApproveSkipShowsOnlyApprovedPiecesAndBackRevisits() {
        let app = launchSharedFixture()
        reviewNextPiece(in: app, approve: true)
        reviewNextPiece(in: app, approve: false)
        app.buttons["sharedImport.back"].tap()
        XCTAssertTrue(app.staticTexts["2 of 3"].waitForExistence(timeout: 3))
        reviewNextPiece(in: app, approve: false)
        reviewNextPiece(in: app, approve: false)
        XCTAssertTrue(app.buttons["sharedImport.confirm"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Top"].exists)
        XCTAssertFalse(app.staticTexts["Pants"].exists)
        XCTAssertFalse(app.staticTexts["Hat"].exists)
    }

    func testReviewSelectTwoSkipOneSaveOutfitAndReopen() {
        let app = launchSharedFixture()
        reviewNextPiece(in: app, approve: true)
        reviewNextPiece(in: app, approve: true)
        reviewNextPiece(in: app, approve: false)
        let confirm = app.buttons["sharedImport.confirm"]
        reveal(confirm, in: app)
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Reviewed import confirmation"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        confirm.tap()
        openCloset(in: app)
        app.buttons["closet.filter.Outfits"].tap()
        let outfit = app.buttons.matching(NSPredicate(format: "label == %@", "Shared outfit")).firstMatch
        XCTAssertTrue(outfit.waitForExistence(timeout: 5))
        app.terminate()
        app.launchArguments = ["-mockSignedIn", "-skipDemoCloset"]
        app.launch()
        app.buttons["closet.filter.Outfits"].tap()
        XCTAssertTrue(outfit.waitForExistence(timeout: 5))
    }

    func testRelaunchRestoresProgressAndIndividualImport() {
        let app = launchSharedFixture()
        reviewNextPiece(in: app, approve: true)
        XCTAssertTrue(app.descendants(matching: .any)["sharedImport.selectedPreview"].waitForExistence(timeout: 3))
        app.terminate()
        app.launchArguments = ["-mockSignedIn", "-skipDemoCloset", "-showCamera"]
        app.launch()
        XCTAssertTrue(app.staticTexts["2 of 3"].waitForExistence(timeout: 10), "Review resumes at the second piece")
        reviewNextPiece(in: app, approve: false)
        reviewNextPiece(in: app, approve: false)
        let individual = app.buttons["sharedImport.confirmIndividual"]
        XCTAssertTrue(individual.waitForExistence(timeout: 3))
        individual.tap()
        openCloset(in: app)
        XCTAssertTrue(app.buttons["Top"].firstMatch.waitForExistence(timeout: 5))
    }

    private func launchSharedFixture(withCandidates: Bool = true) -> XCUIApplication {
        let app = XCUIApplication()
        let suffix = String(UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(12))
        app.launchArguments = ["-mockSignedIn", "-skipDemoCloset", "-showCamera", "-seedShareFixture",
                               "00000000-0000-4000-8000-\(suffix)"]
        if withCandidates { app.launchArguments.append("-seedTwoCandidates") }
        app.launch()
        XCTAssertTrue(app.buttons["sharedImport.close"].waitForExistence(timeout: 10))
        return app
    }

    private func reviewNextPiece(in app: XCUIApplication, approve: Bool) {
        if approve {
            let option = app.buttons["sharedImport.option"]
            XCTAssertTrue(option.waitForExistence(timeout: 5))
            option.tap()
        }
        let button = app.buttons[approve ? "sharedImport.approve" : "sharedImport.skip"]
        XCTAssertTrue(button.waitForExistence(timeout: 5))
        XCTAssertTrue(button.isEnabled)
        button.tap()
    }

    /// Find More on the summary: add a region. The new piece is named "Piece".
    private func addManualPiece(in app: XCUIApplication) {
        let more = app.buttons["sharedImport.findMore"]
        reveal(more, in: app)
        more.tap()
        XCTAssertTrue(app.navigationBars["Adjust Image Region"].waitForExistence(timeout: 5))
        app.buttons["Use Region"].tap()
        XCTAssertTrue(app.buttons["sharedImport.findMore"].waitForExistence(timeout: 5))
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

/// Isolated fixture coverage; this does not verify Firebase authentication.
final class InfiniteFeedUITests: XCTestCase {
    func testAutomaticPagingPausesOnFailureAndRetries() {
        let app = XCUIApplication()
        app.launchArguments = ["-mockSignedIn", "-skipDemoCloset", "-showDiscovery", "-failDiscoveryPage"]
        app.launch()
        XCTAssertTrue(app.buttons["infinite.post.infinite_0"].waitForExistence(timeout: 5))
        let retry = app.buttons["infinite.retry"]
        XCTAssertFalse(retry.exists)
        let friends = app.buttons["Friends"]
        XCTAssertTrue(friends.exists)
        friends.tap()
        XCTAssertTrue(app.descendants(matching: .any)["infinite.card.infinite_0"].firstMatch.waitForExistence(timeout: 5))
        XCTAssertFalse(retry.exists)
        app.buttons["For You"].tap()
        let feed = app.scrollViews["infinite.scroll"]
        for _ in 0..<8 {
            if retry.isHittable { break }
            feed.swipeUp()
        }
        XCTAssertTrue(retry.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["infinite.post.infinite_11"].exists)
        XCTAssertFalse(app.buttons["infinite.post.infinite_12"].exists)
        retry.tap()
        XCTAssertTrue(app.buttons["infinite.post.infinite_12"].waitForExistence(timeout: 5))
        XCTAssertFalse(retry.exists)
        for _ in 0..<30 {
            if app.staticTexts["infinite.end"].isHittable { break }
            feed.swipeUp()
        }
        XCTAssertTrue(app.staticTexts["infinite.end"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["infinite.post.infinite_47"].exists)
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Infinite feed reached last fixture page"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
