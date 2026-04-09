import XCTest

/// Base test case with screenshot capture, log collection, and error reporting
class BaseTestCase: XCTestCase {
    
    // MARK: - Test Configuration
    
    /// Test account credentials - update these with your test accounts
    struct TestAccounts {
        static let primary = TestAccount(
            email: "test2@barrio.app",
            password: "TestPassword123!"
        )
        static let secondary = TestAccount(
            email: "test1@barrio.app",
            password: "TestPassword123!"
        )
    }
    
    struct TestAccount {
        let email: String
        let password: String
    }
    
    // MARK: - Test State
    
    var app: XCUIApplication!
    var testReport: TestReport!
    var screenshotDir: URL!
    var logsDir: URL!
    
    // MARK: - Setup & Teardown
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        continueAfterFailure = false
        
        // Initialize app
        app = XCUIApplication()
        app.launchArguments.append("--uitesting")
        app.launch()
        
        // Dismiss any system dialogs (password save, notifications, etc.)
        addUIInterruptionMonitor(withDescription: "System Dialog") { alert in
            let dominated = ["Not Now", "Don't Save", "Cancel", "Dismiss", "Later", "Don't Allow"]
            for label in dominated {
                let btn = alert.buttons[label]
                if btn.exists { btn.tap(); return true }
            }
            // Fallback: tap the first button
            if alert.buttons.count > 0 {
                alert.buttons.firstMatch.tap()
                return true
            }
            return false
        }
        
        // Create test report
        testReport = TestReport(testName: name)
        
        // Create directories for artifacts
        let testDir = createTestDirectory()
        screenshotDir = testDir.appendingPathComponent("screenshots")
        logsDir = testDir.appendingPathComponent("logs")
        
        try FileManager.default.createDirectory(at: screenshotDir, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: logsDir, withIntermediateDirectories: true)
        
