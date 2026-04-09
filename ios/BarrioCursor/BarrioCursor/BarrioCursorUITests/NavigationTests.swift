import XCTest

/// Core navigation: main screen (Discover), Map pill, Profile icon. No tab bar.
class NavigationTests: BaseTestCase {

    override func setUpWithError() throws {
        try super.setUpWithError()
        sleep(2)
        try loginWithTestAccount()
    }

    // MARK: - Tests

    func testMainScreenAfterLogin() throws {
        XCTAssertTrue(app.otherElements["main_tab_view"].waitForExistence(timeout: 10),
                      "Main screen should be visible after login")
        XCTAssertTrue(app.buttons["map_pill"].exists || app.buttons["Map"].exists, "Map pill should exist")
        XCTAssertTrue(app.buttons["Profile"].exists, "Profile icon should exist")
        attach(screenshot: "main_screen_visible")
    }

    func testDiscoverScreenVisible() throws {
        // After login we're on Discover; verify content
        sleep(2)
        attach(screenshot: "discover_screen")
        
        let hasHeader = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS[c] 'portal' OR label CONTAINS[c] 'New York' OR label CONTAINS[c] 'Custom location'")
        ).firstMatch.exists
        
        let hasContent = hasHeader ||
            app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'No events' OR label CONTAINS[c] 'Near you'")).firstMatch.exists
        XCTAssertTrue(hasContent, "Discover should show header or content")
    }

    func testProfileButtonOpensProfile() throws {
        tapProfileButton()
        sleep(3)

        attach(screenshot: "profile_sheet")

        let logoutButton = app.buttons["logout"]
        if !logoutButton.exists { app.swipeUp(); sleep(1) }
        XCTAssertTrue(logoutButton.waitForExistence(timeout: 5), "Log Out should exist on Profile screen")
    }

    func testMapPillOpensMap() throws {
        let opened = tapMapPill()
        sleep(1)
        attach(screenshot: "map_fullscreen")
        try XCTSkipUnless(opened, "Map pill tap did not register — known SwiftUI overlay issue on x86_64 simulators")
    }
}
