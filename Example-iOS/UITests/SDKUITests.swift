import XCTest

final class SDKUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }
    @MainActor
    private func launch(_ extra: [String] = [], reset: Bool = true, language: String = "en", locale: String = "en_US") async throws -> XCUIApplication {
        if reset { _ = try await fixture("reset", method: "POST") }
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "-AppleLanguages", "(\(language))", "-AppleLocale", locale] + (reset ? ["--reset-sdk"] : []) + extra
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
    func testEnglishLocalization() async throws {
        try await verifyLocalization(language: "en", locale: "en_US", feedback: "Send Feedback", name: "Name", email: "Email",
                                     attach: "Attach", submit: "Submit Feedback", conversations: "My Conversations",
                                     empty: "No conversations yet. Send feedback to start a conversation.",
                                     whatsNew: "What’s New", allReleases: "View all release notes", close: "Close", retry: "Try Again")
    }

    @MainActor
    func testSimplifiedChineseLocalization() async throws {
        try await verifyLocalization(language: "zh-Hans", locale: "zh_CN", feedback: "发送反馈", name: "姓名", email: "邮箱",
                                     attach: "添加附件", submit: "提交反馈", conversations: "我的对话",
                                     empty: "暂无对话，提交反馈后即可在这里查看。",
                                     whatsNew: "更新内容", allReleases: "查看全部更新说明", close: "关闭", retry: "重试")
    }

    @MainActor
    func testTraditionalChineseLocalization() async throws {
        try await verifyLocalization(language: "zh-Hant", locale: "zh_TW", feedback: "傳送回饋", name: "姓名", email: "電子郵件",
                                     attach: "加入附件", submit: "提交回饋", conversations: "我的對話",
                                     empty: "尚無對話，提交回饋後即可在此查看。",
                                     whatsNew: "更新內容", allReleases: "查看所有更新說明", close: "關閉", retry: "重試")
    }

    @MainActor
    func testSimplifiedChineseServerErrorIsLocalized() async throws {
        try await verifyLocalizedServerError(language: "zh-Hans", locale: "zh_CN", feedback: "发送反馈", conversations: "我的对话",
                                             message: "请求过于频繁，请稍等一分钟后重试。")
    }

    @MainActor
    func testTraditionalChineseServerErrorIsLocalized() async throws {
        try await verifyLocalizedServerError(language: "zh-Hant", locale: "zh_TW", feedback: "傳送回饋", conversations: "我的對話",
                                             message: "請求過於頻繁，請稍等一分鐘後再試一次。")
    }

    @MainActor
    private func verifyLocalizedServerError(language: String, locale: String, feedback: String, conversations: String,
                                            message: String) async throws {
        let app = try await launch(["--legacy-token", "--english-errors"], language: language, locale: locale)
        XCTAssertTrue(app.buttons[feedback].waitForExistence(timeout: 10), app.debugDescription)
        app.buttons[feedback].tap()
        app.buttons[conversations].tap()
        XCTAssertTrue(app.staticTexts[message].waitForExistence(timeout: 10), app.debugDescription)
        XCTAssertFalse(app.staticTexts["Server English should never appear in localized UI"].exists)
        capture("localization-\(language)-server-error", app: app)
        app.terminate()
    }

    @MainActor
    private func verifyLocalization(language: String, locale: String, feedback: String, name: String, email: String,
                                    attach: String, submit: String, conversations: String, empty: String,
                                    whatsNew: String, allReleases: String, close: String, retry: String) async throws {
        let app = try await launch(language: language, locale: locale)
        let entry = app.buttons[feedback]
        XCTAssertTrue(entry.waitForExistence(timeout: 10), app.debugDescription)
        capture("localization-\(language)-entry", app: app)
        entry.tap()
        XCTAssertTrue(app.navigationBars[feedback].waitForExistence(timeout: 10), app.debugDescription)
        XCTAssertTrue(app.textFields[name].exists, app.debugDescription)
        XCTAssertTrue(app.textFields[email].exists, app.debugDescription)
        XCTAssertTrue(app.buttons[attach].exists, app.debugDescription)
        XCTAssertTrue(app.buttons[submit].exists, app.debugDescription)
        capture("localization-\(language)-feedback", app: app)
        app.buttons[conversations].tap()
        XCTAssertTrue(app.staticTexts[empty].waitForExistence(timeout: 10), app.debugDescription)
        capture("localization-\(language)-inbox", app: app)
        app.buttons[close].tap()
        app.buttons["example.showWhatsNew"].tap()
        XCTAssertTrue(app.staticTexts["SDK Test App"].waitForExistence(timeout: 10), app.debugDescription)
        XCTAssertTrue(app.navigationBars[whatsNew].exists, app.debugDescription)
        XCTAssertTrue(app.webViews.staticTexts["Built for iPhone and iPad"].waitForExistence(timeout: 10), app.debugDescription)
        XCTAssertTrue(app.buttons[close].exists, app.debugDescription)
        XCTAssertTrue(app.links[allReleases].exists, app.debugDescription)
        let requestedLanguage = try await releaseLanguage()
        XCTAssertTrue(requestedLanguage.hasPrefix(language), "Expected \(language) release content, received Accept-Language: \(requestedLanguage)")
        capture("localization-\(language)-whats-new", app: app)
        app.buttons[close].tap()
        app.terminate()

        let offline = try await launch(["--offline"], language: language, locale: locale)
        offline.buttons["example.showWhatsNew"].tap()
        XCTAssertTrue(offline.buttons[retry].waitForExistence(timeout: 10), offline.debugDescription)
        XCTAssertTrue(offline.navigationBars[whatsNew].exists, offline.debugDescription)
        capture("localization-\(language)-whats-new-error", app: offline)
        offline.buttons[close].tap()
        XCTAssertTrue(offline.buttons[feedback].waitForExistence(timeout: 5))
        offline.terminate()
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
    private func releaseLanguage() async throws -> String {
        let (data, response) = try await URLSession.shared.data(from: URL(string: "http://127.0.0.1:8766/__qa/release-language")!)
        XCTAssertEqual((response as? HTTPURLResponse)?.statusCode, 200)
        return try JSONDecoder().decode([String: String].self, from: data)["acceptLanguage"] ?? ""
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
