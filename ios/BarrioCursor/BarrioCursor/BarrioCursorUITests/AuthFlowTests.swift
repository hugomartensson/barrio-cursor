import XCTest

/// Tier 1: Authentication flow tests.
class AuthFlowTests: BaseTestCase {

    // MARK: - Setup

    override func setUpWithError() throws {
        try super.setUpWithError()
        sleep(2)
    }

    // MARK: - Tier 1, Test 1: Signup screen elements

    func testSignupScreenElements() throws {
        ensureOnAuthScreen()

        let fullNameField = app.textFields.matching(
            NSPredicate(format: "placeholderValue == 'Full Name'")
        ).firstMatch
        let emailField = app.textFields.matching(
            NSPredicate(format: "placeholderValue == 'Email'")
        ).firstMatch
        let passwordField = app.secureTextFields.matching(
            NSPredicate(format: "placeholderValue == 'Password'")
        ).firstMatch
        let confirmPasswordField = app.secureTextFields.matching(
            NSPredicate(format: "placeholderValue == 'Confirm Password'")
        ).firstMatch
        let createAccountButton = app.buttons.matching(
            NSPredicate(format: "label CONTAINS 'Create Account'")
        ).firstMatch
        let switchToLoginButton = app.buttons.matching(
            NSPredicate(format: "label CONTAINS 'Log in here'")
        ).firstMatch

        XCTAssertTrue(fullNameField.waitForExistence(timeout: 10),
                       "Full Name field should be visible on signup screen")
        XCTAssertTrue(emailField.exists, "Email field should be visible")
        XCTAssertTrue(passwordField.exists, "Password field should be visible")
        XCTAssertTrue(confirmPasswordField.exists, "Confirm Password field should be visible")
        XCTAssertTrue(createAccountButton.exists, "Create Account button should be visible")
        XCTAssertTrue(switchToLoginButton.exists, "'Log in here' link should be visible")

        XCTAssertFalse(createAccountButton.isEnabled,
                        "Create Account should be disabled with empty form")

        attach(screenshot: "signup_screen_elements")
    }

    // MARK: - Tier 1, Test 2: Switch to login

