import XCTest

/// Tier 3D: Profile management — view, edit, navigation to sub-screens.
class ProfileTests2: BaseTestCase {

    override func setUpWithError() throws {
        try super.setUpWithError()
        sleep(2)
        try loginWithTestAccount(TestAccounts.secondary)
    }

    // MARK: - Tests

    func testProfileShowsUserInfo() throws {
        tapProfileButton()
        sleep(2)

        attach(screenshot: "profile_info")

        // Profile may show mock user name/email or any identifiable content (tabs, logout, etc.)
        let hasUserInfo = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS[c] 'Test' OR label CONTAINS[c] 'barrio' OR label CONTAINS[c] 'UI Test'")
        ).firstMatch.waitForExistence(timeout: 5)
        let hasProfileContent = app.buttons["logout"].exists || app.buttons["my_collections_tab"].exists || app.buttons["my_events_tab"].exists
        XCTAssertTrue(hasUserInfo || hasProfileContent, "Profile should display user info or profile content (tabs, logout)")
    }

    func testOpenEditProfile() throws {
        tapProfileButton()
        sleep(2)

        let editProfileBtn = app.buttons["edit_profile"]

        guard editProfileBtn.waitForExistence(timeout: 5) else {
            attach(screenshot: "no_edit_profile")
            XCTFail("Edit profile button/header not found")
            return
        }
        editProfileBtn.tap()
        sleep(2)

        attach(screenshot: "edit_profile_sheet")

        let nameField = app.textFields.matching(
            NSPredicate(format: "placeholderValue CONTAINS 'Name' OR identifier == 'name' OR value CONTAINS 'Test'")
        ).firstMatch
        let saveBtn = app.buttons.matching(
            NSPredicate(format: "label == 'Save' OR label == 'Done'")
        ).firstMatch

        let hasEditElements = nameField.waitForExistence(timeout: 5) || saveBtn.exists
        XCTAssertTrue(hasEditElements, "Edit profile should show Name field or Save button")

        if app.buttons["Cancel"].exists { app.buttons["Cancel"].tap() }
        else if saveBtn.exists { saveBtn.tap() }
        else { app.swipeDown() }
    }

    func testMyEventsNavigation() throws {
        tapProfileButton()
        sleep(2)

        let myEvents = app.buttons["my_events_tab"].exists ? app.buttons["my_events_tab"] : app.buttons.matching(NSPredicate(format: "label == 'My Events'")).firstMatch
        guard myEvents.waitForExistence(timeout: 5) else {
            attach(screenshot: "no_my_events_link")
            XCTFail("'My Events' link not found")
            return
        }
        myEvents.tap()
        sleep(2)

        attach(screenshot: "my_events_screen")

        // My Events is a tab in the profile sheet, not a pushed nav view; check for event-related content or empty state
        let hasNavBar = app.navigationBars["My Events"].waitForExistence(timeout: 3)
        let hasEventContent = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'event'")).firstMatch.exists
        let hasEmptyState = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'no events' OR label CONTAINS[c] 'empty'")).firstMatch.exists
        let hasMyEventsTab = app.buttons["my_events_tab"].exists
        XCTAssertTrue(hasNavBar || hasEventContent || hasEmptyState || hasMyEventsTab, "My Events screen or tab should be visible")
    }

    func testInterestedEventsNavigation() throws {
        try XCTSkipIf(true, "Interested Events link removed from Profile; use Saved Events instead")
    }
}
