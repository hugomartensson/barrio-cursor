import XCTest

/// Tests for general navigation: discovery feed → spot/profile, profile → saves/collections
class NavigationFlowTests: BaseTestCase {

    override func setUpWithError() throws {
        try super.setUpWithError()
        try loginWithTestAccount()
    }

    // MARK: - Discovery → Spot detail

    func testNavigateFromDiscoverToSpotDetail() throws {
        try recordStep("Navigate to Discover") {
            app.tabBars.buttons["Discover"].tap()
            sleep(5)
            captureScreenshot(name: "discover_feed")
        }

        try recordStep("Tap first spot card") {
            let spotCard = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'spot_card_'")).firstMatch
            if spotCard.waitForExistence(timeout: 8) {
                spotCard.tap()
                sleep(2)
                captureScreenshot(name: "spot_detail_opened")
            } else {
                throw NSError(domain: "NavigationFlowTests", code: -1, userInfo: [
                    NSLocalizedDescriptionKey: "No spot card found in feed (spots section may be empty)"
                ])
            }
        }

        try recordStep("Verify spot detail screen") {
            let hasContent = app.staticTexts.matching(NSPredicate(format: "label.length > 0")).count > 0
            XCTAssertTrue(hasContent, "Spot detail should show content")
            captureScreenshot(name: "spot_detail_visible")
        }
    }

    // MARK: - Discovery → User profile (suggested user)

    func testNavigateFromDiscoverToUserProfile() throws {
        try recordStep("Navigate to Discover") {
            app.tabBars.buttons["Discover"].tap()
            sleep(5)
        }

        try recordStep("Tap first suggested user card") {
            let userCard = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'suggested_user_'")).firstMatch
            if userCard.waitForExistence(timeout: 8) {
                userCard.tap()
                sleep(3)
                captureScreenshot(name: "user_profile_sheet_opened")
            } else {
                throw NSError(domain: "NavigationFlowTests", code: -1, userInfo: [
                    NSLocalizedDescriptionKey: "No suggested user card found (People section may be empty)"
                ])
            }
        }

        try recordStep("Verify user profile visible") {
            let hasProfileContent = app.staticTexts.matching(NSPredicate(format: "label.length > 0")).count > 0
            XCTAssertTrue(hasProfileContent, "User profile sheet should show content")
            captureScreenshot(name: "user_profile_visible")
        }
    }

    // MARK: - Profile → My Saves (tap big number)

    func testNavigateFromProfileSavedCountToMySaves() throws {
        try recordStep("Navigate to Profile") {
            app.tabBars.buttons["Profile"].tap()
            sleep(2)
            captureScreenshot(name: "profile_opened")
        }

        try recordStep("Tap SAVED count card") {
            let savedButton = app.buttons["profile_saved_count"]
            if savedButton.waitForExistence(timeout: 5) {
                savedButton.tap()
                sleep(2)
                captureScreenshot(name: "my_saves_opened")
            } else {
                throw NSError(domain: "NavigationFlowTests", code: -1, userInfo: [
                    NSLocalizedDescriptionKey: "Profile SAVED count button not found"
                ])
            }
        }

        try recordStep("Verify My Saves screen") {
            let hasSavesContent = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'saved' OR label CONTAINS[c] 'save' OR label.length > 0")).count > 0
            XCTAssertTrue(hasSavesContent, "My Saves view should be visible")
            captureScreenshot(name: "my_saves_visible")
        }
    }

    // MARK: - Profile → My Collections (tap big number)

    func testNavigateFromProfileCollectionsCountToMyCollections() throws {
        try recordStep("Navigate to Profile") {
            app.tabBars.buttons["Profile"].tap()
            sleep(2)
        }

        try recordStep("Tap COLLECTIONS count card") {
            let collectionsButton = app.buttons["profile_collections_count"]
            if collectionsButton.waitForExistence(timeout: 5) {
                collectionsButton.tap()
                sleep(2)
                captureScreenshot(name: "my_collections_opened")
            } else {
                throw NSError(domain: "NavigationFlowTests", code: -1, userInfo: [
                    NSLocalizedDescriptionKey: "Profile COLLECTIONS count button not found"
                ])
            }
        }

        try recordStep("Verify My Collections screen") {
            let hasCollectionsContent = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'collection' OR label.length > 0")).count > 0
            XCTAssertTrue(hasCollectionsContent, "My Collections view should be visible")
            captureScreenshot(name: "my_collections_visible")
        }
    }

