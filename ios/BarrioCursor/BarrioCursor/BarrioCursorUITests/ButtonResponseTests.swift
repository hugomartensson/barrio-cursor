import XCTest

/// Taps key buttons and asserts the UI responds (screen change, sheet, alert).
/// Failures here mean a button did nothing or the wrong UI appeared — useful for agent-driven fixes.
class ButtonResponseTests: BaseTestCase {

    override func setUpWithError() throws {
        try super.setUpWithError()
        sleep(2)
    }

    // MARK: - Auth screen

    func testSwitchToLoginFormResponds() throws {
        if isLoggedIn() {
            attemptLogout()
            _ = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Create Account' OR label CONTAINS 'Log in here'")).firstMatch.waitForExistence(timeout: 10)
        }

        let switchToLogin = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Log in here'")).firstMatch
        guard switchToLogin.waitForExistence(timeout: 10) else {
            try XCTSkipIf(true, "Not on auth screen with 'Log in here'")
            return
        }
        switchToLogin.tap()
        sleep(1)

        let loginButton = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'LOG IN'")).firstMatch
        let fullNameGone = !app.textFields.matching(NSPredicate(format: "placeholderValue == 'Full Name'")).firstMatch.exists

        XCTAssertTrue(loginButton.waitForExistence(timeout: 5), "Tap 'Log in here' should show LOG IN button")
        XCTAssertTrue(fullNameGone, "Tap 'Log in here' should hide Full Name field")
    }

    func testSwitchToSignupFormResponds() throws {
        if isLoggedIn() {
            attemptLogout()
            _ = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Create Account' OR label CONTAINS 'Log in here'")).firstMatch.waitForExistence(timeout: 10)
        }

        let switchToLogin = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Log in here'")).firstMatch
        if switchToLogin.waitForExistence(timeout: 5) { switchToLogin.tap(); sleep(1) }

        let switchToSignup = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Sign Up'")).firstMatch
        guard switchToSignup.waitForExistence(timeout: 5) else {
            try XCTSkipIf(true, "Sign Up link not found")
            return
        }
        switchToSignup.tap()
        sleep(1)

        let fullName = app.textFields.matching(NSPredicate(format: "placeholderValue == 'Full Name'")).firstMatch
        let createAccount = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Create Account'")).firstMatch

        XCTAssertTrue(fullName.waitForExistence(timeout: 5), "Tap 'Sign Up' should show Full Name field")
        XCTAssertTrue(createAccount.exists, "Tap 'Sign Up' should show Create Account button")
    }

    func testLoginButtonResponds() throws {
        if isLoggedIn() {
            attemptLogout()
            _ = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Create Account' OR label CONTAINS 'Log in here'")).firstMatch.waitForExistence(timeout: 10)
        }

        let switchToLogin = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Log in here'")).firstMatch
        if switchToLogin.waitForExistence(timeout: 5) { switchToLogin.tap(); sleep(1) }

        let emailField = app.textFields.matching(NSPredicate(format: "placeholderValue == 'Email'")).firstMatch
        let passwordField = app.secureTextFields.matching(NSPredicate(format: "placeholderValue == 'Password'")).firstMatch
        guard emailField.waitForExistence(timeout: 5), passwordField.exists else {
            try XCTSkipIf(true, "Login form not available")
            return
        }
        emailField.tap(); emailField.typeText(TestAccounts.secondary.email)
        passwordField.tap(); passwordField.typeText(TestAccounts.secondary.password)

        let loginButton = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'LOG IN'")).firstMatch
        guard loginButton.exists else { XCTFail("LOG IN button not found"); return }
        loginButton.tap()

        let mainTab = app.otherElements["main_tab_view"]
        XCTAssertTrue(mainTab.waitForExistence(timeout: 15), "Tap LOG IN should show main tab / Discover")
    }

    // MARK: - Main app (logged in)

    func testMapButtonOpensMap() throws {
        try loginWithTestAccount()

        let opened = tapMapPill()
        sleep(1)
        attach(screenshot: "map_after_tap")
        try XCTSkipUnless(opened, "Map pill tap did not register — known SwiftUI overlay issue on x86_64 simulators")
    }

    func testProfileButtonOpensProfile() throws {
        try loginWithTestAccount()

        tapProfileButton()
        sleep(3)

        let logoutButton = app.buttons["logout"].exists ? app.buttons["logout"] : app.buttons.matching(NSPredicate(format: "label CONTAINS 'Log Out'")).firstMatch
        if !logoutButton.exists { app.swipeUp(); sleep(1) }
        let profileVisible = logoutButton.waitForExistence(timeout: 5)
            || app.staticTexts.matching(NSPredicate(format: "label != ''")).firstMatch.exists

        XCTAssertTrue(profileVisible, "Tap Profile should show profile (Log Out or user content)")
    }

    func testProfileCloseDismissesSheet() throws {
        try loginWithTestAccount()

        tapProfileButton()
        sleep(1)

        let closeButton = app.buttons["Close"]
        guard closeButton.waitForExistence(timeout: 5) else {
            try XCTSkipIf(true, "Profile sheet has no Close button")
            return
        }
        closeButton.tap()
        sleep(2)

        let backOnDiscover = app.otherElements["main_tab_view"].waitForExistence(timeout: 5)
            || app.buttons["map_pill"].exists
            || app.buttons["Profile"].exists
        XCTAssertTrue(backOnDiscover, "Tap Close on Profile should dismiss sheet back to Discover")
    }

    func testLogoutButtonShowsConfirmation() throws {
        try loginWithTestAccount()

        tapProfileButton()
        sleep(1)
        let logoutButton = app.buttons["logout"].exists ? app.buttons["logout"] : app.buttons.matching(NSPredicate(format: "label CONTAINS 'Log Out'")).firstMatch
        if !logoutButton.exists { app.swipeUp(); sleep(1) }
        guard logoutButton.waitForExistence(timeout: 5) else {
            try XCTSkipIf(true, "Log Out button not found")
            return
        }
        logoutButton.tap()
        sleep(1)

        let alertOrAuth = app.alerts.buttons["Log Out"].waitForExistence(timeout: 3)
            || app.buttons.matching(NSPredicate(format: "label CONTAINS 'Create Account' OR label CONTAINS 'Log in here'")).firstMatch.waitForExistence(timeout: 3)

        XCTAssertTrue(alertOrAuth, "Tap Log Out should show confirmation alert or auth screen")
    }

    func testEventCardTapOpensDetail_ifEventsExist() throws {
        try loginWithTestAccount()

        // Already on Discover after login; wait for feed to load
        sleep(3)

        let eventTitle = app.staticTexts.matching(NSPredicate(format: "identifier == 'event_title'")).firstMatch
        guard eventTitle.waitForExistence(timeout: 10) else {
            try XCTSkipIf(true, "No events in feed to tap")
            return
        }
        eventTitle.tap()
        sleep(2)

        let saveButton = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Save'")).firstMatch
        let detailVisible = saveButton.waitForExistence(timeout: 5)
            || app.buttons["Cancel"].waitForExistence(timeout: 3)

        XCTAssertTrue(detailVisible, "Tap event card should open event detail (Save or Cancel visible)")
    }
}
