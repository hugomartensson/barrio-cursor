# Barrio UI Testing System

Automated UI testing and bug detection system for the Barrio iOS app. This system runs tests against the real Supabase API, captures screenshots, logs errors, and generates AI-consumable reports.

## Overview

This testing system provides:

1. **Automated Test Execution** - Runs all core user flows automatically
2. **Intelligent Failure Detection** - Captures screenshots, API errors, and UI issues
3. **Structured Reports** - Generates JSON and Markdown reports with all artifacts
4. **Automated Feedback Loop** - Continuously runs tests and waits for fixes

## Test Coverage

### Core Flows Tested

- ✅ **Authentication** (`LoginFlowTests.swift`)
  - Login with valid credentials
  - Login with invalid credentials
  - Signup flow

- ✅ **Event Discovery** (`DiscoveryFlowTests.swift`)
  - Browse feed view
  - View event details
  - Filter events (category, following, time)
  - Map view discovery
  - **Map to Story flow** - Tap pin → Story viewer → Swipe media → View details

- ✅ **Event Creation** (`EventCreationTests.swift`)
  - Create event with all fields
  - Media upload
  - Location selection
  - Form validation

- ✅ **Plans** (`PlansFlowTests.swift`)
  - Create plan
  - Add event to plan
  - View plans list
  - Plan details

- ✅ **Profiles** (`ProfileFlowTests.swift`)
  - View own profile
  - Edit profile
  - View other user profiles

## Setup

### 1. Configure Test Accounts

Edit `BaseTestCase.swift` and update the test account credentials:

```swift
struct TestAccounts {
    static let primary = TestAccount(
        email: "test1@barrio.app",  // Update with your test account
        password: "TestPassword123!"
    )
    static let secondary = TestAccount(
        email: "test2@barrio.app",  // Update with your test account
        password: "TestPassword123!"
    )
}
```

**Important:** These accounts must exist in your Supabase database and have appropriate test data.

### 2. Add UI Test Target to Xcode

1. Open `BarrioCursor.xcodeproj` in Xcode
2. File → New → Target
3. Select "UI Testing Bundle"
4. Name it `BarrioCursorUITests`
5. Add the test files from this directory to the target

### 3. Configure Accessibility Identifiers

For reliable test execution, add accessibility identifiers to key UI elements in your SwiftUI views:

```swift
// Example: Login button
Button("Log In") {
    // ...
}
.accessibilityIdentifier("Log In")

// Example: Email field
TextField("Email", text: $email)
    .accessibilityIdentifier("Email")
```

**Key elements to add identifiers:**
- All buttons (Login, Create, Save, etc.)
- Text fields (Email, Password, Title, etc.)
- Tab bar items (Map, Feed, Profile)
- Navigation elements

### 4. Grant Permissions

The simulator/device needs:
- **Location permissions** - For map and location-based features
- **Photo library access** - For event creation with media

These are typically handled by iOS permission dialogs during test execution.

## Running Tests

### Manual Test Run

```bash
cd ios/BarrioCursorUITests
./run-tests.sh
```

This will:
1. Build the test target
2. Run all UI tests
3. Generate reports in `test-reports/`
4. Create JSON and Markdown reports

### Automated Feedback Loop

```bash
cd ios/BarrioCursorUITests
./auto-feedback-loop.sh
```

This will:
1. Run tests
2. Generate reports
3. Monitor for code changes
4. Automatically re-run tests when changes are detected
5. Continue until tests pass or max iterations reached

**Stop the loop:** Press `Ctrl+C`

### Run Specific Test Class

```bash
xcodebuild test \
    -project BarrioCursor.xcodeproj \
    -scheme BarrioCursor \
    -destination 'platform=iOS Simulator,name=iPhone 15' \
    -only-testing:BarrioCursorUITests/LoginFlowTests
```

## Test Reports

Reports are generated in `test-reports/TIMESTAMP/` with:

### Files Generated

- **`SUMMARY.md`** - Quick overview of test run
- **`ai-report.json`** - Structured JSON for AI consumption
- **`test_report.json`** - Detailed test results (per test)
- **`test_report.md`** - Human-readable markdown report
- **`screenshots/`** - All screenshots captured during tests
- **`TestResults.xcresult`** - Xcode test results bundle
- **`build.log`** - Build and test execution log

### Report Structure

```json
{
  "testRun": {
    "timestamp": "2026-01-25_14-30-00",
    "status": "failed",
    "exitCode": 1
  },
  "reports": [
    {
      "testName": "testLoginWithValidCredentials",
      "status": "failed",
      "steps": [
        {
          "name": "Enter Email",
          "status": "passed",
          "screenshot": "01_enter_email.png"
        },
        {
          "name": "Submit Login",
          "status": "failed",
          "error": "Button not found",
          "screenshot": "02_submit_login_error.png"
        }
      ]
    }
  ]
}
```

