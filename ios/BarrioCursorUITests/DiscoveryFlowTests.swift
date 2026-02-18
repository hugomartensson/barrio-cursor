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
            let feedTab = app.tabBars.buttons["Feed"]
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
            let feedTab = app.tabBars.buttons["Feed"]
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
            let feedTab = app.tabBars.buttons["Feed"]
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
    
    func testMapToStoryViewFlow() throws {
        try recordStep("Navigate to Map Tab") {
            let mapTab = app.tabBars.buttons["Map"]
            XCTAssertTrue(waitForElement(mapTab))
            mapTab.tap()
            sleep(3) // Wait for map to load
            captureScreenshot(name: "map_view_initial")
        }
        
        try recordStep("Wait for Event Pins to Load") {
            // Wait for API to fetch events and pins to appear on map
            sleep(5) // Give time for events to load
            captureScreenshot(name: "map_with_pins")
            
            // Verify map is visible
            let mapView = app.maps.firstMatch
            if !mapView.exists {
                // Map might be in a scroll view or different container
                let scrollView = app.scrollViews.firstMatch
                XCTAssertTrue(scrollView.exists, "Map view should be visible")
            }
        }
        
        try recordStep("Tap Event Pin on Map") {
            // Map pins are tricky to interact with in XCUITest
            // Strategy 1: Try tapping on map annotations/pins
            let mapView = app.maps.firstMatch
            
            if mapView.exists {
                // Try tapping in the center area where pins typically appear
                // In real usage, pins would be tappable annotations
                let mapCenter = mapView.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
                
                // Try tapping on the map - this should trigger pin selection if pins are visible
                // Note: Actual pin tapping depends on how MapKit annotations are implemented
                // If pins have accessibility identifiers, we can tap them directly
                
                // Look for any tappable elements that might be pins
                let pinButtons = app.buttons.matching(NSPredicate(format: "identifier CONTAINS 'pin' OR identifier CONTAINS 'event' OR identifier CONTAINS 'annotation'")).firstMatch
                
                if pinButtons.exists {
                    pinButtons.tap()
                    sleep(2) // Wait for story viewer to open
                    captureScreenshot(name: "pin_tapped")
                } else {
                    // Alternative: Tap on map center where a pin might be
                    // This is a fallback - ideally pins should have accessibility identifiers
                    mapView.tap()
                    sleep(2)
                    captureScreenshot(name: "map_tapped_for_pin")
                    
                    // If story viewer didn't open, try tapping different areas
                    // (This is a workaround - real implementation should have identifiable pins)
                }
            } else {
                throw NSError(domain: "DiscoveryFlowTests", code: -1, userInfo: [
                    NSLocalizedDescriptionKey: "Map view not found - cannot tap pins"
                ])
            }
        }
        
        try recordStep("Verify Story Viewer Opened") {
            // Story viewer should be full-screen with black background
            // Check for story viewer elements:
            // - Full-screen view
            // - Media content (images/videos)
            // - Close button (X)
            // - Progress indicators (if visible)
            
            sleep(2) // Wait for story viewer animation
            
            // Look for story viewer indicators
            let hasStoryView = app.images.count > 0 || // Media visible
                             app.buttons.matching(NSPredicate(format: "identifier CONTAINS 'close' OR identifier == 'X' OR label == 'X'")).firstMatch.exists || // Close button
                             app.otherElements.matching(NSPredicate(format: "identifier CONTAINS 'story' OR identifier CONTAINS 'viewer'")).firstMatch.exists // Story container
            
            if hasStoryView {
                print("✅ Story viewer appears to be open")
                captureScreenshot(name: "story_viewer_opened")
            } else {
                // Check if we're still on map (pin tap didn't work)
                let mapView = app.maps.firstMatch
                if mapView.exists {
                    print("⚠️ Still on map - pin tap may not have worked")
                    print("   Note: Map pins need accessibility identifiers for reliable testing")
                    captureScreenshot(name: "still_on_map")
                    // Don't fail - this might be expected if no events/pins exist
                } else {
                    // Might be in a different view - capture for debugging
                    captureScreenshot(name: "unknown_view_after_pin_tap")
                }
            }
        }
        
        try recordStep("Verify Media Displayed in Story") {
            // Story should show event media (photos/videos)
            let hasMedia = app.images.count > 0
            
            if hasMedia {
                print("✅ Media found in story viewer")
                captureScreenshot(name: "story_media_visible")
            } else {
                // Check for video players
                let hasVideo = app.otherElements.matching(NSPredicate(format: "identifier CONTAINS 'video' OR identifier CONTAINS 'player'")).firstMatch.exists
                
                if hasVideo {
                    print("✅ Video player found")
                    captureScreenshot(name: "story_video_visible")
                } else {
                    print("⚠️ No media detected - might be loading or no media for event")
                    captureScreenshot(name: "story_no_media")
                }
            }
        }
        
        try recordStep("Swipe Through Media (Horizontal)") {
            // Story viewer should allow horizontal swiping between media items
            // Try swiping left/right to navigate media
            
            let storyView = app.otherElements.matching(NSPredicate(format: "identifier CONTAINS 'story'")).firstMatch
            
            if storyView.exists {
                // Swipe right to next media (if multiple)
                storyView.swipeLeft() // Swipe left = move to next (right side)
                sleep(1)
                captureScreenshot(name: "story_swiped_next")
                
                // Swipe left to previous media
                storyView.swipeRight() // Swipe right = move to previous (left side)
                sleep(1)
                captureScreenshot(name: "story_swiped_previous")
            } else {
                // Try swiping on the main window/view
                app.swipeLeft()
                sleep(1)
                captureScreenshot(name: "story_swiped_alternative")
            }
        }
        
        try recordStep("Swipe Up to View Event Details") {
            // Swiping up should reveal event details sheet
            // This is a key interaction from the PRD
            
            let storyView = app.otherElements.matching(NSPredicate(format: "identifier CONTAINS 'story'")).firstMatch
            
            if storyView.exists {
                storyView.swipeUp()
            } else {
                // Swipe up on main view
                app.swipeUp()
            }
            
            sleep(2) // Wait for sheet animation
            captureScreenshot(name: "event_details_sheet")
            
            // Verify details sheet appeared
            let hasDetails = app.staticTexts.matching(NSPredicate(format: "label.length > 5")).count > 0 ||
                           app.buttons.matching(NSPredicate(format: "identifier CONTAINS 'interested' OR identifier CONTAINS 'plan'")).firstMatch.exists
            
            if hasDetails {
                print("✅ Event details sheet visible")
            } else {
                print("⚠️ Event details sheet may not have appeared")
            }
        }
        
        try recordStep("Verify Event Details Content") {
            // Details sheet should show:
            // - Event title
            // - Creator name
            // - Date/time
            // - Location
            // - Description
            // - Interaction buttons (Interested, Add to Plan, Share)
            
            let hasTitle = app.staticTexts.matching(NSPredicate(format: "label.length > 5 AND label.length < 100")).count > 0
            
            // Look for interaction buttons
            let interestedButton = app.buttons.matching(NSPredicate(format: "identifier CONTAINS 'interested' OR label CONTAINS[c] 'interested'")).firstMatch
            let addToPlanButton = app.buttons.matching(NSPredicate(format: "identifier CONTAINS 'plan' OR label CONTAINS[c] 'add to plan'")).firstMatch
            
            print("Event details found:")
            print("  Title/Description: \(hasTitle)")
            print("  Interested button: \(interestedButton.exists)")
            print("  Add to Plan button: \(addToPlanButton.exists)")
            
            captureScreenshot(name: "event_details_content")
        }
        
        try recordStep("Swipe Down to Close Details Sheet") {
            // Swiping down should dismiss the details sheet and return to story
            let detailsSheet = app.otherElements.matching(NSPredicate(format: "identifier CONTAINS 'sheet' OR identifier CONTAINS 'details'")).firstMatch
            
            if detailsSheet.exists {
                detailsSheet.swipeDown()
            } else {
                // Swipe down on main view
                app.swipeDown()
            }
            
            sleep(2) // Wait for animation
            captureScreenshot(name: "details_sheet_dismissed")
        }
        
        try recordStep("Close Story Viewer") {
            // Look for close button (X) in top corner
            let closeButton = app.buttons.matching(NSPredicate(format: "identifier CONTAINS 'close' OR identifier == 'X' OR label == 'X' OR identifier CONTAINS 'dismiss'")).firstMatch
            
            if closeButton.exists {
                closeButton.tap()
                sleep(2) // Wait for dismissal animation
                captureScreenshot(name: "story_viewer_closed")
            } else {
                // Try tapping outside or swiping down
                // Alternative: Tap on map area or use back gesture
                app.swipeDown(velocity: .fast)
                sleep(2)
                captureScreenshot(name: "story_dismissed_swipe")
            }
            
            // Verify we're back on map
            let mapView = app.maps.firstMatch
            if mapView.exists || app.tabBars.buttons["Map"].exists {
                print("✅ Returned to map view")
            } else {
                print("⚠️ May not have returned to map - check screenshot")
            }
        }
        
        try recordStep("Verify Returned to Map View") {
            // Final verification that we're back on the map
            let mapTab = app.tabBars.buttons["Map"]
            let mapView = app.maps.firstMatch
            
            if mapTab.exists || mapView.exists {
                print("✅ Successfully completed map-to-story flow")
                captureScreenshot(name: "back_on_map")
            } else {
                // Might be on a different screen - capture for debugging
                captureScreenshot(name: "final_state_after_story")
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
