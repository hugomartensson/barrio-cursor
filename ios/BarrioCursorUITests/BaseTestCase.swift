import XCTest

/// Base test case with screenshot capture, log collection, and error reporting
class BaseTestCase: XCTestCase {
    
    // MARK: - Test Configuration
    
    /// Test account credentials - update these with your test accounts
    struct TestAccounts {
        static let primary = TestAccount(
            email: "test1@barrio.app",
            password: "TestPassword123!"
        )
        static let secondary = TestAccount(
            email: "test2@barrio.app",
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
        
        // Initialize app
        app = XCUIApplication()
        app.launchArguments.append("--uitesting")
        app.launch()
        
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
        // Capture final state
        captureScreenshot(name: "99_final_state")
        
        // Collect logs
        collectLogs()
        
        // Generate report
        generateReport()
        
        // Clean up app state if needed
        if app.state == .runningForeground {
            // Logout if logged in
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
        let screenshot = app.screenshot()
        let filename = String(format: "%02d_%@", testReport.stepCount, name)
        let fileURL = screenshotDir.appendingPathComponent("\(filename).png")
        
        do {
            try screenshot.pngRepresentation.write(to: fileURL)
            testReport.addScreenshot(filename: filename, step: step ?? name)
            print("📸 Screenshot captured: \(filename)")
        } catch {
            print("❌ Failed to save screenshot: \(error)")
        }
    }
    
    // MARK: - Log Collection
    
    /// Collect device logs for the test session
    func collectLogs() {
        // XCUITest doesn't have direct access to console logs, but we can:
        // 1. Capture any visible error messages in the UI
        // 2. Use Xcode's log collection in CI/CD
        // 3. Store test execution metadata
        
        let logData: [String: Any] = [
            "testName": name,
            "duration": testReport.duration,
            "steps": testReport.steps.map { step in
                [
                    "name": step.name,
                    "status": step.status.rawValue,
                    "timestamp": step.timestamp,
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
    
    /// Check if user is logged in
    func isLoggedIn() -> Bool {
        // Check for profile tab or authenticated UI elements
        return app.tabBars.buttons["Profile"].exists || 
               app.navigationBars.containing(.button, identifier: "Profile").firstMatch.exists
    }
    
    /// Attempt to logout (gracefully handles if already logged out)
    func attemptLogout() {
        // Navigate to profile if not already there
        if app.tabBars.buttons["Profile"].exists {
            app.tabBars.buttons["Profile"].tap()
        }
        
        // Look for logout button (implementation depends on your UI)
        // This is a placeholder - adjust based on your actual UI
        if app.buttons["Logout"].exists {
            app.buttons["Logout"].tap()
        }
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
        testReport.finalize()
        
        // Generate JSON report
        let jsonURL = screenshotDir.deletingLastPathComponent().appendingPathComponent("test_report.json")
        testReport.saveJSON(to: jsonURL)
        
        // Generate Markdown report
        let markdownURL = screenshotDir.deletingLastPathComponent().appendingPathComponent("test_report.md")
        testReport.saveMarkdown(to: markdownURL, screenshotsDir: screenshotDir)
        
        print("\n📊 Test Report Generated:")
        print("   JSON: \(jsonURL.path)")
        print("   Markdown: \(markdownURL.path)")
        print("   Screenshots: \(screenshotDir.path)")
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
