import XCTest

/// Tests for authentication flows (login, signup)
class LoginFlowTests: BaseTestCase {
    
    func testLoginWithValidCredentials() throws {
        try recordStep("Launch App") {
            XCTAssertTrue(app.wait(for: .runningForeground, timeout: 5.0))
        }
        
        try recordStep("Navigate to Login") {
            // Wait for auth screen to appear
            let loginButton = app.buttons["Log In"]
            if loginButton.waitForExistence(timeout: 5.0) {
                loginButton.tap()
            }
            // If already on login screen, continue
        }
        
        try recordStep("Enter Email") {
            let emailField = app.textFields["Email"]
            XCTAssertTrue(waitForElement(emailField))
            emailField.tap()
            emailField.typeText(TestAccounts.primary.email)
            captureScreenshot(name: "email_entered")
        }
        
        try recordStep("Enter Password") {
            let passwordField = app.secureTextFields["Password"]
            XCTAssertTrue(waitForElement(passwordField))
            passwordField.tap()
            passwordField.typeText(TestAccounts.primary.password)
            captureScreenshot(name: "password_entered")
        }
        
        try recordStep("Submit Login") {
            let loginButton = app.buttons["Log In"].firstMatch
            if loginButton.exists {
                loginButton.tap()
            } else {
                // Try alternative button identifiers
                let submitButton = app.buttons.matching(identifier: "login").firstMatch
                if submitButton.exists {
                    submitButton.tap()
                } else {
                    // Try keyboard return
                    app.keyboards.buttons["return"].tap()
                }
            }
        }
        
        try recordStep("Verify Login Success") {
            // Wait for main app interface (tab bar or main content)
            let tabBar = app.tabBars.firstMatch
            let mapTab = app.tabBars.buttons["Map"]
            let feedTab = app.tabBars.buttons["Feed"]
            let profileTab = app.tabBars.buttons["Profile"]
            
            // Check if any tab bar element appears (indicates successful login)
            let loginSuccessful = tabBar.waitForExistence(timeout: 10.0) ||
                                  mapTab.waitForExistence(timeout: 10.0) ||
                                  feedTab.waitForExistence(timeout: 10.0) ||
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
                if app.textFields["Email"].exists {
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
            let loginButton = app.buttons["Log In"]
            if loginButton.waitForExistence(timeout: 5.0) {
                loginButton.tap()
            }
        }
        
        try recordStep("Enter Invalid Email") {
            let emailField = app.textFields["Email"]
            XCTAssertTrue(waitForElement(emailField))
            emailField.tap()
            emailField.typeText("invalid@test.com")
        }
        
        try recordStep("Enter Invalid Password") {
            let passwordField = app.secureTextFields["Password"]
            XCTAssertTrue(waitForElement(passwordField))
            passwordField.tap()
            passwordField.typeText("wrongpassword")
        }
        
        try recordStep("Submit Login") {
            let loginButton = app.buttons["Log In"].firstMatch
            if loginButton.exists {
                loginButton.tap()
            }
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
                if app.textFields["Email"].exists {
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
