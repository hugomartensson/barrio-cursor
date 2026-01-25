import XCTest

/// Tests for plans functionality (create plan, add event to plan, view plans)
class PlansFlowTests: BaseTestCase {
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        
        // Login before each test
        try loginWithTestAccount()
    }
    
    func testCreatePlan() throws {
        try recordStep("Navigate to Plans") {
            // Plans might be in Profile tab or have their own section
            // Try Profile tab first
            let profileTab = app.tabBars.buttons["Profile"]
            if profileTab.exists {
                profileTab.tap()
                sleep(2)
                captureScreenshot(name: "profile_opened")
            }
            
            // Look for Plans section or button
            let plansButton = app.buttons.matching(NSPredicate(format: "identifier CONTAINS 'plan' OR label CONTAINS[c] 'plan'")).firstMatch
            if plansButton.exists {
                plansButton.tap()
                sleep(2)
            } else {
                // Try scrolling to find plans section
                let scrollView = app.scrollViews.firstMatch
                if scrollView.exists {
                    scrollView.swipeUp()
                    sleep(1)
                    let plansButton = app.buttons.matching(NSPredicate(format: "identifier CONTAINS 'plan' OR label CONTAINS[c] 'plan'")).firstMatch
                    if plansButton.exists {
                        plansButton.tap()
                        sleep(2)
                    }
                }
            }
            
            captureScreenshot(name: "plans_view_opened")
        }
        
        try recordStep("Tap Create Plan Button") {
            let createButton = app.buttons.matching(NSPredicate(format: "identifier CONTAINS 'create' OR label CONTAINS[c] 'create' OR label == '+'")).firstMatch
            
            if createButton.exists {
                createButton.tap()
                sleep(2)
                captureScreenshot(name: "create_plan_view_opened")
            } else {
                throw NSError(domain: "PlansFlowTests", code: -1, userInfo: [
                    NSLocalizedDescriptionKey: "Could not find create plan button"
                ])
            }
        }
        
        try recordStep("Enter Plan Name") {
            let nameField = app.textFields.matching(NSPredicate(format: "identifier CONTAINS 'name' OR placeholderValue CONTAINS[c] 'name'")).firstMatch
            
            if nameField.exists {
                nameField.tap()
                nameField.typeText("Test Plan - \(Date().timeIntervalSince1970)")
                captureScreenshot(name: "plan_name_entered")
            } else {
                // Try first text field
                let textFields = app.textFields
                if textFields.count > 0 {
                    textFields.firstMatch.tap()
                    textFields.firstMatch.typeText("Test Plan - \(Date().timeIntervalSince1970)")
                } else {
                    throw NSError(domain: "PlansFlowTests", code: -1, userInfo: [
                        NSLocalizedDescriptionKey: "Could not find plan name field"
                    ])
                }
            }
        }
        
        try recordStep("Enter Plan Description (Optional)") {
            let descriptionField = app.textViews.matching(NSPredicate(format: "identifier CONTAINS 'description'")).firstMatch
            
            if descriptionField.exists {
                descriptionField.tap()
                descriptionField.typeText("This is a test plan created by automated UI tests.")
            } else {
                // Try text fields
                let textFields = app.textFields
                if textFields.count > 1 {
                    textFields.element(boundBy: 1).tap()
                    textFields.element(boundBy: 1).typeText("This is a test plan created by automated UI tests.")
                }
            }
        }
        
        try recordStep("Submit Plan Creation") {
            let createButton = app.buttons.matching(NSPredicate(format: "identifier CONTAINS 'create' OR label CONTAINS[c] 'create'")).firstMatch
            
            if createButton.exists {
                if createButton.isEnabled {
                    createButton.tap()
                    sleep(3) // Wait for API call
                    captureScreenshot(name: "plan_submitted")
                } else {
                    throw NSError(domain: "PlansFlowTests", code: -1, userInfo: [
                        NSLocalizedDescriptionKey: "Create button is disabled - required fields may be missing"
                    ])
                }
            } else {
                throw NSError(domain: "PlansFlowTests", code: -1, userInfo: [
                    NSLocalizedDescriptionKey: "Could not find create/submit button"
                ])
            }
        }
        
        try recordStep("Verify Plan Created") {
            // Check if we're back to plans list
            sleep(2)
            
            // Look for the plan in the list
            let planName = "Test Plan"
            let planText = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Test Plan'")).firstMatch
            
            if planText.exists {
                print("✅ Plan appears in list")
                captureScreenshot(name: "plan_in_list")
            } else {
                // Check for error
                let errorText = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'error'")).firstMatch
                if errorText.exists {
                    let errorMessage = errorText.label
                    throw NSError(domain: "PlansFlowTests", code: -1, userInfo: [
                        NSLocalizedDescriptionKey: "Plan creation failed: \(errorMessage)"
                    ])
                } else {
                    // Might have navigated back - check if we're on plans view
                    let plansView = app.navigationBars.matching(NSPredicate(format: "identifier CONTAINS 'plan'")).firstMatch
                    if plansView.exists {
                        print("✅ Navigated back to plans view")
                        captureScreenshot(name: "plans_view_after_create")
                    }
                }
            }
        }
    }
    
    func testAddEventToPlan() throws {
        try recordStep("Navigate to Feed") {
            let feedTab = app.tabBars.buttons["Feed"]
            XCTAssertTrue(waitForElement(feedTab))
            feedTab.tap()
            sleep(5) // Wait for events to load
        }
        
        try recordStep("Tap First Event") {
            // Find and tap an event
            let cells = app.cells
            if cells.count > 0 {
                cells.firstMatch.tap()
                sleep(2)
                captureScreenshot(name: "event_detail_opened")
            } else {
                throw NSError(domain: "PlansFlowTests", code: -1, userInfo: [
                    NSLocalizedDescriptionKey: "No events found to add to plan"
                ])
            }
        }
        
        try recordStep("Tap Add to Plan") {
            let addToPlanButton = app.buttons.matching(NSPredicate(format: "identifier CONTAINS 'plan' OR label CONTAINS[c] 'add to plan' OR label CONTAINS[c] 'plan'")).firstMatch
            
            if addToPlanButton.exists {
                addToPlanButton.tap()
                sleep(2)
                captureScreenshot(name: "plan_selector_opened")
            } else {
                throw NSError(domain: "PlansFlowTests", code: -1, userInfo: [
                    NSLocalizedDescriptionKey: "Could not find 'Add to Plan' button"
                ])
            }
        }
        
        try recordStep("Select Plan or Create New") {
            // Look for existing plans or create new option
            let createNewButton = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'create' OR label CONTAINS[c] 'new'")).firstMatch
            
            if createNewButton.exists {
                // Create new plan
                createNewButton.tap()
                sleep(2)
                captureScreenshot(name: "create_plan_from_event")
                
                // Fill plan name
                let nameField = app.textFields.firstMatch
                if nameField.exists {
                    nameField.tap()
                    nameField.typeText("Quick Plan - \(Date().timeIntervalSince1970)")
                }
                
                // Submit
                let createButton = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'create'")).firstMatch
                if createButton.exists {
                    createButton.tap()
                    sleep(3)
                }
            } else {
                // Select existing plan
                let planOption = app.buttons.firstMatch
                if planOption.exists {
                    planOption.tap()
                    sleep(2)
                }
            }
            
            captureScreenshot(name: "plan_selected")
        }
        
        try recordStep("Verify Event Added to Plan") {
            // Check for success indicator or navigate to plan
            sleep(2)
            
            // Look for success message or navigation
            let successText = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'added' OR label CONTAINS[c] 'success'")).firstMatch
            if successText.exists {
                print("✅ Success message displayed")
                captureScreenshot(name: "event_added_success")
            } else {
                // Check if we navigated to plan detail
                let planView = app.navigationBars.matching(NSPredicate(format: "identifier CONTAINS 'plan'")).firstMatch
                if planView.exists {
                    print("✅ Navigated to plan view")
                    captureScreenshot(name: "plan_with_event")
                }
            }
        }
    }
    
    func testViewPlansList() throws {
        try recordStep("Navigate to Profile") {
            let profileTab = app.tabBars.buttons["Profile"]
            XCTAssertTrue(waitForElement(profileTab))
            profileTab.tap()
            sleep(2)
        }
        
        try recordStep("Navigate to Plans") {
            let plansButton = app.buttons.matching(NSPredicate(format: "identifier CONTAINS 'plan' OR label CONTAINS[c] 'plan'")).firstMatch
            
            if plansButton.exists {
                plansButton.tap()
                sleep(2)
                captureScreenshot(name: "plans_list_opened")
            } else {
                // Try scrolling
                let scrollView = app.scrollViews.firstMatch
                if scrollView.exists {
                    scrollView.swipeUp()
                    sleep(1)
                    let plansButton = app.buttons.matching(NSPredicate(format: "identifier CONTAINS 'plan' OR label CONTAINS[c] 'plan'")).firstMatch
                    if plansButton.exists {
                        plansButton.tap()
                        sleep(2)
                        captureScreenshot(name: "plans_list_opened")
                    }
                }
            }
        }
        
        try recordStep("Verify Plans Displayed") {
            // Check for plans in list
            let hasPlans = app.cells.count > 0 ||
                          app.staticTexts.matching(NSPredicate(format: "label.length > 0")).count > 0
            
            if !hasPlans {
                // Check for empty state
                let emptyState = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'no plans' OR label CONTAINS[c] 'empty'")).firstMatch
                if emptyState.exists {
                    print("⚠️ Plans list is empty - this might be expected")
                    captureScreenshot(name: "plans_empty")
                } else {
                    throw NSError(domain: "PlansFlowTests", code: -1, userInfo: [
                        NSLocalizedDescriptionKey: "Plans list appears empty with no empty state message"
                    ])
                }
            } else {
                print("✅ Plans found in list")
                captureScreenshot(name: "plans_list_with_items")
            }
        }
        
        try recordStep("Tap Plan to View Details") {
            let planCell = app.cells.firstMatch
            if planCell.exists {
                planCell.tap()
                sleep(2)
                captureScreenshot(name: "plan_detail_viewed")
            } else {
                print("⚠️ No plans to tap - skipping detail view test")
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
            throw NSError(domain: "PlansFlowTests", code: -1, userInfo: [
                NSLocalizedDescriptionKey: "Login failed in setup"
            ])
        }
    }
}
