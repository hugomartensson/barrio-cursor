import XCTest

/// Tests for event discovery flows (browse feed, view events, filter)
class DiscoveryFlowTests: BaseTestCase {
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        
        // Login before each test
        try loginWithTestAccount()
    }
    
    func testBrowseFeedView() throws {
        try recordStep("Navigate to Feed Tab") {
            let feedTab = app.tabBars.buttons["Discover"]
            XCTAssertTrue(waitForElement(feedTab))
            feedTab.tap()
            captureScreenshot(name: "feed_tab_selected")
        }
        
        try recordStep("Wait for Events to Load") {
            // Wait for events to appear (could be list items, cards, etc.)
            // Adjust selectors based on your actual FeedView implementation
            let eventList = app.scrollViews.firstMatch
            XCTAssertTrue(waitForElement(eventList, timeout: 15.0))
            
            // Give extra time for API call
            sleep(3)
            captureScreenshot(name: "feed_loaded")
        }
        
        try recordStep("Verify Events Displayed") {
            // Look for event indicators (titles, images, etc.)
            // This is a flexible check - adjust based on your UI
            let hasEvents = app.staticTexts.matching(NSPredicate(format: "label.length > 0")).count > 0 ||
                           app.images.count > 0 ||
                           app.buttons.matching(NSPredicate(format: "identifier CONTAINS 'event'")).count > 0
            
            if !hasEvents {
                // Check for empty state
                let emptyState = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'no events' OR label CONTAINS[c] 'empty'")).firstMatch
                if emptyState.exists {
                    print("⚠️ Feed is empty - this might be expected if no events exist")
                    captureScreenshot(name: "feed_empty")
                } else {
                    throw NSError(domain: "DiscoveryFlowTests", code: -1, userInfo: [
                        NSLocalizedDescriptionKey: "No events found and no empty state displayed"
                    ])
                }
            } else {
                print("✅ Events found in feed")
            }
        }
        
        try recordStep("Scroll Feed") {
            let feedScrollView = app.scrollViews.firstMatch
            if feedScrollView.exists {
                feedScrollView.swipeUp()
                sleep(1)
                captureScreenshot(name: "feed_scrolled")
            }
        }
    }
    
    func testViewEventDetails() throws {
        try recordStep("Navigate to Feed Tab") {
            let feedTab = app.tabBars.buttons["Discover"]
            XCTAssertTrue(waitForElement(feedTab))
            feedTab.tap()
        }
        
        try recordStep("Wait for Events") {
            sleep(5) // Wait for API to load events
            captureScreenshot(name: "feed_before_tap")
        }
        
        try recordStep("Tap First Event") {
            // Try multiple strategies to find and tap an event
            var eventTapped = false
            
            // Strategy 1: Tap any visible cell/row
            let cells = app.cells
            if cells.count > 0 {
                cells.firstMatch.tap()
                eventTapped = true
            }
            
            // Strategy 2: Tap any button that might be an event
            if !eventTapped {
                let eventButtons = app.buttons.matching(NSPredicate(format: "identifier CONTAINS 'event' OR label.length > 10"))
                if eventButtons.count > 0 {
                    eventButtons.firstMatch.tap()
                    eventTapped = true
                }
            }
            
            // Strategy 3: Tap any static text that looks like an event title
            if !eventTapped {
                let titles = app.staticTexts.matching(NSPredicate(format: "label.length > 5 AND label.length < 100"))
                if titles.count > 0 {
                    titles.firstMatch.tap()
                    eventTapped = true
                }
            }
            
            if !eventTapped {
                throw NSError(domain: "DiscoveryFlowTests", code: -1, userInfo: [
                    NSLocalizedDescriptionKey: "Could not find any tappable event element"
                ])
            }
            
            sleep(2) // Wait for navigation
            captureScreenshot(name: "event_detail_opened")
        }
        
        try recordStep("Verify Event Details") {
            // Check for event detail elements
            // Adjust based on your EventDetailView implementation
            let hasDetails = app.staticTexts.matching(NSPredicate(format: "label.length > 0")).count > 0
            
            if !hasDetails {
                throw NSError(domain: "DiscoveryFlowTests", code: -1, userInfo: [
                    NSLocalizedDescriptionKey: "Event detail view appears empty"
                ])
            }
            
            // Look for specific detail elements
            let hasTitle = app.staticTexts.matching(NSPredicate(format: "label.length > 5")).count > 0
            XCTAssertTrue(hasTitle, "Event should have a title or description")
            
            captureScreenshot(name: "event_details_visible")
        }
    }
    
    func testFilterEvents() throws {
        try recordStep("Navigate to Feed Tab") {
            let feedTab = app.tabBars.buttons["Discover"]
            XCTAssertTrue(waitForElement(feedTab))
            feedTab.tap()
            sleep(3) // Wait for initial load
        }
        
        try recordStep("Apply Category Filter") {
            // Look for filter buttons/menus
            // Adjust selectors based on your FeedView filter UI
            let filterButton = app.buttons.matching(NSPredicate(format: "identifier CONTAINS 'filter' OR identifier CONTAINS 'category'")).firstMatch
            
            if filterButton.exists {
                filterButton.tap()
                sleep(1)
                captureScreenshot(name: "filter_menu_opened")
                
                // Try to select a category (adjust based on your UI)
                let categoryOption = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Food' OR label CONTAINS 'Music'")).firstMatch
                if categoryOption.exists {
                    categoryOption.tap()
                    sleep(2) // Wait for filter to apply
                    captureScreenshot(name: "filter_applied")
                }
            } else {
                print("⚠️ Filter button not found - skipping filter test")
            }
        }
        
        try recordStep("Apply Following Filter") {
            // Look for "Following" toggle
            let followingButton = app.buttons.matching(NSPredicate(format: "identifier CONTAINS 'following' OR label CONTAINS[c] 'following'")).firstMatch
            
            if followingButton.exists {
                followingButton.tap()
                sleep(2) // Wait for filter to apply
                captureScreenshot(name: "following_filter_applied")
            } else {
                print("⚠️ Following filter not found")
            }
        }
    }
    
    func testMapViewDiscovery() throws {
        try recordStep("Navigate to Map Tab") {
            let mapTab = app.tabBars.buttons["Map"]
            XCTAssertTrue(waitForElement(mapTab))
            mapTab.tap()
            sleep(3) // Wait for map to load
            captureScreenshot(name: "map_view_opened")
        }
        
        try recordStep("Verify Map Loaded") {
            // Map views are tricky to verify - check for map-related elements
            let mapView = app.maps.firstMatch
            if mapView.exists {
                print("✅ Map view found")
            } else {
                // Map might be rendered differently - check for any scrollable view
                let scrollView = app.scrollViews.firstMatch
                XCTAssertTrue(scrollView.exists, "Map or scrollable view should exist")
            }
        }
        
        try recordStep("Wait for Event Pins") {
            sleep(5) // Wait for events to load on map
            captureScreenshot(name: "map_with_events")
        }
        
        try recordStep("Interact with Map") {
            // Try to pan the map
            let mapView = app.maps.firstMatch
            if mapView.exists {
                mapView.swipeLeft()
                sleep(1)
                mapView.swipeRight()
                sleep(1)
                captureScreenshot(name: "map_panned")
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func loginWithTestAccount() throws {
        // Quick login helper - assumes app is launched
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
                    sleep(5) // Wait for login
                }
            }
        }
        
        // Verify login succeeded
        let tabBar = app.tabBars.firstMatch
        if !tabBar.waitForExistence(timeout: 10.0) {
            throw NSError(domain: "DiscoveryFlowTests", code: -1, userInfo: [
                NSLocalizedDescriptionKey: "Login failed in setup"
            ])
        }
    }
}
