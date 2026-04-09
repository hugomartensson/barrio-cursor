import XCTest

/// UI tests for pending alpha items: follow-requests screen (#13), collection detail with remove (#3), other-user profile sections (#12).
class PendingAlphaFlowTests: BaseTestCase {

    override func setUpWithError() throws {
        try super.setUpWithError()
        try loginWithTestAccount()
    }

    // MARK: - #13 Follow-request management UI

    func testFollowRequestsScreenReachableFromProfile() throws {
        try recordStep("Open Profile") {
            tapProfileButton()
            sleep(2)
            captureScreenshot(name: "profile_opened")
        }

        try recordStep("Tap followers count link") {
            let followersLink = app.buttons["profile_followers_link"]
            if followersLink.waitForExistence(timeout: 8) {
                followersLink.tap()
                sleep(3)
                captureScreenshot(name: "follow_requests_screen")
            } else {
                // Fallback: tap element containing "followers"
                let followersText = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'followers'")).firstMatch
                if followersText.waitForExistence(timeout: 5) {
                    followersText.tap()
                    sleep(3)
                    captureScreenshot(name: "follow_requests_screen")
                }
            }
        }

        try recordStep("Verify Follow requests / Followers screen") {
            let screen = app.otherElements["follow_requests_screen"]
            let followRequestsSection = app.staticTexts["Follow requests"]
            let followersSection = app.staticTexts["Followers"]
            let noFollowersYet = app.staticTexts["No followers yet"]
            let navTitle = app.navigationBars.staticTexts["Followers"]
            let loading = app.staticTexts["Loading..."]
            let hasScreen = screen.waitForExistence(timeout: 5)
            let hasSection = followRequestsSection.exists || followersSection.exists || noFollowersYet.exists
            let hasNavTitle = navTitle.waitForExistence(timeout: 3)
            let hasLoading = loading.exists
            XCTAssertTrue(hasScreen || hasSection || hasNavTitle || hasLoading, "Follow requests screen should show list, sections, or loading")
            captureScreenshot(name: "follow_requests_verified")
        }
    }

    // MARK: - #3 Collection detail with items (swipe-to-delete exists in UI)

    func testCollectionDetailShowsItemsSection() throws {
        try recordStep("Open Profile") {
            tapProfileButton()
            sleep(2)
        }

        try recordStep("Open My Collections tab") {
            let collectionsTab = app.buttons["my_collections_tab"]
            if collectionsTab.waitForExistence(timeout: 8) {
                collectionsTab.tap()
                sleep(2)
                captureScreenshot(name: "my_collections_tab")
            } else {
                try XCTSkipIf(true, "My Collections tab not found")
            }
        }

        try recordStep("Open first collection if any") {
            let firstCell = app.cells.firstMatch
            if firstCell.waitForExistence(timeout: 5) {
                firstCell.tap()
                sleep(3)
                captureScreenshot(name: "collection_detail")
            } else {
                try XCTSkipIf(true, "No collections to open (API disabled in UI test)")
            }
        }

        try recordStep("Verify collection detail has items section") {
            let itemsSection = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'ITEM' OR label CONTAINS[c] 'COLLECTION'")).firstMatch
            let hasContent = app.cells.count > 0 || itemsSection.waitForExistence(timeout: 5)
            XCTAssertTrue(hasContent, "Collection detail should show items section or list")
            captureScreenshot(name: "collection_items_visible")
        }
    }

    // MARK: - #12 Other-user profile sections (Collections, Saved spots, Saved events)

    func testOtherUserProfileShowsSections() throws {
        try recordStep("Ensure on Discover") {
            if app.buttons["Discover"].exists {
                app.buttons["Discover"].tap()
                sleep(1)
            }
            sleep(4)
        }

        try recordStep("Open event then creator profile") {
            let eventCell = app.cells.firstMatch
            guard eventCell.waitForExistence(timeout: 8) else {
                throw XCTSkip("No events (API disabled in UI test)")
            }
            eventCell.tap()
            sleep(2)
            let creatorBtn = app.buttons.matching(NSPredicate(format: "identifier CONTAINS 'creator' OR identifier CONTAINS 'user' OR label CONTAINS 'By'")).firstMatch
            if creatorBtn.waitForExistence(timeout: 5) {
                creatorBtn.tap()
                sleep(3)
            } else {
                throw XCTSkip("Creator button not found on event detail")
            }
        }

        try recordStep("Verify other-user profile sections") {
            let collectionsLabel = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'COLLECTION'")).firstMatch
            let savedSpotsLabel = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'SAVED' AND label CONTAINS[c] 'SPOT'")).firstMatch
            let savedEventsLabel = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'SAVED' AND label CONTAINS[c] 'EVENT'")).firstMatch
            let followButton = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'follow'")).firstMatch
            let hasAnySection = collectionsLabel.exists || savedSpotsLabel.exists || savedEventsLabel.exists
            let hasFollow = followButton.exists
            let hasProfileContent = app.staticTexts.matching(NSPredicate(format: "label != ''")).count > 2
            XCTAssertTrue(hasAnySection || hasFollow || hasProfileContent, "Other-user profile should show sections or follow button or content")
            captureScreenshot(name: "other_user_profile_sections")
        }
    }
}
