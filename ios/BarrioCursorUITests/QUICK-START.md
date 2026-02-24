# Quick Start Guide - Automated UI Testing

## 5-Minute Setup

### Step 1: Add UI Test Target (2 minutes)

1. Open `BarrioCursor.xcodeproj` in Xcode
2. **File → New → Target**
3. Select **"UI Testing Bundle"**
4. Name it: `BarrioCursorUITests`
5. Click **Finish**

### Step 2: Add Test Files (1 minute)

1. In Xcode, right-click the `BarrioCursorUITests` target
2. **Add Files to "BarrioCursor"...**
3. Select all `.swift` files from `ios/BarrioCursorUITests/`
4. Ensure **"Copy items if needed"** is checked
5. Ensure **"BarrioCursorUITests"** target is selected
6. Click **Add**

### Step 3: Configure Test Accounts (1 minute)

1. Open `BaseTestCase.swift` in Xcode
2. Find `TestAccounts` struct (around line 10)
3. Update with your test account credentials:

```swift
struct TestAccounts {
    static let primary = TestAccount(
        email: "your-test-account@barrio.app",  // ← Update this
        password: "YourTestPassword123!"         // ← Update this
    )
}
```

### Step 4: Backend / Database (if tests hit your API)

From repo root, ensure the server DB is migrated and seeded so Discover and collections work:

```bash
cd server && npx prisma migrate deploy && npx prisma db seed
```

### Step 5: Run Your First Test (1 minute)

```bash
cd ios/BarrioCursorUITests
./run-tests.sh
```

**Expected:** Some tests may fail initially (this is normal - we need to add accessibility identifiers)

## Next: Add Accessibility Identifiers

Tests need identifiers to find UI elements. Add these to your SwiftUI views:

### Priority 1: Critical Elements

```swift
// AuthView.swift
Button("Log In") {
    // ...
}
.accessibilityIdentifier("Log In")

TextField("Email", text: $email)
    .accessibilityIdentifier("Email")

SecureField("Password", text: $password)
    .accessibilityIdentifier("Password")

// ContentView.swift
var body: some View {
    Group {
        if authManager.isAuthenticated {
            MainTabView()
                .accessibilityIdentifier("main_tab_view")
        } else {
            AuthView()
                .accessibilityIdentifier("auth_view")
        }
    }
}

// MainTabView.swift
private func portalTabItem(icon: String, label: String, tag: Int) -> some View {
    let isActive = selectedTab == tag
    return Button {
        selectedTab = tag
    } label: {
        VStack {
            Image(systemName: icon)
            Text(label)
        }
    }
    .buttonStyle(.plain)
    .accessibilityIdentifier(label) // "Discover", "Map", "Profile"
}
```

### Priority 2: Create Event

```swift
// CreateEventView.swift
TextField("Title", text: $title)
    .accessibilityIdentifier("Title")

TextEditor(text: $description)
    .accessibilityIdentifier("Description")

Button("Create Event") {
    // ...
}
.accessibilityIdentifier("Create Event")
```

### Priority 3: Collections

```swift
// CreateCollectionSheet.swift
TextField("Name", text: $name)
    .accessibilityIdentifier("collection_name")

TextField("Description (optional)", text: $description)
    .accessibilityIdentifier("collection_description")

Button("Create") {
    // ...
}
.accessibilityIdentifier("create_collection")
```

## Running Tests

### Manual Run
```bash
cd ios/BarrioCursorUITests
./run-tests.sh
```

### Automated Feedback Loop
```bash
cd ios/BarrioCursorUITests
./auto-feedback-loop.sh
```

This will:
- Run tests
- Generate reports
- Wait for code changes
- Re-run automatically
- Continue until tests pass

**Stop:** Press `Ctrl+C`

## Viewing Reports

Reports are in: `ios/test-reports/TIMESTAMP/`

- **`SUMMARY.md`** - Quick overview
- **`ai-report.json`** - For AI consumption
- **`test_report.md`** - Human-readable
- **`screenshots/`** - All screenshots

## Common Issues

### "Element not found"
→ Add accessibility identifier to that UI element

### "Tests timeout"
→ Increase timeout in `BaseTestCase.swift` or check if API is running

### "Login fails"
→ Verify test account credentials in `BaseTestCase.swift`

## Full Documentation

See `README.md` for complete documentation.

---

**That's it!** You're ready to start automated testing. 🚀
