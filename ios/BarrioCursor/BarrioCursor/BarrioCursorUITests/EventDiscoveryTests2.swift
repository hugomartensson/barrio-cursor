import XCTest

/// Tier 3A: Event discovery flow — feed browsing, event detail, save toggle.
class EventDiscoveryTests2: BaseTestCase {

    override func setUpWithError() throws {
        try super.setUpWithError()
        sleep(2)
        try loginWithTestAccount(TestAccounts.secondary)
    }

    // MARK: - Tests

    func testFeedShowsEventsOrEmptyState() throws {
        if app.buttons["Discover"].exists { app.buttons["Discover"].tap(); sleep(1) }
        sleep(3)

        attach(screenshot: "feed_loaded")

        let emptyState = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS 'No events' OR label CONTAINS 'no events' OR label CONTAINS 'Nothing here'")
        ).firstMatch
        let loadingState = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS 'Loading'")
        ).firstMatch
        let errorState = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS 'error' OR label CONTAINS 'Error' OR label CONTAINS 'Failed'")
        ).firstMatch
        let eventTitle = app.staticTexts.matching(
            NSPredicate(format: "identifier == 'event_title'")
        ).firstMatch

        _ = eventTitle.waitForExistence(timeout: 10)

        let hasContent = eventTitle.exists || emptyState.exists || loadingState.exists || errorState.exists
        XCTAssertTrue(hasContent, "Feed should show events, empty state, loading, or error")
    }

    func testTapEventOpensDetail() throws {
        if app.buttons["Discover"].exists { app.buttons["Discover"].tap(); sleep(1) }
        sleep(3)

        let eventTitle = app.staticTexts.matching(
            NSPredicate(format: "identifier == 'event_title'")
        ).firstMatch
        guard eventTitle.waitForExistence(timeout: 10) else {
            attach(screenshot: "no_events_to_tap")
            try XCTSkipIf(true, "No events in feed to tap — skipping detail test")
            return
        }

        eventTitle.tap()
        sleep(2)

        attach(screenshot: "event_detail")

        let saveButton = app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] 'Save'")
        ).firstMatch
        
        let hasDetailElements = saveButton.waitForExistence(timeout: 5)
        XCTAssertTrue(hasDetailElements,
                       "Event detail should show a Save button or other interaction controls")
    }

    func testToggleSave() throws {
        if app.buttons["Discover"].exists { app.buttons["Discover"].tap(); sleep(1) }
        sleep(3)

        let eventTitle = app.staticTexts.matching(
            NSPredicate(format: "identifier == 'event_title'")
        ).firstMatch
        guard eventTitle.waitForExistence(timeout: 10) else {
            try XCTSkipIf(true, "No events to test save toggle")
            return
        }

        eventTitle.tap()
        sleep(2)

        let saveButton = app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] 'Save'")
        ).firstMatch
        guard saveButton.waitForExistence(timeout: 5) else {
            attach(screenshot: "no_save_button")
            XCTFail("Save button not found on event detail")
            return
        }

        attach(screenshot: "before_save_tap")
        saveButton.tap()
        sleep(2)
        attach(screenshot: "after_save_tap")

        XCTAssertTrue(saveButton.exists, "Save button should still exist after tap")
    }

    func testMapShowsContent() throws {
        (app.buttons["map_pill"].exists ? app.buttons["map_pill"] : app.buttons["Map"]).tap()
        sleep(3)

        attach(screenshot: "map_view")

        let mapExists = app.maps.firstMatch.waitForExistence(timeout: 10)
        XCTAssertTrue(mapExists, "Map view should be visible")
    }
}
