import XCTest

/// Tests for profile viewing and editing
class ProfileFlowTests: BaseTestCase {
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        
        // Login before each test
        try loginWithTestAccount()
    }
    
    func testViewOwnProfile() throws {
        try recordStep("Navigate to Profile Tab") {
            let profileTab = app.tabBars.buttons["Profile"]
            XCTAssertTrue(waitForElement(profileTab))
            profileTab.tap()
            sleep(2)
            captureScreenshot(name: "profile_tab_opened")
        }
        
        try recordStep("Verify Profile Information") {
            // Check for profile elements
            let hasProfileInfo = app.staticTexts.matching(NSPredicate(format: "label.length > 0")).count > 0
            
            XCTAssertTrue(hasProfileInfo, "Profile should display user information")
            
            // Look for specific profile elements
            // Adjust based on your ProfileView implementation
            let hasName = app.staticTexts.matching(NSPredicate(format: "label.length > 2 AND label.length < 50")).count > 0
            
            if hasName {
                print("✅ Profile information displayed")
            }
            
            captureScreenshot(name: "profile_info_visible")
        }
        
        try recordStep("Verify Profile Sections") {
            // Check for common profile sections
            // Adjust based on your actual ProfileView structure
            
            // Look for "My Events" or "Events" section
            let eventsSection = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'event'")).firstMatch
            
            // Look for "Plans" section
            let plansSection = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'plan'")).firstMatch
            
            // Look for "Interested" section
            let interestedSection = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'interested'")).firstMatch
            
            print("Profile sections found:")
            print("  Events: \(eventsSection.exists)")
            print("  Plans: \(plansSection.exists)")
            print("  Interested: \(interestedSection.exists)")
            
            captureScreenshot(name: "profile_sections")
        }
    }
    
    func testEditProfile() throws {
        try recordStep("Navigate to Profile") {
            let profileTab = app.tabBars.buttons["Profile"]
            XCTAssertTrue(waitForElement(profileTab))
            profileTab.tap()
            sleep(2)
        }
        
        try recordStep("Open Edit Profile") {
            let editButton = app.buttons.matching(NSPredicate(format: "identifier CONTAINS 'edit' OR label CONTAINS[c] 'edit'")).firstMatch
            
            if editButton.exists {
                editButton.tap()
                sleep(2)
                captureScreenshot(name: "edit_profile_opened")
            } else {
                throw NSError(domain: "ProfileFlowTests", code: -1, userInfo: [
                    NSLocalizedDescriptionKey: "Could not find edit profile button"
                ])
            }
        }
        
        try recordStep("Edit Name") {
            let nameField = app.textFields.matching(NSPredicate(format: "identifier CONTAINS 'name' OR placeholderValue CONTAINS[c] 'name'")).firstMatch
            
            if nameField.exists {
                nameField.tap()
                nameField.clearText()
                nameField.typeText("Test User Updated")
                captureScreenshot(name: "name_edited")
            } else {
                // Try first text field
                let textFields = app.textFields
                if textFields.count > 0 {
                    textFields.firstMatch.tap()
                    textFields.firstMatch.clearText()
                    textFields.firstMatch.typeText("Test User Updated")
                } else {
                    throw NSError(domain: "ProfileFlowTests", code: -1, userInfo: [
                        NSLocalizedDescriptionKey: "Could not find name field"
                    ])
                }
            }
        }
        
        try recordStep("Save Changes") {
            let saveButton = app.buttons.matching(NSPredicate(format: "identifier CONTAINS 'save' OR label CONTAINS[c] 'save' OR label CONTAINS[c] 'done'")).firstMatch
            
            if saveButton.exists {
                if saveButton.isEnabled {
                    saveButton.tap()
                    sleep(3) // Wait for API call
                    captureScreenshot(name: "profile_saved")
                } else {
                    throw NSError(domain: "ProfileFlowTests", code: -1, userInfo: [
                        NSLocalizedDescriptionKey: "Save button is disabled"
                    ])
                }
            } else {
                throw NSError(domain: "ProfileFlowTests", code: -1, userInfo: [
                    NSLocalizedDescriptionKey: "Could not find save button"
                ])
            }
        }
        
        try recordStep("Verify Changes Saved") {
            // Check if we're back to profile view
            sleep(2)
            
            // Look for updated name
            let updatedName = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Test User Updated'")).firstMatch
            
            if updatedName.exists {
                print("✅ Profile name updated successfully")
                captureScreenshot(name: "profile_updated")
            } else {
                // Check for error
                let errorText = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'error'")).firstMatch
                if errorText.exists {
                    let errorMessage = errorText.label
                    throw NSError(domain: "ProfileFlowTests", code: -1, userInfo: [
                        NSLocalizedDescriptionKey: "Profile update failed: \(errorMessage)"
                    ])
                }
            }
        }
    }
    
    func testViewOtherUserProfile() throws {
        try recordStep("Navigate to Feed") {
            let feedTab = app.tabBars.buttons["Feed"]
            XCTAssertTrue(waitForElement(feedTab))
            feedTab.tap()
            sleep(5) // Wait for events to load
        }
        
        try recordStep("Tap Event Creator") {
            // Look for creator name/avatar in event cards
            let creatorButton = app.buttons.matching(NSPredicate(format: "identifier CONTAINS 'creator' OR identifier CONTAINS 'user' OR identifier CONTAINS 'profile'")).firstMatch
            
            if creatorButton.exists {
                creatorButton.tap()
                sleep(2)
                captureScreenshot(name: "creator_profile_opened")
            } else {
                // Try tapping on event first, then creator
                let eventCell = app.cells.firstMatch
                if eventCell.exists {
                    eventCell.tap()
                    sleep(2)
                    
                    // Now look for creator button in detail view
                    let creatorButton = app.buttons.matching(NSPredicate(format: "identifier CONTAINS 'creator' OR identifier CONTAINS 'user'")).firstMatch
                    if creatorButton.exists {
                        creatorButton.tap()
                        sleep(2)
                        captureScreenshot(name: "creator_profile_opened")
                    } else {
                        throw NSError(domain: "ProfileFlowTests", code: -1, userInfo: [
                            NSLocalizedDescriptionKey: "Could not find creator profile button"
                        ])
                    }
                } else {
                    throw NSError(domain: "ProfileFlowTests", code: -1, userInfo: [
                        NSLocalizedDescriptionKey: "No events found to view creator profile"
                    ])
                }
            }
        }
        
        try recordStep("Verify Other User Profile") {
            // Check for profile information
            let hasProfileInfo = app.staticTexts.matching(NSPredicate(format: "label.length > 0")).count > 0
            
            XCTAssertTrue(hasProfileInfo, "Other user profile should display information")
            
            // Look for follow button (should exist for other users)
            let followButton = app.buttons.matching(NSPredicate(format: "identifier CONTAINS 'follow' OR label CONTAINS[c] 'follow'")).firstMatch
            
            if followButton.exists {
                print("✅ Follow button found - this is another user's profile")
                captureScreenshot(name: "other_user_profile")
            } else {
                print("⚠️ Follow button not found - might be own profile or UI differs")
            }
        }
        
        try recordStep("View User's Events") {
            // Look for events section
            let eventsSection = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'event'")).firstMatch
            
            if eventsSection.exists {
                print("✅ Events section found")
            }
            
            // Try scrolling to see more
            let scrollView = app.scrollViews.firstMatch
            if scrollView.exists {
                scrollView.swipeUp()
                sleep(1)
                captureScreenshot(name: "profile_scrolled")
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func loginWithTestAccount() throws {
        let emailField = app.textFields["Email"]
        if emailField.waitForExistence(timeout: 5.0) {
            emailField.tap()
            emailField.typeText(TestAccounts.primary.email)
            
            let passwordField = app.secureTextFields["Password"]
            if passwordField.waitForExistence(timeout: 2.0) {
                passwordField.tap()
                passwordField.typeText(TestAccounts.primary.password)
                
                let loginButton = app.buttons["Log In"].firstMatch
                if loginButton.exists {
                    loginButton.tap()
                    sleep(5)
                }
            }
        }
        
        let tabBar = app.tabBars.firstMatch
        if !tabBar.waitForExistence(timeout: 10.0) {
            throw NSError(domain: "ProfileFlowTests", code: -1, userInfo: [
                NSLocalizedDescriptionKey: "Login failed in setup"
            ])
        }
    }
}

// MARK: - XCUIElement Extensions

extension XCUIElement {
    func clearText() {
        guard let stringValue = self.value as? String else {
            return
        }
        
        self.tap()
        
        let deleteString = String(repeating: XCUIKeyboardKey.delete.rawValue, count: stringValue.count)
        self.typeText(deleteString)
    }
}
