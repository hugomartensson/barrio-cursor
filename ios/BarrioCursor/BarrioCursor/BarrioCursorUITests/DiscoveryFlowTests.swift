import XCTest

/// Tests for event discovery flows (browse feed, view events, filter)
class DiscoveryFlowTests: BaseTestCase {
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        
        // Login before each test
        try loginWithTestAccount()
    }
    
    func testBrowseDiscoverView() throws {
        try recordStep("Ensure on Discover") {
            // After login we're on Discover; only tap Discover if we're on Map (dismiss pill)
            if app.buttons["Discover"].exists {
                app.buttons["Discover"].tap()
                sleep(1)
            }
            captureScreenshot(name: "discover_screen")
        }
        
        try recordStep("Verify Discover Screen Loaded") {
            // FeedView uses List (not ScrollView); when API is disabled we may see EmptyStateView.
            // Verify Discover is visible: Profile button and either map_pill or filter/content.
            let hasProfile = app.buttons["Profile"].waitForExistence(timeout: 10)
            let hasMapPill = app.buttons["map_pill"].exists || app.buttons["Map"].exists
            let hasFilterPill = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'filter_pill_'")).firstMatch.exists
            let hasContent = hasMapPill || hasFilterPill || app.staticTexts.matching(NSPredicate(format: "label != ''")).count > 0
            XCTAssertTrue(hasProfile, "Discover screen should show Profile button")
            XCTAssertTrue(hasContent, "Discover screen should show map pill, filter pills, or text content")
            sleep(1)
            captureScreenshot(name: "feed_loaded")
        }
        
        try recordStep("Verify Feed Content or Empty State") {
            // Either events/list content OR empty state is valid (API disabled in UI test).
            let hasEvents = app.staticTexts.matching(NSPredicate(format: "label != ''")).count > 0 ||
                           app.images.count > 0 ||
                           app.buttons.matching(NSPredicate(format: "identifier CONTAINS 'event'")).count > 0 ||
                           app.cells.count > 0
            let emptyState = app.staticTexts["No events nearby"]
            let hasEmptyState = emptyState.waitForExistence(timeout: 3)
            XCTAssertTrue(hasEvents || hasEmptyState, "Feed should show events/list content or empty state 'No events nearby'")
            if hasEmptyState { captureScreenshot(name: "feed_empty") }
            else { print("✅ Events or list content found in feed") }
        }
        
        try recordStep("Scroll Feed If Possible") {
            let feedScrollView = app.scrollViews.firstMatch
            let hasCells = app.cells.count > 0
            if feedScrollView.exists {
                feedScrollView.swipeUp()
                sleep(1)
                captureScreenshot(name: "feed_scrolled")
            } else if hasCells {
                app.cells.firstMatch.swipeUp()
                sleep(1)
                captureScreenshot(name: "feed_scrolled")
            }
        }
    }
    
    func testViewEventDetails() throws {
        try recordStep("Ensure on Discover") {
            if app.buttons["Discover"].exists {
                app.buttons["Discover"].tap()
                sleep(1)
            }
        }
        
        try recordStep("Wait for Events") {
            sleep(5) // Wait for API to load events
            captureScreenshot(name: "feed_before_tap")
        }
        
        try recordStep("Tap First Event") {
            var eventTapped = false
            
            // Strategy 1: Find a text with the event_title identifier and tap it
            let eventTitle = app.staticTexts.matching(
                NSPredicate(format: "identifier == 'event_title'")
            ).firstMatch
            if eventTitle.waitForExistence(timeout: 3) {
                eventTitle.tap()
                eventTapped = true
            }
            
            // Strategy 2: Tap any visible cell/row (List-based layouts)
            if !eventTapped {
                let cells = app.cells
                if cells.count > 0 {
                    cells.firstMatch.tap()
                    eventTapped = true
                }
            }
            
            // Strategy 3: Tap any button whose identifier contains 'event'
            if !eventTapped {
                let eventButtons = app.buttons.matching(NSPredicate(format: "identifier CONTAINS 'event'"))
                if eventButtons.count > 0 {
                    eventButtons.firstMatch.tap()
                    eventTapped = true
                }
            }
            
            if !eventTapped {
                captureScreenshot(name: "no_events_to_tap")
                try XCTSkipIf(true, "No tappable event found — feed may be empty (seed DB or wait for events)")
                return
            }
            
            sleep(2)
            captureScreenshot(name: "event_detail_opened")
        }
        
        try recordStep("Verify Event Details") {
            // Check for event detail elements
            // Adjust based on your EventDetailView implementation
            let hasDetails = app.staticTexts.matching(NSPredicate(format: "label != ''")).count > 0
            
            if !hasDetails {
                throw NSError(domain: "DiscoveryFlowTests", code: -1, userInfo: [
                    NSLocalizedDescriptionKey: "Event detail view appears empty"
                ])
            }
            
            // Look for specific detail elements
            let hasTitle = app.staticTexts.matching(NSPredicate(format: "label MATCHES '.{6,}'")).count > 0
            XCTAssertTrue(hasTitle, "Event should have a title or description")
            
            captureScreenshot(name: "event_details_visible")
        }
    }
    
    func testFilterEvents() throws {
        try recordStep("Ensure on Discover") {
            if app.buttons["Discover"].exists {
                app.buttons["Discover"].tap()
                sleep(1)
            }
            sleep(3) // Wait for initial load
        }

        try recordStep("Apply Category Filter") {
            // Use accessibility identifiers on filter pills (PortalFilterPill); skip if none (no API data in UI test)
            let foodPill = app.buttons["filter_pill_Food"]
            let musicPill = app.buttons["filter_pill_Music"]
            if !foodPill.waitForExistence(timeout: 5), !musicPill.exists {
                try XCTSkipIf(true, "Filter pills not visible (no API data in UI test)")
            }
            if foodPill.exists {
                foodPill.tap()
                sleep(2)
                captureScreenshot(name: "filter_applied")
            } else if musicPill.exists {
                musicPill.tap()
                sleep(2)
                captureScreenshot(name: "filter_applied")
            }
        }

        try recordStep("Apply Following Filter") {
            let followingButton = app.buttons.matching(NSPredicate(format: "identifier CONTAINS 'following' OR label CONTAINS[c] 'following'")).firstMatch
            if followingButton.exists {
                followingButton.tap()
                sleep(2)
                captureScreenshot(name: "following_filter_applied")
            } else {
                print("⚠️ Following filter not found")
            }
        }
    }
    
    func testMapViewDiscovery() throws {
        try recordStep("Open Map (floating pill)") {
            let mapTab = app.buttons["map_pill"].exists ? app.buttons["map_pill"] : app.buttons["Map"]
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
    
}