    func testSwitchToLogin() throws {
        ensureOnAuthScreen()

        let switchToLoginButton = app.buttons.matching(
            NSPredicate(format: "label CONTAINS 'Log in here'")
        ).firstMatch
        XCTAssertTrue(switchToLoginButton.waitForExistence(timeout: 10),
                       "Should be on signup screen with 'Log in here' link")
        switchToLoginButton.tap()
        sleep(1)

        let loginButton = app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] 'LOG IN'")
        ).firstMatch
        XCTAssertTrue(loginButton.waitForExistence(timeout: 5),
                       "Log In button should appear after switching")

        let fullNameField = app.textFields.matching(
            NSPredicate(format: "placeholderValue == 'Full Name'")
        ).firstMatch
        XCTAssertFalse(fullNameField.exists,
                        "Full Name field should not be on login screen")

        let confirmPasswordField = app.secureTextFields.matching(
            NSPredicate(format: "placeholderValue == 'Confirm Password'")
        ).firstMatch
        XCTAssertFalse(confirmPasswordField.exists,
                        "Confirm Password should not be on login screen")

        let switchToSignupButton = app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] 'Sign Up'")
        ).firstMatch
        XCTAssertTrue(switchToSignupButton.exists,
                       "'Sign Up' link should be visible on login screen")

        attach(screenshot: "login_screen")
    }

    // MARK: - Tier 1, Test 3: Switch back to signup

    func testSwitchBackToSignup() throws {
        ensureOnAuthScreen()

        let switchToLoginButton = app.buttons.matching(
            NSPredicate(format: "label CONTAINS 'Log in here'")
        ).firstMatch
        XCTAssertTrue(switchToLoginButton.waitForExistence(timeout: 10))
        switchToLoginButton.tap()
        sleep(1)

        let loginButton = app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] 'LOG IN'")
        ).firstMatch
        XCTAssertTrue(loginButton.waitForExistence(timeout: 5))

        let switchToSignupButton = app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] 'Sign Up'")
        ).firstMatch
        XCTAssertTrue(switchToSignupButton.exists)
        switchToSignupButton.tap()
        sleep(1)

        let fullNameField = app.textFields.matching(
            NSPredicate(format: "placeholderValue == 'Full Name'")
        ).firstMatch
        XCTAssertTrue(fullNameField.waitForExistence(timeout: 5),
                       "Full Name field should reappear on signup screen")

        attach(screenshot: "back_to_signup")
    }

    // MARK: - Tier 1, Test 4: Login with valid credentials

    func testLoginWithValidCredentials() throws {
        ensureOnAuthScreen()
        switchToLoginForm()

        let emailField = app.textFields["login_email"]
        XCTAssertTrue(emailField.waitForExistence(timeout: 8), "Email field (login_email) should appear on login form")
        emailField.tap()
        emailField.typeText(TestAccounts.secondary.email)

        let passwordField = app.secureTextFields["login_password"]
        XCTAssertTrue(passwordField.waitForExistence(timeout: 3), "Password field (login_password) should exist")
        passwordField.tap()
        passwordField.typeText(TestAccounts.secondary.password)

        attach(screenshot: "credentials_entered")

        let loginButton = app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] 'LOG IN'")
        ).firstMatch
        XCTAssertTrue(loginButton.exists)
        loginButton.tap()

        let mainTabView = app.otherElements["main_tab_view"]
        let loginSucceeded = mainTabView.waitForExistence(timeout: 15)

        attach(screenshot: "after_login")

        if !loginSucceeded {
            print("=== LOGIN FAILED - HIERARCHY ===")
            print(app.debugDescription)
            print("=== END HIERARCHY ===")
        }

        XCTAssertTrue(loginSucceeded,
                       "Main screen should appear after successful login")
        
        XCTAssertTrue(app.buttons["map_pill"].exists || app.buttons["Map"].exists, "Map pill should exist")
        XCTAssertTrue(app.buttons["Profile"].exists, "Profile icon should exist")

        attach(screenshot: "logged_in_screen")
    }

    // MARK: - Tier 1, Test 5: Logout

    func testLogout() throws {
        try loginWithTestAccount(TestAccounts.secondary)

        let profileButton = app.buttons["Profile"]
        XCTAssertTrue(profileButton.waitForExistence(timeout: 10),
                       "Profile icon should exist after login")
        tapProfileButton()
        sleep(1)

        attach(screenshot: "profile_screen")

        let logoutButton = app.buttons["logout"].exists ? app.buttons["logout"] : app.buttons.matching(
            NSPredicate(format: "label CONTAINS 'Log Out'")
        ).firstMatch

        if !logoutButton.exists {
            app.swipeUp()
            sleep(1)
        }

        XCTAssertTrue(logoutButton.waitForExistence(timeout: 5),
                       "Log Out button should be visible on Profile screen")
        logoutButton.tap()

        let confirmLogout = app.alerts.buttons["Log Out"]
        if confirmLogout.waitForExistence(timeout: 3) {
            confirmLogout.tap()
        }

        attach(screenshot: "after_logout")

        let authElement = app.buttons.matching(
            NSPredicate(format: "label CONTAINS 'Create Account' OR label CONTAINS 'Log In' OR label CONTAINS 'Log in here'")
        ).firstMatch
        XCTAssertTrue(authElement.waitForExistence(timeout: 10),
                       "Auth screen should appear after logout")

        attach(screenshot: "auth_screen_after_logout")
    }

    // MARK: - Auth-Specific Helpers

    private func ensureOnAuthScreen() {
        if isLoggedIn() {
            attemptLogout()
        }
        let authButton = app.buttons.matching(
            NSPredicate(format: "label CONTAINS 'Create Account' OR label CONTAINS 'Log in here'")
        ).firstMatch
        _ = authButton.waitForExistence(timeout: 10)
    }

    private func switchToLoginForm() {
        let switchButton = app.buttons.matching(
            NSPredicate(format: "label CONTAINS 'Log in here'")
        ).firstMatch
        if switchButton.waitForExistence(timeout: 5) {
            switchButton.tap()
            sleep(1)
            let loginButton = app.buttons.matching(
                NSPredicate(format: "label == 'Log In'")
            ).firstMatch
            _ = loginButton.waitForExistence(timeout: 5)
        }
    }
}
