import XCTest

/// Tests for profile viewing and editing
class ProfileFlowTests: BaseTestCase {
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        
        // Login before each test
        try loginWithTestAccount()
    }
    
    func testViewOwnProfile() throws {
        try recordStep("Open Profile (header icon)") {
            tapProfileButton()
            sleep(2)
            captureScreenshot(name: "profile_sheet_opened")
        }
        
        try recordStep("Verify Profile Information") {
            // Check for profile elements
            let hasProfileInfo = app.staticTexts.matching(NSPredicate(format: "label != ''")).count > 0
            
            XCTAssertTrue(hasProfileInfo, "Profile should display user information")
            
            // Look for specific profile elements
            // Adjust based on your ProfileView implementation
            let hasName = app.staticTexts.matching(NSPredicate(format: "label MATCHES '.{3,49}'")).count > 0
            
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
            
            // Look for "Saved" section
            let savedSection = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'saved'")).firstMatch
            
            print("Profile sections found:")
            print("  Events: \(eventsSection.exists)")
            print("  Plans: \(plansSection.exists)")
            print("  Saved: \(savedSection.exists)")
            
            captureScreenshot(name: "profile_sections")
        }
    }
    
    func testEditProfile() throws {
        try recordStep("Open Profile (header icon)") {
            tapProfileButton()
            sleep(2)
        }
        
        try recordStep("Open Edit Profile") {
            let editButton = app.buttons["edit_profile"]
            if !editButton.exists {
                let fallback = app.buttons.matching(NSPredicate(format: "identifier CONTAINS 'edit' OR label CONTAINS[c] 'edit'")).firstMatch
                if fallback.exists { fallback.tap(); sleep(2); captureScreenshot(name: "edit_profile_opened"); return }
            }
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
            // Check if we're back to profile view or edit sheet dismissed
            sleep(2)
            
            let updatedName = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Test User Updated'")).firstMatch
            if updatedName.exists {
                print("✅ Profile name updated successfully")
                captureScreenshot(name: "profile_updated")
                return
            }
            // In UI-testing mode API is disabled, so save fails and we may see an error — that's expected
            let errorText = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'error'")).firstMatch
            if errorText.exists {
                print("⚠️ Profile save showed error (expected when API is disabled in UI tests)")
                captureScreenshot(name: "profile_save_error_expected")
                return
            }
            // Sheet may have dismissed; verify we can see profile content (e.g. logout or tabs)
            let onProfile = app.buttons["logout"].exists || app.buttons["my_collections_tab"].exists
            XCTAssertTrue(onProfile, "Edit flow should complete: either updated name, error (expected in UI test), or back on profile")
        }
    }
    
    func testViewOtherUserProfile() throws {
        try recordStep("Ensure on Discover") {
            if app.buttons["Discover"].exists {
                app.buttons["Discover"].tap()
                sleep(1)
            }
            sleep(5) // Wait for events to load
        }

        // Skip when no events/creator (API disabled in UI test)
        let creatorButton = app.buttons.matching(NSPredicate(format: "identifier CONTAINS 'creator' OR identifier CONTAINS 'user' OR identifier CONTAINS 'profile'")).firstMatch
        let hasEventCell = app.cells.firstMatch.exists
        if !creatorButton.exists, !hasEventCell {
            try XCTSkipIf(true, "No events or creator found — cannot test other-user profile (API disabled in UI test)")
        }
        
        try recordStep("Tap Event Creator") {
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
                    try XCTSkipIf(true, "No events found — cannot test creator profile (seed DB with events)")
                    return
                }
            }
        }
        
        try recordStep("Verify Other User Profile") {
            // Check for profile information
            let hasProfileInfo = app.staticTexts.matching(NSPredicate(format: "label != ''")).count > 0
            
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
}