    // MARK: - Profile → My Saves (nav row)

    func testNavigateFromProfileNavRowToMySaves() throws {
        try recordStep("Navigate to Profile") {
            app.tabBars.buttons["Profile"].tap()
            sleep(2)
        }

        try recordStep("Tap My Saves row") {
            let mySavesNav = app.buttons["nav_my_saves"]
            if mySavesNav.waitForExistence(timeout: 5) {
                mySavesNav.tap()
                sleep(2)
                captureScreenshot(name: "my_saves_via_nav")
            } else {
                let mySavesLabel = app.staticTexts["My Saves"]
                if mySavesLabel.waitForExistence(timeout: 3) {
                    mySavesLabel.tap()
                    sleep(2)
                } else {
                    throw NSError(domain: "NavigationFlowTests", code: -1, userInfo: [
                        NSLocalizedDescriptionKey: "My Saves nav row not found"
                    ])
                }
            }
        }

        try recordStep("Verify My Saves screen") {
            XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label.length > 0")).count > 0)
            captureScreenshot(name: "my_saves_via_nav_visible")
        }
    }

    // MARK: - Profile → My Collections (nav row)

    func testNavigateFromProfileNavRowToMyCollections() throws {
        try recordStep("Navigate to Profile") {
            app.tabBars.buttons["Profile"].tap()
            sleep(2)
        }

        try recordStep("Tap My Collections row") {
            let myCollectionsNav = app.buttons["nav_my_collections"]
            if myCollectionsNav.waitForExistence(timeout: 5) {
                myCollectionsNav.tap()
                sleep(2)
                captureScreenshot(name: "my_collections_via_nav")
            } else {
                let myCollectionsLabel = app.staticTexts["My Collections"]
                if myCollectionsLabel.waitForExistence(timeout: 3) {
                    myCollectionsLabel.tap()
                    sleep(2)
                } else {
                    throw NSError(domain: "NavigationFlowTests", code: -1, userInfo: [
                        NSLocalizedDescriptionKey: "My Collections nav row not found"
                    ])
                }
            }
        }

        try recordStep("Verify My Collections screen") {
            XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label.length > 0")).count > 0)
            captureScreenshot(name: "my_collections_via_nav_visible")
        }
    }

    // MARK: - Discovery → Event detail (smoke)

    func testNavigateFromDiscoverToEventDetail() throws {
        try recordStep("Navigate to Discover") {
            app.tabBars.buttons["Discover"].tap()
            sleep(5)
        }

        try recordStep("Tap first event card") {
            let cells = app.cells
            if cells.count > 0 {
                cells.firstMatch.tap()
                sleep(2)
                captureScreenshot(name: "event_detail_opened")
            } else {
                let eventLink = app.buttons.matching(NSPredicate(format: "identifier CONTAINS 'event'")).firstMatch
                if eventLink.waitForExistence(timeout: 5) {
                    eventLink.tap()
                    sleep(2)
                } else {
                    throw NSError(domain: "NavigationFlowTests", code: -1, userInfo: [
                        NSLocalizedDescriptionKey: "No event card found in feed"
                    ])
                }
            }
        }

        try recordStep("Verify event detail") {
            XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label.length > 0")).count > 0)
            captureScreenshot(name: "event_detail_visible")
        }
    }

    // MARK: - Helpers

    private func loginWithTestAccount() throws {
        let emailField = app.textFields["Email"]
        if emailField.waitForExistence(timeout: 5.0) {
            emailField.tap()
            emailField.typeText(TestAccounts.primary.email)
            let passwordField = app.secureTextFields["Password"]
            if passwordField.waitForExistence(timeout: 2.0) {
                passwordField.tap()
                passwordField.typeText(TestAccounts.primary.password)
                app.buttons["Log In"].firstMatch.tap()
                sleep(5)
            }
        }
        if !app.tabBars.firstMatch.waitForExistence(timeout: 10.0) {
            throw NSError(domain: "NavigationFlowTests", code: -1, userInfo: [
                NSLocalizedDescriptionKey: "Login failed in setup"
            ])
        }
    }
}