        // Capture initial state
        captureScreenshot(name: "00_initial_state")
    }
    
    override func tearDownWithError() throws {
        // Capture final state and write reports only if references are still valid
        if app != nil, testReport != nil, screenshotDir != nil {
            captureScreenshot(name: "99_final_state")
        }
        if testReport != nil, logsDir != nil {
            collectLogs()
        }
        if testReport != nil, screenshotDir != nil {
            generateReport()
        }

        // Clean up app state if needed
        if app?.state == .runningForeground {
            if isLoggedIn() {
                attemptLogout()
            }
        }

        app = nil
        try super.tearDownWithError()
    }
    
    // MARK: - Screenshot Capture
    
    /// Capture a screenshot with automatic naming
    func captureScreenshot(name: String, step: String? = nil) {
        guard let app = app, var report = testReport, let screenshotDir = screenshotDir else { return }
        let screenshot = app.screenshot()
        let filename = String(format: "%02d_%@", report.stepCount, name)
        let fileURL = screenshotDir.appendingPathComponent("\(filename).png")

        do {
            try screenshot.pngRepresentation.write(to: fileURL)
            report.addScreenshot(filename: filename, step: step ?? name)
            testReport = report
            print("📸 Screenshot captured: \(filename)")
        } catch {
            print("❌ Failed to save screenshot: \(error)")
        }
    }
    
    // MARK: - Log Collection
    
    /// Collect device logs for the test session
    func collectLogs() {
        guard let testReport = testReport, let logsDir = logsDir else { return }
        // XCUITest doesn't have direct access to console logs, but we can:
        // 1. Capture any visible error messages in the UI
        // 2. Use Xcode's log collection in CI/CD
        // 3. Store test execution metadata

        let formatter = ISO8601DateFormatter()
        let logData: [String: Any] = [
            "testName": name,
            "duration": testReport.duration,
            "steps": testReport.steps.map { step in
                [
                    "name": step.name,
                    "status": step.status.rawValue,
                    "timestamp": formatter.string(from: step.timestamp),
                    "error": step.error ?? ""
                ]
            },
            "screenshots": testReport.screenshots.map { $0.filename }
        ]
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: logData, options: .prettyPrinted)
            let logURL = logsDir.appendingPathComponent("test_log.json")
            try jsonData.write(to: logURL)
        } catch {
            print("❌ Failed to save logs: \(error)")
        }
    }
    
    // MARK: - Test Step Tracking
    
    /// Record a test step with automatic screenshot
    func recordStep(_ name: String, action: () throws -> Void) rethrows {
        testReport.startStep(name)
        captureScreenshot(name: name.sanitizedForFilename(), step: name)
        
        do {
            try action()
            testReport.completeStep(success: true)
        } catch {
            testReport.completeStep(success: false, error: error.localizedDescription)
            captureScreenshot(name: "\(name.sanitizedForFilename())_error", step: "\(name) - ERROR")
            throw error
        }
    }
    
    // MARK: - Helper Methods
    
    /// Wait for element to appear with timeout
    func waitForElement(_ element: XCUIElement, timeout: TimeInterval = 10.0) -> Bool {
        return element.waitForExistence(timeout: timeout)
    }
    
    /// Wait for element to disappear
    func waitForElementToDisappear(_ element: XCUIElement, timeout: TimeInterval = 10.0) -> Bool {
        let predicate = NSPredicate(format: "exists == false")
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        return XCTWaiter.wait(for: [expectation], timeout: timeout) == .completed
    }
    
    /// Check if user is logged in (main screen visible: Discover + Map pill + Profile icon)
    func isLoggedIn() -> Bool {
        return app.otherElements["main_tab_view"].exists &&
               (app.buttons["map_pill"].exists || app.buttons["Map"].exists || app.buttons["Profile"].exists)
    }
    
    /// Attempt to logout (gracefully handles if already logged out)
    func attemptLogout() {
        // Pop any navigation stacks before tapping the Profile button —
        // pressing back buttons first avoids "multiple matches" when a
        // back button is also labeled "Profile".
        for _ in 0..<5 {
            let backButton = app.navigationBars.buttons.matching(
                NSPredicate(format: "identifier == 'BackButton'")
            ).firstMatch
            guard backButton.exists else { break }
            backButton.tap()
            sleep(1)
        }
        
        // Open Profile (header icon; use .firstMatch to avoid ambiguity)
        let profileTab = app.buttons.matching(
            NSPredicate(format: "label == 'Profile'")
        ).firstMatch
        if profileTab.exists {
            robustTap(profileTab)
        }
        
        // Look for "Log Out" button (identifier or label) and confirm alert
        let logoutButton = app.buttons["logout"].exists ? app.buttons["logout"] : app.buttons.matching(
            NSPredicate(format: "label CONTAINS 'Log Out'")
        ).firstMatch
        if logoutButton.waitForExistence(timeout: 5) {
            logoutButton.tap()
            let confirm = app.alerts.buttons["Log Out"]
            if confirm.waitForExistence(timeout: 3) {
                confirm.tap()
            }
        }
    }
    
    /// Convenience helper: ensure we're logged in with the primary test account.
    /// Safe to call from setUp; returns immediately if already logged in.
    /// Retries once on failure to handle simulator cold-start timing issues.
    func loginWithTestAccount(_ account: TestAccount = TestAccounts.primary) throws {
        if isLoggedIn() {
            dismissSystemDialogs()
            return
        }

        for attempt in 1...2 {
            do {
                try performLogin(account)
                dismissSystemDialogs()
                return
            } catch {
                if attempt == 2 { throw error }
                // Retry: terminate and relaunch to get a clean state
                app.terminate()
                sleep(3)
                app.launch()
                sleep(2)
            }
        }
    }

    private func performLogin(_ account: TestAccount) throws {
        let loginLink = app.buttons.matching(
            NSPredicate(format: "identifier == 'switch_to_login' OR label CONTAINS[c] 'Log in here' OR label CONTAINS[c] 'LOG IN'")
        ).firstMatch
        if loginLink.waitForExistence(timeout: 5) && loginLink.label.localizedCaseInsensitiveContains("log in here") {
            loginLink.tap()
            sleep(1)
        }

        let emailField = app.textFields["login_email"].exists
            ? app.textFields["login_email"]
            : app.textFields.matching(NSPredicate(format: "placeholderValue == 'Email'")).firstMatch
        guard emailField.waitForExistence(timeout: 5) else {
            throw NSError(domain: "BaseTestCase", code: -1, userInfo: [
                NSLocalizedDescriptionKey: "Email field not found for login helper"
            ])
        }
        // Tap to focus; use coordinate tap so focus is reliably established before typing (helps after long idle timeout)
        if emailField.frame.width > 0, emailField.frame.height > 0 {
            emailField.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        } else {
            emailField.tap()
        }
        sleep(2)
        // Re-tap once to re-establish focus if simulator was slow to grant it
        if emailField.exists && emailField.isHittable {
            emailField.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
            sleep(1)
        }
        emailField.typeText(account.email)

        let passwordField = app.secureTextFields["login_password"].exists
            ? app.secureTextFields["login_password"]
            : app.secureTextFields.matching(NSPredicate(format: "placeholderValue == 'Password'")).firstMatch
        guard passwordField.waitForExistence(timeout: 5) else {
            throw NSError(domain: "BaseTestCase", code: -1, userInfo: [
                NSLocalizedDescriptionKey: "Password field not found for login helper"
            ])
        }
        if passwordField.frame.width > 0, passwordField.frame.height > 0 {
            passwordField.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        } else {
            passwordField.tap()
        }
        sleep(2)
        if passwordField.exists && passwordField.isHittable {
            passwordField.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
            sleep(1)
        }
        passwordField.typeText(account.password)

        let loginButton = app.buttons["login_submit"].exists
            ? app.buttons["login_submit"]
            : app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Log In' OR label CONTAINS[c] 'LOG IN'")).firstMatch
        guard loginButton.exists else {
            throw NSError(domain: "BaseTestCase", code: -1, userInfo: [
                NSLocalizedDescriptionKey: "Log In button not found for login helper"
            ])
        }
        loginButton.tap()

        let mainTabView = app.otherElements["main_tab_view"]
        guard mainTabView.waitForExistence(timeout: 15) else {
            throw NSError(domain: "BaseTestCase", code: -1, userInfo: [
                NSLocalizedDescriptionKey: "Login failed — main tab view did not appear"
            ])
        }
    }
    
    /// Tap an element, falling back to coordinate-based tap when XCUITest
    /// reports hit point {-1, -1} (common for overlay / safe-area elements).
    func robustTap(_ element: XCUIElement) {
        guard element.exists else { return }
        let frame = element.frame
        if frame.origin.x >= 0, frame.origin.y >= 0,
           frame.width > 0, frame.height > 0 {
            element.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        } else {
            element.tap()
        }
    }

    /// Tap the map pill. Tries multiple strategies because SwiftUI overlay
    /// buttons don't reliably receive XCUITest taps on x86_64 simulators.
    /// Returns `true` if the map appeared after tapping.
    @discardableResult
    func tapMapPill() -> Bool {
        // Strategy 1: coordinate tap via element frame
        let pill = app.buttons["map_pill"]
        if pill.exists {
            let frame = pill.frame
            if frame.width > 0, frame.height > 0 {
                let normX = frame.midX / app.frame.width
                let normY = frame.midY / app.frame.height
                app.coordinate(withNormalizedOffset: CGVector(dx: normX, dy: normY)).tap()
                sleep(2)
                if mapIsVisible() { return true }
            }
        }

        // Strategy 2: label-based lookup + coordinate tap
        let mapBtn = app.buttons.matching(NSPredicate(format: "label == 'Map'")).firstMatch
        if mapBtn.exists {
            let frame = mapBtn.frame
            if frame.width > 0, frame.height > 0 {
                let normX = frame.midX / app.frame.width
                let normY = frame.midY / app.frame.height
                app.coordinate(withNormalizedOffset: CGVector(dx: normX, dy: normY)).tap()
                sleep(2)
                if mapIsVisible() { return true }
            }
        }

        // Strategy 3: direct element tap
        if pill.exists && pill.isHittable {
            pill.tap()
            sleep(2)
            if mapIsVisible() { return true }
        }

        // Strategy 4: hardcoded bottom-right where pill sits
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.88, dy: 0.90)).tap()
        sleep(2)
        return mapIsVisible()
    }

    private func mapIsVisible() -> Bool {
        return app.maps.firstMatch.exists
            || app.otherElements["Map"].exists
            || app.buttons["Discover"].exists
    }

    /// Tap the Profile button in the Discover header.
    /// Uses coordinate-based tap for reliability since `.buttonStyle(.plain)`
    /// buttons sometimes don't respond to direct XCUITest taps.
    func tapProfileButton() {
        let profileBtn = app.buttons["Profile"]
        guard profileBtn.waitForExistence(timeout: 5) else { return }

        // Strategy 1: coordinate tap derived from the element's frame
        let frame = profileBtn.frame
        if frame.width > 0, frame.height > 0 {
            let normX = frame.midX / app.frame.width
            let normY = frame.midY / app.frame.height
            app.coordinate(withNormalizedOffset: CGVector(dx: normX, dy: normY)).tap()
            sleep(2)
            // Check if it worked (profile sheet has "logout" or "Log Out")
            if app.buttons["logout"].exists || app.buttons.matching(NSPredicate(format: "label CONTAINS 'Log Out'")).firstMatch.exists {
                return
            }
        }

        // Strategy 2: direct element tap
        if profileBtn.isHittable {
            profileBtn.tap()
            sleep(2)
            if app.buttons["logout"].exists || app.buttons.matching(NSPredicate(format: "label CONTAINS 'Log Out'")).firstMatch.exists {
                return
            }
        }

        // Strategy 3: normalized offset on the element itself
        profileBtn.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
    }

    /// Dismiss any system dialogs (password save, notifications, etc.)
    /// by tapping an element to trigger the interruption monitors.
    func dismissSystemDialogs() {
        // Tap near the top-left (status bar area) to trigger interruption monitors
        // without accidentally tapping content cards that open detail views
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.1, dy: 0.02)).tap()
        sleep(1)
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.1, dy: 0.02)).tap()
        sleep(1)
    }
    
    /// Create test directory for this test run
    private func createTestDirectory() -> URL {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let timestamp = formatter.string(from: Date())
        let testName = name.replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: "[", with: "")
            .replacingOccurrences(of: "]", with: "")
        
        let testDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("BarrioUITests")
            .appendingPathComponent("\(timestamp)_\(testName)")
        
        try? FileManager.default.createDirectory(at: testDir, withIntermediateDirectories: true)
        return testDir
    }
    
    /// Generate test report
    private func generateReport() {
        guard let testReport = testReport, let screenshotDir = screenshotDir else { return }
        var report = testReport
        report.finalize()

        // Generate JSON report
        let jsonURL = screenshotDir.deletingLastPathComponent().appendingPathComponent("test_report.json")
        report.saveJSON(to: jsonURL)

        // Generate Markdown report
        let markdownURL = screenshotDir.deletingLastPathComponent().appendingPathComponent("test_report.md")
        report.saveMarkdown(to: markdownURL, screenshotsDir: screenshotDir)

        print("\n📊 Test Report Generated:")
        print("   JSON: \(jsonURL.path)")
        print("   Markdown: \(markdownURL.path)")
        print("   Screenshots: \(screenshotDir.path)")
    }
    
    // MARK: - XCTest Attachment Convenience
    
    /// Attach a screenshot to Xcode's test results (in addition to filesystem capture).
    func attach(screenshot name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .deleteOnSuccess  // Keep only on failure to reduce memory between tests
        add(attachment)
    }
    
    // MARK: - Layout Sanity Checks
    
    /// Run all layout sanity checks on the current screen.
    func runLayoutSanityChecks() {
        assertNoOverlappingInteractiveElements()
        assertMinimumTapTargets()
        assertNoOffScreenInteractiveElements()
    }
    
    /// Fails if any two hittable interactive elements overlap by more than `tolerance` points.
    func assertNoOverlappingInteractiveElements(tolerance: CGFloat = 4.0) {
        let elements = collectHittableInteractiveElements()
        var overlaps: [String] = []
        
        for i in 0..<elements.count {
            for j in (i + 1)..<elements.count {
                let intersection = elements[i].frame.intersection(elements[j].frame)
                if !intersection.isNull
                    && intersection.width > tolerance
                    && intersection.height > tolerance {
                    overlaps.append(
                        "'\(elements[i].label)' & '\(elements[j].label)' (\(Int(intersection.width))×\(Int(intersection.height))pt)"
                    )
                }
            }
        }
        
        if !overlaps.isEmpty {
            captureScreenshot(name: "overlapping_elements")
            XCTFail("\(overlaps.count) overlapping element pair(s): \(overlaps.joined(separator: "; "))")
        }
    }
    
    /// Fails if any hittable interactive element is smaller than Apple's 44×44pt minimum.
    func assertMinimumTapTargets(minSize: CGFloat = 44.0) {
        let elements = collectHittableInteractiveElements()
        var violations: [String] = []
        
        for el in elements {
            guard el.frame.width > 0, el.frame.height > 0 else { continue }
            if el.frame.width < minSize || el.frame.height < minSize {
                violations.append("'\(el.label)' (\(Int(el.frame.width))×\(Int(el.frame.height))pt)")
            }
        }
        
        if !violations.isEmpty {
            captureScreenshot(name: "small_tap_targets")
            XCTFail(
                "\(violations.count) element(s) below \(Int(minSize))×\(Int(minSize))pt minimum: "
                + violations.joined(separator: ", ")
            )
        }
    }
    
    /// Fails if any hittable interactive element is entirely outside the screen bounds.
    func assertNoOffScreenInteractiveElements() {
        let screen = app.frame
        let elements = collectHittableInteractiveElements()
        var offScreen: [String] = []
        
        for el in elements {
            if el.frame.maxX < 0 || el.frame.maxY < 0
                || el.frame.minX > screen.width || el.frame.minY > screen.height {
                offScreen.append("'\(el.label)' at \(el.frame)")
            }
        }
        
        if !offScreen.isEmpty {
            captureScreenshot(name: "offscreen_elements")
            XCTFail("\(offScreen.count) off-screen element(s): \(offScreen.joined(separator: "; "))")
        }
    }
    
    /// Gather all hittable buttons, text fields, secure fields, and switches on screen.
    private func collectHittableInteractiveElements() -> [(label: String, frame: CGRect)] {
        var results: [(label: String, frame: CGRect)] = []
        
        for button in app.buttons.allElementsBoundByIndex where button.isHittable && button.frame.width > 0 {
            let label = button.label.isEmpty ? (button.identifier.isEmpty ? "Button" : button.identifier) : button.label
            results.append((label: label, frame: button.frame))
        }
        for field in app.textFields.allElementsBoundByIndex where field.isHittable && field.frame.width > 0 {
            let label = field.placeholderValue ?? (field.identifier.isEmpty ? "TextField" : field.identifier)
            results.append((label: label, frame: field.frame))
        }
        for field in app.secureTextFields.allElementsBoundByIndex where field.isHittable && field.frame.width > 0 {
            let label = field.placeholderValue ?? (field.identifier.isEmpty ? "SecureField" : field.identifier)
            results.append((label: label, frame: field.frame))
        }
        for toggle in app.switches.allElementsBoundByIndex where toggle.isHittable && toggle.frame.width > 0 {
            let label = toggle.label.isEmpty ? (toggle.identifier.isEmpty ? "Switch" : toggle.identifier) : toggle.label
            results.append((label: label, frame: toggle.frame))
        }
        
        return results
    }
}

// MARK: - Shared XCUIElement helpers

extension XCUIElement {
    func clearText() {
        guard let stringValue = self.value as? String else {
            return
        }
        
        tap()
        
        let deleteString = String(repeating: XCUIKeyboardKey.delete.rawValue, count: stringValue.count)
        typeText(deleteString)
    }
}

// MARK: - String Extensions

extension String {
    func sanitizedForFilename() -> String {
        return self
            .replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: "[", with: "")
            .replacingOccurrences(of: "]", with: "")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "\\", with: "_")
    }
}