## Integration with AI Fixes

### How It Works

1. **Tests Run** → Generate `ai-report.json`
2. **AI Reads Report** → Automatically identifies bugs
3. **AI Fixes Bugs** → Implements fixes in code
4. **Tests Re-run** → Automated loop detects changes and verifies fixes
5. **Loop Continues** → Until all tests pass

### The "You Fix" Step Explained

**"You fix" = The AI assistant automatically fixes bugs**

The workflow is designed so that:
- Tests run automatically
- Reports are generated automatically
- **AI reads reports and fixes bugs automatically**
- Tests re-run automatically
- Process repeats until all pass

**You (the human) don't need to manually:**
- Read bug reports
- Identify issues
- Write fixes
- Verify fixes

**The AI handles it all automatically!**

### How AI Consumes Reports

The AI reads the JSON reports to understand:
- Which tests failed
- What steps failed
- Screenshots of failures
- Error messages
- API response issues

Then automatically:
- Identifies root causes
- Implements fixes
- Saves code changes
- Tests verify fixes automatically

### Example Workflow

```bash
# 1. Start automated feedback loop
./auto-feedback-loop.sh

# 2. Tests run automatically
# 3. Reports generated automatically
# 4. AI reads reports and fixes bugs automatically
# 5. Tests re-run automatically
# 6. Loop continues until all pass
```

**You just start it and let it run!** 🚀

## Customization

### Adjusting Test Timeouts

Edit `BaseTestCase.swift`:

```swift
func waitForElement(_ element: XCUIElement, timeout: TimeInterval = 10.0) -> Bool {
    // Increase timeout for slow API calls
    return element.waitForExistence(timeout: timeout)
}
```

### Adding New Tests

1. Create new test class inheriting from `BaseTestCase`
2. Implement test methods (must start with `test`)
3. Use `recordStep()` for automatic screenshot capture
4. Use `captureScreenshot()` for manual screenshots

Example:
```swift
class MyNewTests: BaseTestCase {
    func testMyFeature() throws {
        try recordStep("Do something") {
            // Test code
        }
        
        try recordStep("Verify result") {
            XCTAssertTrue(something)
        }
    }
}
```

### Customizing Reports

Edit `TestReport.swift` to add custom fields or change report format.

## Troubleshooting

### Tests Can't Find UI Elements

**Problem:** Tests fail with "element not found"

**Solutions:**
1. Add accessibility identifiers to UI elements
2. Increase wait timeouts
3. Check if element is actually visible (not hidden/off-screen)
4. Use Xcode's UI test recorder to find correct selectors

### Screenshots Not Captured

**Problem:** Screenshot directory is empty

**Solutions:**
1. Check file permissions
2. Verify temp directory is writable
3. Check Xcode console for errors

### Tests Hang or Timeout

**Problem:** Tests wait indefinitely

**Solutions:**
1. Check if API is responding (test manually)
2. Increase timeouts for slow operations
3. Verify network connectivity
4. Check for infinite loading states in UI

### Login Fails

**Problem:** Can't log in with test accounts

**Solutions:**
1. Verify test account credentials in `BaseTestCase.swift`
2. Ensure accounts exist in Supabase
3. Check if accounts are locked/disabled
4. Verify API endpoint is correct

## Best Practices

1. **Keep Tests Independent** - Each test should work in isolation
2. **Use Test Accounts** - Don't use production accounts
3. **Clean Up** - Tests should clean up after themselves (delete test data)
4. **Fast Feedback** - Keep tests fast for quick iteration
5. **Clear Assertions** - Use descriptive error messages

## CI/CD Integration

### GitHub Actions Example

```yaml
name: UI Tests

on: [push, pull_request]

jobs:
  test:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v2
      - name: Run UI Tests
        run: |
          cd ios/BarrioCursorUITests
          ./run-tests.sh
      - name: Upload Reports
        uses: actions/upload-artifact@v2
        with:
          name: test-reports
          path: ios/test-reports/
```

## Next Steps

1. ✅ Add accessibility identifiers to all key UI elements
2. ✅ Configure test accounts in Supabase
3. ✅ Run initial test suite
4. ✅ Review and fix any test failures
5. ✅ Set up automated feedback loop
6. ✅ Integrate with your development workflow

## Support

For issues or questions:
1. Check test logs in `test-reports/`
2. Review Xcode console output
3. Check API health: `curl http://localhost:3000/api/health`
4. Verify test account access

---

**Happy Testing! 🧪**
