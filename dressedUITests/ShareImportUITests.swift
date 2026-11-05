import XCTest

final class ShareImportUITests: XCTestCase {
    func testInterruptedSharedDraftRestartsAndKeepsManualSelectionAfterRelaunch() {
        let app = XCUIApplication()
        let suffix = String(UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(12))
        app.launchArguments = ["-mockSignedIn", "-showCamera", "-seedShareFixture",
                               "00000000-0000-4000-8000-\(suffix)",
                               "-seedInterruptedManual", "-delaySharedRecognition"]
        app.launch()
        XCTAssertTrue(app.navigationBars["Review Shared Image"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Finding possible pieces…"].waitForExistence(timeout: 5))
        app.terminate()

        // Do not reseed or delay on return. The app must load the persisted
        // processing draft and run its real on-device recognition service.
        app.launchArguments = ["-mockSignedIn", "-showCamera"]
        app.launch()
        XCTAssertTrue(app.navigationBars["Review Shared Image"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["Find Pieces Again"].waitForExistence(timeout: 30))
        let manual = app.buttons["Manual scarf"]
        for _ in 0..<6 where !manual.isHittable { app.collectionViews.firstMatch.swipeUp() }
        XCTAssertTrue(manual.exists)
        XCTAssertEqual(manual.value as? String, "Selected")
        let count = app.staticTexts["1 of 2 pieces selected"]
        for _ in 0..<4 where !count.isHittable { app.collectionViews.firstMatch.swipeUp() }
        XCTAssertTrue(count.exists, "Recognition must merge without losing or duplicating the manual piece")
        let save = app.buttons["Save Pieces and Outfit"]
        for _ in 0..<3 where !save.isHittable { app.collectionViews.firstMatch.swipeUp() }
        XCTAssertTrue(save.isEnabled)

        app.terminate()
        app.launch()
        XCTAssertTrue(app.navigationBars["Review Shared Image"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["Find Pieces Again"].waitForExistence(timeout: 10))
        for _ in 0..<6 where !manual.isHittable { app.collectionViews.firstMatch.swipeUp() }
        XCTAssertEqual(manual.value as? String, "Selected")
        for _ in 0..<4 where !count.isHittable { app.collectionViews.firstMatch.swipeUp() }
        XCTAssertTrue(count.exists)
        app.buttons["Discard"].tap()
        app.buttons["Discard Image"].tap()
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
        for _ in 0..<4 where !app.staticTexts["Measured wall time"].isHittable {
            app.collectionViews.firstMatch.swipeUp()
        }
        XCTAssertTrue(app.staticTexts["Measured wall time"].exists)
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS 'ms median'")).count >= 2)
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
        app.launchArguments = ["-mockSignedIn", "-showCamera"]
        app.launch()

        // A prior interrupted shared-image check can leave a queued draft.
        if app.navigationBars["Review Shared Image"].waitForExistence(timeout: 2) {
            app.buttons["Later"].tap()
        }

        let url = app.textFields["productURLField"]
        XCTAssertTrue(url.waitForExistence(timeout: 10))
        url.tap()
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
        if app.navigationBars["Review Shared Image"].waitForExistence(timeout: 2) {
            app.buttons["Later"].tap()
        }
        XCTAssertTrue(wishlist.waitForExistence(timeout: 5))
        wishlist.tap()
        XCTAssertTrue(app.staticTexts[title].waitForExistence(timeout: 5))
    }

    func testAddManualPieceAlongsideAutomaticSuggestions() {
        let app = XCUIApplication()
        let suffix = String(UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(12))
        let pieceName = "Blue sweater \(suffix)"
        app.launchArguments = ["-mockSignedIn", "-showCamera", "-seedShareFixture",
                               "00000000-0000-4000-8000-\(suffix)"]
        app.launch()

        XCTAssertTrue(app.navigationBars["Review Shared Image"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["Find Pieces Again"].waitForExistence(timeout: 30))
        XCTAssertFalse(app.staticTexts["Finding possible pieces…"].exists)
        app.buttons["Add Piece Manually"].tap()
        XCTAssertTrue(app.navigationBars["Adjust Image Region"].waitForExistence(timeout: 5))
        app.buttons["Use Region"].tap()

        // SwiftUI lazily loads rows; a count taken before scrolling can select
        // the automatic suggestion instead of the newly added empty manual field.
        let name = app.textFields.matching(identifier: "Piece name")
            .matching(NSPredicate(format: "value == nil OR value == '' OR value == 'Piece name'"))
            .firstMatch
        for _ in 0..<5 where !name.isHittable {
            app.collectionViews.firstMatch.swipeUp()
        }
        XCTAssertTrue(name.isHittable)
        name.tap()
        name.typeText(pieceName)
        app.buttons[pieceName].tap()
        app.keyboards.buttons["return"].tap()
        app.collectionViews.firstMatch.swipeUp()
        app.buttons["Save Pieces and Outfit"].tap()

        app.buttons["My Closet"].tap()
        XCTAssertTrue(app.staticTexts[pieceName].waitForExistence(timeout: 5))
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
        for _ in 0..<3 where !topName.isHittable { app.collectionViews.firstMatch.swipeUp() }
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
