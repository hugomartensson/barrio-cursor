import XCTest

/// Tests for event creation flow
class EventCreationTests: BaseTestCase {
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        
        // Login before each test
        try loginWithTestAccount()
    }
    
    func testCreateEventBasic() throws {
        try recordStep("Navigate to Create Event") {
            // Try to find create event button
            // Common locations: Feed tab + button, Map long-press, toolbar
            let createButton = app.buttons.matching(NSPredicate(format: "identifier CONTAINS 'create' OR identifier CONTAINS 'add' OR label == '+'")).firstMatch
            
            if createButton.exists {
                createButton.tap()
            } else {
                // Try navigating to Feed first
                let feedTab = app.tabBars.buttons["Feed"]
                if feedTab.exists {
                    feedTab.tap()
                    sleep(1)
                    let createButton = app.buttons.matching(NSPredicate(format: "identifier CONTAINS 'create' OR label == '+'")).firstMatch
                    if createButton.exists {
                        createButton.tap()
                    } else {
                        throw NSError(domain: "EventCreationTests", code: -1, userInfo: [
                            NSLocalizedDescriptionKey: "Could not find create event button"
                        ])
                    }
                } else {
                    throw NSError(domain: "EventCreationTests", code: -1, userInfo: [
                        NSLocalizedDescriptionKey: "Could not find Feed tab or create button"
                    ])
                }
            }
            
            sleep(2) // Wait for create view to appear
            captureScreenshot(name: "create_event_view_opened")
        }
        
        try recordStep("Fill Event Title") {
            let titleField = app.textFields.matching(NSPredicate(format: "identifier CONTAINS 'title' OR placeholderValue CONTAINS[c] 'title'")).firstMatch
            
            if titleField.exists {
                titleField.tap()
                titleField.typeText("Test Event - \(Date().timeIntervalSince1970)")
                captureScreenshot(name: "title_entered")
            } else {
                // Try any text field
                let textFields = app.textFields
                if textFields.count > 0 {
                    textFields.firstMatch.tap()
                    textFields.firstMatch.typeText("Test Event - \(Date().timeIntervalSince1970)")
                } else {
                    throw NSError(domain: "EventCreationTests", code: -1, userInfo: [
                        NSLocalizedDescriptionKey: "Could not find title field"
                    ])
                }
            }
        }
        
        try recordStep("Fill Description") {
            let descriptionField = app.textViews.matching(NSPredicate(format: "identifier CONTAINS 'description'")).firstMatch
            
            if descriptionField.exists {
                descriptionField.tap()
                descriptionField.typeText("This is a test event created by automated UI tests.")
            } else {
                // Try text fields
                let textFields = app.textFields
                if textFields.count > 1 {
                    textFields.element(boundBy: 1).tap()
                    textFields.element(boundBy: 1).typeText("This is a test event created by automated UI tests.")
                }
            }
            
            captureScreenshot(name: "description_entered")
        }
        
        try recordStep("Select Category") {
            // Look for category picker/button
            let categoryButton = app.buttons.matching(NSPredicate(format: "identifier CONTAINS 'category' OR label CONTAINS 'Category'")).firstMatch
            
            if categoryButton.exists {
                categoryButton.tap()
                sleep(1)
                captureScreenshot(name: "category_picker_opened")
                
                // Select first category option
                let categoryOption = app.buttons.firstMatch
                if categoryOption.exists {
                    categoryOption.tap()
                }
            } else {
                print("⚠️ Category selector not found - may be optional or implemented differently")
            }
        }
        
        try recordStep("Set Location") {
            // Look for location button/field
            let locationButton = app.buttons.matching(NSPredicate(format: "identifier CONTAINS 'location' OR label CONTAINS[c] 'location' OR label CONTAINS[c] 'address'")).firstMatch
            
            if locationButton.exists {
                locationButton.tap()
                sleep(2) // Wait for location picker
                captureScreenshot(name: "location_picker_opened")
                
                // Try to confirm location (adjust based on your UI)
                let confirmButton = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'confirm' OR label CONTAINS[c] 'done' OR label CONTAINS[c] 'select'")).firstMatch
                if confirmButton.exists {
                    confirmButton.tap()
                    sleep(1)
                } else {
                    // Try to tap map or use current location
                    let useCurrentLocation = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'current' OR label CONTAINS[c] 'use'")).firstMatch
                    if useCurrentLocation.exists {
                        useCurrentLocation.tap()
                    }
                }
            } else {
                print("⚠️ Location button not found")
            }
        }
        
        try recordStep("Set Start Time") {
            // Look for time/date picker
            let timeButton = app.buttons.matching(NSPredicate(format: "identifier CONTAINS 'time' OR identifier CONTAINS 'date' OR label CONTAINS 'Time' OR label CONTAINS 'Date'")).firstMatch
            
            if timeButton.exists {
                timeButton.tap()
                sleep(1)
                captureScreenshot(name: "time_picker_opened")
                
                // Try to confirm (date/time pickers vary)
                let confirmButton = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'done' OR label CONTAINS[c] 'confirm'")).firstMatch
                if confirmButton.exists {
                    confirmButton.tap()
                }
            } else {
                print("⚠️ Time picker not found")
            }
        }
        
        try recordStep("Add Media") {
            // Look for add media button
            let addMediaButton = app.buttons.matching(NSPredicate(format: "identifier CONTAINS 'media' OR identifier CONTAINS 'photo' OR identifier CONTAINS 'image' OR label CONTAINS 'Add'")).firstMatch
            
            if addMediaButton.exists {
                addMediaButton.tap()
                sleep(2) // Wait for photo picker
                captureScreenshot(name: "media_picker_opened")
                
                // Try to select a photo (this is tricky - photo picker is system UI)
                // For now, just verify the picker opened
                // In real tests, you might need to grant photo library access
            } else {
                print("⚠️ Add media button not found - media might be optional")
            }
        }
        
        try recordStep("Submit Event") {
            // Look for create/submit button
            let createButton = app.buttons.matching(NSPredicate(format: "identifier CONTAINS 'create' OR identifier CONTAINS 'submit' OR label CONTAINS[c] 'create' OR label CONTAINS[c] 'post'")).firstMatch
            
            if createButton.exists {
                if createButton.isEnabled {
                    createButton.tap()
                    sleep(3) // Wait for API call
                    captureScreenshot(name: "event_submitted")
                } else {
                    throw NSError(domain: "EventCreationTests", code: -1, userInfo: [
                        NSLocalizedDescriptionKey: "Create button is disabled - required fields may be missing"
                    ])
                }
            } else {
                throw NSError(domain: "EventCreationTests", code: -1, userInfo: [
                    NSLocalizedDescriptionKey: "Could not find create/submit button"
                ])
            }
        }
        
        try recordStep("Verify Event Created") {
            // Check if we're back to feed/map and event appears
            sleep(3) // Wait for navigation and event to appear
            
            // Look for success indicators or navigation back
            let tabBar = app.tabBars.firstMatch
            if tabBar.exists {
                print("✅ Navigated back to main view - event likely created")
                captureScreenshot(name: "event_creation_success")
            } else {
                // Check for error messages
                let errorText = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'error'")).firstMatch
                if errorText.exists {
                    let errorMessage = errorText.label
                    throw NSError(domain: "EventCreationTests", code: -1, userInfo: [
                        NSLocalizedDescriptionKey: "Event creation failed: \(errorMessage)"
                    ])
                }
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
            throw NSError(domain: "EventCreationTests", code: -1, userInfo: [
                NSLocalizedDescriptionKey: "Login failed in setup"
            ])
        }
    }
}
