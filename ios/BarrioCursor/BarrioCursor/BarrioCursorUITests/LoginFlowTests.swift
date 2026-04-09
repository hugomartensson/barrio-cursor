import XCTest

/// Tests for authentication flows (login, signup)
class LoginFlowTests: BaseTestCase {
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        dismissSystemDialogs()
        if isLoggedIn() {
            attemptLogout()
            sleep(2)
        }
    }
    
    func testLoginWithValidCredentials() throws {
        try recordStep("Launch App") {
            XCTAssertTrue(app.wait(for: .runningForeground, timeout: 5.0))
        }
        
        try recordStep("Navigate to Login") {
            let switchToLogin = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Log in here'")).firstMatch
            if switchToLogin.waitForExistence(timeout: 5.0) {
                switchToLogin.tap()
                sleep(1)
            }
            // If already on login screen (Log In button visible), continue
        }
        
        try recordStep("Enter Email") {
            let emailField = app.textFields["login_email"].exists ? app.textFields["login_email"] : app.textFields.matching(NSPredicate(format: "placeholderValue == 'Email'")).firstMatch
            XCTAssertTrue(waitForElement(emailField))
            emailField.tap()
            sleep(1)
            emailField.typeText(TestAccounts.primary.email)
            captureScreenshot(name: "email_entered")
        }
        
        try recordStep("Enter Password") {
            let passwordField = app.secureTextFields["login_password"].exists ? app.secureTextFields["login_password"] : app.secureTextFields.matching(NSPredicate(format: "placeholderValue == 'Password'")).firstMatch
            XCTAssertTrue(waitForElement(passwordField))
            passwordField.tap()
            passwordField.typeText(TestAccounts.primary.password)
            captureScreenshot(name: "password_entered")
        }
        
        try recordStep("Submit Login") {
            let loginButton = app.buttons["login_submit"].exists ? app.buttons["login_submit"] : app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Log In'")).firstMatch
            if loginButton.waitForExistence(timeout: 3) {
                loginButton.tap()
            } else {
                app.keyboards.buttons["return"].tap()
            }
        }
        
        try recordStep("Verify Login Success") {
            // Main screen: main_tab_view + Map pill + Profile icon (no tab bar)
            let mainTabView = app.otherElements["main_tab_view"]
            let mapPill = app.buttons["map_pill"]
            let mapButton = app.buttons["Map"]
            let profileTab = app.buttons["Profile"]
            
            let loginSuccessful = mainTabView.waitForExistence(timeout: 10.0) ||
                                  mapPill.waitForExistence(timeout: 10.0) ||
                                  mapButton.waitForExistence(timeout: 10.0) ||
                                  profileTab.waitForExistence(timeout: 10.0)
            
            if !loginSuccessful {
                // Check for error messages
                let errorText = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'error' OR label CONTAINS[c] 'fail'")).firstMatch
                if errorText.exists {
                    let errorMessage = errorText.label
                    throw NSError(domain: "LoginFlowTests", code: -1, userInfo: [
                        NSLocalizedDescriptionKey: "Login failed with error: \(errorMessage)"
                    ])
                }
                
                // Check if still on login screen (indicates failure)
                if app.textFields["login_email"].exists || app.textFields.matching(NSPredicate(format: "placeholderValue == 'Email'")).firstMatch.exists {
                    throw NSError(domain: "LoginFlowTests", code: -1, userInfo: [
                        NSLocalizedDescriptionKey: "Login failed - still on login screen"
                    ])
                }
            }
            
            XCTAssertTrue(loginSuccessful, "Login should navigate to main app interface")
            captureScreenshot(name: "login_success")
        }
    }
    
    func testLoginWithInvalidCredentials() throws {
        try recordStep("Launch App") {
            XCTAssertTrue(app.wait(for: .runningForeground, timeout: 5.0))
        }
        
        try recordStep("Navigate to Login") {
            let switchToLogin = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Log in here'")).firstMatch
            if switchToLogin.waitForExistence(timeout: 5.0) {
                switchToLogin.tap()
                sleep(1)
            }
        }
        
        try recordStep("Enter Invalid Email") {
            let emailField = app.textFields["login_email"].exists ? app.textFields["login_email"] : app.textFields.matching(NSPredicate(format: "placeholderValue == 'Email'")).firstMatch
            XCTAssertTrue(waitForElement(emailField))
            emailField.tap()
            sleep(1)
            emailField.typeText("invalid@test.com")
        }
        
        try recordStep("Enter Invalid Password") {
            let passwordField = app.secureTextFields["login_password"].exists ? app.secureTextFields["login_password"] : app.secureTextFields.matching(NSPredicate(format: "placeholderValue == 'Password'")).firstMatch
            XCTAssertTrue(waitForElement(passwordField))
            passwordField.tap()
            passwordField.typeText("wrongpassword")
        }
        
        try recordStep("Submit Login") {
            let loginButton = app.buttons["login_submit"].exists ? app.buttons["login_submit"] : app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Log In'")).firstMatch
            if loginButton.waitForExistence(timeout: 3) { loginButton.tap() }
        }
        
        try recordStep("Verify Error Message") {
            // Wait for error message to appear
            sleep(2) // Give API time to respond
            
            // Look for error indicators
            let errorText = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'error' OR label CONTAINS[c] 'invalid' OR label CONTAINS[c] 'incorrect'")).firstMatch
            
            if errorText.exists {
                let errorMessage = errorText.label
                captureScreenshot(name: "error_displayed")
                print("✅ Error message displayed: \(errorMessage)")
            } else {
                // Check if still on login screen (also indicates failure handled)
                if app.textFields["login_email"].exists || app.textFields.matching(NSPredicate(format: "placeholderValue == 'Email'")).firstMatch.exists {
                    print("✅ Login correctly rejected - still on login screen")
                    captureScreenshot(name: "login_rejected")
                } else {
                    throw NSError(domain: "LoginFlowTests", code: -1, userInfo: [
                        NSLocalizedDescriptionKey: "Expected error message or login screen, but neither found"
                    ])
                }
            }
        }
    }
}
