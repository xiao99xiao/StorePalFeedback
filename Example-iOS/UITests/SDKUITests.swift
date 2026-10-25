import XCTest

final class SDKUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }
    @MainActor
    private func launch(_ extra: [String] = [], reset: Bool = true) async throws -> XCUIApplication {
        if reset { _ = try await fixture("reset", method: "POST") }
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"] + (reset ? ["--reset-sdk"] : []) + extra
        app.launch()
        return app
    }

    @MainActor
    func testFeedbackAndConversation() async throws {
        let app = try await launch()
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
        let inbox = try await fixture("state")
        XCTAssertEqual(inbox["legacyCalls"], 0, "A new installation must not discover conversations by email")
        XCTAssertEqual(inbox["threadReads"], 0, "Loading a list must not mark its threads seen")
        XCTAssertEqual(inbox["unreadCount"], 1)
        XCTAssertTrue(app.images["Unread reply"].exists)
        capture("capability-inbox-unread", app: app)
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
        let replied = try await fixture("state")
        XCTAssertEqual(replied["replyCalls"], 1)
        app.navigationBars["My Conversations"].buttons["BackButton"].tap()
        XCTAssertTrue(conversation.waitForExistence(timeout: 10))
        XCTAssertFalse(app.images["Unread reply"].exists, "Opening the thread must immediately clear its local unread indicator")
        capture("capability-inbox-read-after-return", app: app)
    }

    @MainActor
    func testManualWhatsNewAndFirstInstall() async throws {
        let app = try await launch()
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
    func testUpgradeShowsOnce() async throws {
        let app = try await launch(["--upgrade"])
        XCTAssertTrue(app.staticTexts["SDK Test App"].waitForExistence(timeout: 10), app.debugDescription)
        app.buttons["Close"].tap()
        app.terminate()
        let relaunched = try await launch(reset: false)
        XCTAssertTrue(relaunched.buttons["Send Feedback"].waitForExistence(timeout: 10))
        XCTAssertFalse(relaunched.staticTexts["SDK Test App"].exists)
    }

    @MainActor
    func testReleaseFailureCanRetryAndClose() async throws {
        let app = try await launch(["--offline"])
        app.buttons["What’s New"].tap()
        XCTAssertTrue(app.buttons["Try Again"].waitForExistence(timeout: 10))
        app.buttons["Try Again"].tap()
        XCTAssertTrue(app.buttons["Try Again"].waitForExistence(timeout: 10))
        capture("whats-new-error", app: app)
        app.buttons["Close"].tap()
        XCTAssertTrue(app.buttons["Send Feedback"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testFeedbackLayout() async throws {
        let app = try await launch()
        app.buttons["Send Feedback"].tap()
        XCTAssertTrue(app.textFields["Name"].waitForExistence(timeout: 10))
        capture("feedback-form", app: app)
    }

    @MainActor
    func testConfiguredEmailOnNewInstallationCannotDiscoverHistory() async throws {
        let app = try await launch(["--configured-email"])
        app.buttons["Send Feedback"].tap()
        app.buttons["My Conversations"].tap()
        let empty = app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "No conversations yet.")).firstMatch
        XCTAssertTrue(empty.waitForExistence(timeout: 10), app.debugDescription)
        let state = try await fixture("state")
        XCTAssertEqual(state["legacyCalls"], 0)
        XCTAssertEqual(state["lookupCalls"], 0, "No capabilities means no inbox request")
        capture("fresh-install-private-inbox", app: app)
    }

    @MainActor
    func testLegacyEmailImportsOnceAndSurvivesRestart() async throws {
        let app = try await launch(["--legacy-email"])
        app.buttons["Send Feedback"].tap()
        app.buttons["My Conversations"].tap()
        XCTAssertTrue(app.staticTexts["Historical feedback from previous SDK"].waitForExistence(timeout: 10), app.debugDescription)
        let imported = try await fixture("state")
        XCTAssertEqual(imported["legacyCalls"], 2, "Both legacy pages must be imported")
        XCTAssertEqual(imported["threadReads"], 0)
        XCTAssertEqual(imported["unreadCount"], 1)
        capture("legacy-inbox-imported", app: app)
        app.terminate()
        let relaunched = try await launch(reset: false)
        relaunched.buttons["Send Feedback"].tap()
        relaunched.buttons["My Conversations"].tap()
        XCTAssertTrue(relaunched.staticTexts["Historical feedback from previous SDK"].waitForExistence(timeout: 10), relaunched.debugDescription)
        let restored = try await fixture("state")
        XCTAssertEqual(restored["legacyCalls"], 2, "A completed import must never repeat on restart")
        XCTAssertEqual(restored["threadReads"], 0)
        XCTAssertGreaterThan(restored["lookupCalls"] ?? 0, imported["lookupCalls"] ?? 0)
        capture("legacy-inbox-after-restart", app: relaunched)
    }

    @MainActor
    func testSavedCapabilitySurvivesLegacyCutoffAndRestart() async throws {
        let app = try await launch(["--legacy-token", "--strict-server"])
        app.buttons["Send Feedback"].tap()
        app.buttons["My Conversations"].tap()
        let saved = app.staticTexts["Saved conversation from previous SDK"]
        XCTAssertTrue(saved.waitForExistence(timeout: 10), app.debugDescription)
        let listed = try await fixture("state")
        XCTAssertEqual(listed["legacyCalls"], 1, "A closed compatibility endpoint is checked only once")
        XCTAssertEqual(listed["threadReads"], 0)
        XCTAssertEqual(listed["unreadCount"], 1)
        saved.tap()
        XCTAssertTrue(app.staticTexts["Thanks for the report!"].waitForExistence(timeout: 10))
        capture("saved-capability-after-cutoff", app: app)
        app.terminate()
        let relaunched = try await launch(["--strict-server"], reset: false)
        relaunched.buttons["Send Feedback"].tap()
        relaunched.buttons["My Conversations"].tap()
        XCTAssertTrue(relaunched.staticTexts["Saved conversation from previous SDK"].waitForExistence(timeout: 10), relaunched.debugDescription)
        let restored = try await fixture("state")
        XCTAssertEqual(restored["legacyCalls"], 1)
        XCTAssertEqual(restored["unreadCount"], 0, "Only opening the saved thread may mark it read")
    }

    @MainActor
    private func fixture(_ path: String, method: String = "GET") async throws -> [String: Int] {
        var request = URLRequest(url: URL(string: "http://127.0.0.1:8766/__qa/\(path)")!)
        request.httpMethod = method
        let (data, response) = try await URLSession.shared.data(for: request)
        XCTAssertEqual((response as? HTTPURLResponse)?.statusCode, 200)
        return try JSONDecoder().decode([String: Int].self, from: data)
    }

    @MainActor
    private func capture(_ name: String, app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
        let hierarchy = XCTAttachment(string: app.debugDescription)
        hierarchy.name = name + "-hierarchy"
        hierarchy.lifetime = .keepAlways
        add(hierarchy)
    }
}
