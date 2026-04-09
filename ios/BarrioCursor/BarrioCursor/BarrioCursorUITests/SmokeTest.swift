import XCTest

/// Smoke test: validates the UI testing pipeline works, then checks every
/// main screen for layout problems (overlapping buttons, small tap targets,
/// off-screen elements).
class SmokeTest: BaseTestCase {

    // MARK: - Basic Launch

    func testAppLaunches() throws {
        sleep(2)

        print("=== ACCESSIBILITY HIERARCHY START ===")
        print(app.debugDescription)
        print("=== ACCESSIBILITY HIERARCHY END ===")

        let onAuthScreen = app.buttons["Log In"].exists
            || app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Log in here'")).firstMatch.exists
            || app.buttons["Sign Up"].exists
            || app.textFields["login_email"].exists
            || app.textFields.matching(NSPredicate(format: "placeholderValue == 'Email'")).firstMatch.exists

        let onMainScreen = app.otherElements["main_tab_view"].exists
            || app.buttons["map_pill"].exists
            || app.buttons["Map"].exists
            || app.buttons["Profile"].exists

        attach(screenshot: "smoke_launch")

        XCTAssertTrue(
            onAuthScreen || onMainScreen,
            "App launched but couldn't identify auth screen or main screen."
        )

        if onAuthScreen {
            print("✅ App launched to AUTH screen")
        } else {
            print("✅ App launched to MAIN screen (user is logged in)")
        }
    }

    // MARK: - Layout Sanity Across All Screens

    func testLayoutSanityAllScreens() throws {
        continueAfterFailure = true

        try loginWithTestAccount()

        // After login we're on Discover
        sleep(2)
        captureScreenshot(name: "layout_discover")
        runLayoutSanityChecks()

        // Open Map (floating pill) — may not work on x86_64 simulators
        if tapMapPill() {
            captureScreenshot(name: "layout_map")
            runLayoutSanityChecks()

            // Dismiss map (Discover pill on map screen)
            if app.buttons["Discover"].exists {
                app.buttons["Discover"].tap()
                sleep(1)
            }
        }

        // Open Profile (header icon)
        tapProfileButton()
        sleep(1)
        captureScreenshot(name: "layout_profile")
        runLayoutSanityChecks()
    }
}
