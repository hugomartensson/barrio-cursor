import XCTest

/// Flow 2 (collections) and Flow 3 (creation) — PRD-aligned.
/// Collections: open create-collection form from Profile. Creation: open event/spot forms from Profile.
/// API is disabled in UI-testing mode so we only verify forms open, not submission.
class CollectionsFlowTests: BaseTestCase {

    override func setUpWithError() throws {
        try super.setUpWithError()
        try loginWithTestAccount()
    }

    func testCreateCollectionFromProfile() throws {
        try recordStep("Open Profile and Create Collection form") {
            tapProfileButton()
            sleep(2)
            let createCollectionBtn = app.buttons["create_collection_action"]
            XCTAssertTrue(waitForElement(createCollectionBtn, timeout: 10), "Create collection action card should exist on Profile")
            createCollectionBtn.tap()
            sleep(3) // Allow sheet to present
            captureScreenshot(name: "create_collection_sheet")
        }

        try recordStep("Verify Create Collection form") {
            // CreateCollectionView: header "New Collection", name field identifier "title", placeholder "Collection name", button "create"
            let newCollectionTitle = app.staticTexts["New Collection"]
            let nameField = app.textFields["title"]
            let createButton = app.buttons["create"].exists ? app.buttons["create"] : app.buttons.matching(NSPredicate(format: "label CONTAINS 'Create'")).firstMatch
            let hasTitle = newCollectionTitle.waitForExistence(timeout: 10)
            let hasNameField = nameField.waitForExistence(timeout: 10)
            let hasCreateBtn = createButton.waitForExistence(timeout: 5)
            XCTAssertTrue(hasTitle || hasNameField, "Create collection sheet should show 'New Collection' or name field")
            XCTAssertTrue(hasCreateBtn, "Create collection sheet should show create button")
            captureScreenshot(name: "collection_form_visible")
        }
    }

    func testCreateEventFormOpens() throws {
        try recordStep("Open Profile and Create Event form") {
            tapProfileButton()
            sleep(2)
            let createEventBtn = app.buttons["create_event_action"]
            XCTAssertTrue(waitForElement(createEventBtn, timeout: 10), "Create event action card should exist on Profile")
            createEventBtn.tap()
            sleep(2)
            captureScreenshot(name: "create_event_sheet")
        }

        try recordStep("Verify Create Event form") {
            let titleField = app.textFields["title"].exists ? app.textFields["title"] : app.textFields.matching(NSPredicate(format: "identifier == 'title'")).firstMatch
            let createButton = app.buttons["create"].exists ? app.buttons["create"] : app.buttons.matching(NSPredicate(format: "label CONTAINS 'Create'")).firstMatch
            XCTAssertTrue(titleField.waitForExistence(timeout: 10), "Create event sheet should show title field")
            XCTAssertTrue(createButton.waitForExistence(timeout: 5), "Create event sheet should show create button")
            captureScreenshot(name: "event_form_visible")
        }
    }

    func testCreateSpotFormOpens() throws {
        try recordStep("Open Profile and Create Spot form") {
            tapProfileButton()
            sleep(2)
            let createSpotBtn = app.buttons["create_spot_action"]
            XCTAssertTrue(waitForElement(createSpotBtn, timeout: 10), "Create spot action card should exist on Profile")
            createSpotBtn.tap()
            sleep(2)
            captureScreenshot(name: "create_spot_sheet")
        }

        try recordStep("Verify Create Spot form") {
            let titleField = app.textFields["title"].exists ? app.textFields["title"] : app.textFields.matching(NSPredicate(format: "identifier == 'title'")).firstMatch
            let createButton = app.buttons["create"].exists ? app.buttons["create"] : app.buttons.matching(NSPredicate(format: "label CONTAINS 'Create'")).firstMatch
            XCTAssertTrue(titleField.waitForExistence(timeout: 10), "Create spot sheet should show title field")
            XCTAssertTrue(createButton.waitForExistence(timeout: 5), "Create spot sheet should show create button")
            captureScreenshot(name: "spot_form_visible")
        }
    }
}
