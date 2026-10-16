import XCTest

final class SDKUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }
    @MainActor
    private func launch(_ extra: [String] = [], reset: Bool = true) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing"] + (reset ? ["--reset-sdk"] : []) + extra
        app.launch()
        return app
    }

    @MainActor
    func testFeedbackAndConversation() throws {
        let app = launch()
        app.buttons["Send Feedback"].tap()
        let name = app.textFields["Name"]
        XCTAssertTrue(name.waitForExistence(timeout: 10))
        name.tap()
        name.typeText("SDK Tester")
        let email = app.textFields["Email"]
        email.tap()
        email.typeText("sdk-test@example.com")
        let message = app.textFields["Message"]
        XCTAssertTrue(message.waitForExistence(timeout: 5), app.debugDescription)
        message.tap()
        message.typeText("The feedback form works on iOS.")
        app.swipeUp()
        app.buttons["Submit Feedback"].tap()
        XCTAssertTrue(app.staticTexts["Thank you!"].waitForExistence(timeout: 10), app.debugDescription)
        capture("feedback-success", app: app)
        app.buttons["My Conversations"].tap()
        let conversation = app.staticTexts["The feedback form works on iOS."]
        XCTAssertTrue(conversation.waitForExistence(timeout: 10), app.debugDescription)
        conversation.tap()
        XCTAssertTrue(app.staticTexts["Thanks for the report!"].waitForExistence(timeout: 10))
        capture("conversation", app: app)
        let reply = app.textFields["Write a reply…"]
        reply.tap()
        reply.typeText("Thank you.")
        app.buttons["Send Reply"].tap()
        let cleared = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", "Write a reply…"), object: reply)
        XCTAssertEqual(XCTWaiter.wait(for: [cleared], timeout: 10), .completed)
        XCTAssertTrue(app.staticTexts["Thank you."].waitForExistence(timeout: 10))
    }

    @MainActor
    func testManualWhatsNewAndFirstInstall() {
        let app = launch()
        XCTAssertTrue(app.navigationBars["StorePal iOS Example"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.staticTexts["SDK Test App"].exists)
        app.buttons["What’s New"].tap()
        XCTAssertTrue(app.staticTexts["SDK Test App"].waitForExistence(timeout: 10), app.debugDescription)
        XCTAssertTrue(app.webViews.firstMatch.waitForExistence(timeout: 10))
        capture("whats-new", app: app)
        app.buttons["Close"].tap()
        XCTAssertTrue(app.buttons["Send Feedback"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testUpgradeShowsOnce() {
        let app = launch(["--upgrade"])
        XCTAssertTrue(app.staticTexts["SDK Test App"].waitForExistence(timeout: 10), app.debugDescription)
        app.buttons["Close"].tap()
        app.terminate()
        let relaunched = launch(reset: false)
        XCTAssertTrue(relaunched.buttons["Send Feedback"].waitForExistence(timeout: 10))
        XCTAssertFalse(relaunched.staticTexts["SDK Test App"].exists)
    }

    @MainActor
    func testReleaseFailureCanRetryAndClose() {
        let app = launch(["--offline"])
        app.buttons["What’s New"].tap()
        XCTAssertTrue(app.buttons["Try Again"].waitForExistence(timeout: 10))
        app.buttons["Try Again"].tap()
        XCTAssertTrue(app.buttons["Try Again"].waitForExistence(timeout: 10))
        capture("whats-new-error", app: app)
        app.buttons["Close"].tap()
        XCTAssertTrue(app.buttons["Send Feedback"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testFeedbackLayout() {
        let app = launch()
        app.buttons["Send Feedback"].tap()
        XCTAssertTrue(app.textFields["Name"].waitForExistence(timeout: 10))
        capture("feedback-form", app: app)
    }

    @MainActor
    private func capture(_ name: String, app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
