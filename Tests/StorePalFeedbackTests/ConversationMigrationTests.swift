import Foundation
import Testing
@testable import StorePalFeedback

private let firstToken = "00000000-0000-4000-8000-000000000001"
private let secondToken = "00000000-0000-4000-8000-000000000002"
private let foreignToken = "00000000-0000-4000-8000-000000000099"

private final class InboxProtocol: URLProtocol {
    static let transcript = InboxTranscript()
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        let (status, body) = Self.transcript.respond(request)
        client?.urlProtocol(self, didReceive: HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: body)
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}

/// The only shared test state is protected by this lock, including URLProtocol callbacks.
private final class InboxTranscript: @unchecked Sendable {
    enum Scenario { case ordinary, retryMigration, cutoff, slowMigration }
    private let lock = NSLock()
    private var scenario = Scenario.ordinary
    private var requests: [(String, [String])] = []
    private var legacyPages: [Int] = []
    func reset(_ scenario: Scenario) { lock.withLock { self.scenario = scenario; requests = []; legacyPages = [] } }
    var pages: [Int] { lock.withLock { legacyPages } }
    var recorded: [(String, [String])] { lock.withLock { requests } }
    func respond(_ request: URLRequest) -> (Int, Data) {
        let snapshot = lock.withLock { () -> (Scenario, Int, Int) in
            let page = Int(URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?.queryItems?.first { $0.name == "page" }?.value ?? "1") ?? 1
            let legacy = request.url!.path.hasSuffix("/conversations")
            if legacy { legacyPages.append(page) }
            return (scenario, page, legacyPages.filter { $0 == page }.count)
        }
        let path = request.url!.path
        let tokens: [String]
        if path.hasSuffix("/lookup") {
            var data = request.httpBody ?? Data()
            if data.isEmpty, let stream = request.httpBodyStream {
                stream.open(); defer { stream.close() }
                var bytes = [UInt8](repeating: 0, count: 4096)
                while stream.hasBytesAvailable {
                    let size = stream.read(&bytes, maxLength: bytes.count)
                    if size <= 0 { break }; data.append(contentsOf: bytes.prefix(size))
                }
            }
            tokens = (try? JSONSerialization.jsonObject(with: data) as? [String: [String]])?["tokens"] ?? []
            #expect(request.httpMethod == "POST")
            #expect(request.url?.query == nil)
            #expect(!tokens.isEmpty && tokens.count <= 100)
        } else { tokens = [] }
        lock.withLock { requests.append((path, tokens)) }
        if path.hasSuffix("/conversations") {
            if snapshot.0 == .slowMigration { Thread.sleep(forTimeInterval: 0.15) }
            if snapshot.0 == .cutoff { return (403, Data(#"{"data":null,"error":{"code":"USER_TOKEN_REQUIRED","message":"Migration ended"}}"#.utf8)) }
            if snapshot.0 == .retryMigration && snapshot.1 == 2 && snapshot.2 == 1 {
                return (503, Data(#"{"data":null,"error":{"code":"UNAVAILABLE","message":"Retry"}}"#.utf8))
            }
            return page([snapshot.1 == 1 ? firstToken : secondToken], total: 2, page: snapshot.1, size: 1)
        }
        #expect(path.hasSuffix("/conversations/lookup"), "New inboxes must never open threads to build a list")
        // A buggy server cannot inject an unrequested capability into the local inbox.
        return page(tokens + [foreignToken], total: tokens.count + 1, page: 1, size: 100)
    }
    private func page(_ tokens: [String], total: Int, page: Int, size: Int) -> (Int, Data) {
        let items = tokens.map { token -> [String: Any] in
            ["id": token, "conversation_token": token, "category": "bug", "message": "Saved feedback",
             "reply_count": 1, "last_reply_at": "2026-10-25T01:00:00Z", "has_unread_reply": true,
             "created_at": "2026-10-24T01:00:00Z"]
        }
        return (200, try! JSONSerialization.data(withJSONObject: ["data": ["conversations": items, "total": total, "page": page, "per_page": size], "error": NSNull()]))
    }
}

@Suite(.serialized)
@MainActor
struct ConversationMigrationTests {
    private func client() -> APIClient {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [InboxProtocol.self]
        return APIClient(configuration: StorePalConfiguration(apiKey: "sp_live_test", baseURL: URL(string: "https://inbox.test")!), session: URLSession(configuration: configuration))
    }
    private func defaults() -> (UserDefaults, String) {
        let name = "storepal-migration-test-" + UUID().uuidString
        return (UserDefaults(suiteName: name)!, name)
    }

    @Test func newInstallUsesSavedTokensWithoutEmailOrSeenRequests() async throws {
        InboxProtocol.transcript.reset(.ordinary)
        let (defaults, name) = defaults(); defer { defaults.removePersistentDomain(forName: name) }
        let store = ConversationStore(apiKey: "sp_live_test", defaults: defaults)
        store.savedEmail = "entered-after-upgrade@example.test"
        store.saveToken(firstToken)
        let result = try await store.loadInbox(client: client())
        #expect(result.total == 1)
        #expect(result.conversations.first?.hasUnreadReply == true)
        #expect(InboxProtocol.transcript.pages.isEmpty)
        #expect(InboxProtocol.transcript.recorded.allSatisfy { $0.0.hasSuffix("/lookup") })
    }

    @Test func existingIdentityImportsOnceAndKeepsOldDeviceTokens() async throws {
        InboxProtocol.transcript.reset(.ordinary)
        let (defaults, name) = defaults(); defer { defaults.removePersistentDomain(forName: name) }
        defaults.set("old@example.test", forKey: "storepal_user_email")
        defaults.set([firstToken.uppercased(), firstToken], forKey: "storepal_conversation_tokens")
        let store = ConversationStore(apiKey: "sp_live_test", defaults: defaults)
        #expect(try await store.loadInbox(client: client()).total == 2)
        #expect(Set(store.allTokens()) == Set([firstToken, secondToken]))
        #expect(InboxProtocol.transcript.pages == [1, 2])
        let reopened = ConversationStore(apiKey: "sp_live_test", defaults: defaults)
        #expect(try await reopened.loadInbox(client: client()).total == 2)
        #expect(InboxProtocol.transcript.pages == [1, 2])
    }

    @Test func migrationResumesAfterNetworkFailureAndRestart() async throws {
        InboxProtocol.transcript.reset(.retryMigration)
        let (defaults, name) = defaults(); defer { defaults.removePersistentDomain(forName: name) }
        defaults.set("old@example.test", forKey: "storepal_user_email")
        let store = ConversationStore(apiKey: "sp_live_test", defaults: defaults)
        await #expect(throws: (any Error).self) { try await store.loadInbox(client: client()) }
        #expect(store.allTokens() == [firstToken])
        let reopened = ConversationStore(apiKey: "sp_live_test", defaults: defaults)
        #expect(try await reopened.loadInbox(client: client()).total == 2)
        #expect(InboxProtocol.transcript.pages == [1, 2, 2])
    }

    @Test func cutoffKeepsHeldTokensAndNeverFallsBackToEmail() async throws {
        InboxProtocol.transcript.reset(.cutoff)
        let (defaults, name) = defaults(); defer { defaults.removePersistentDomain(forName: name) }
        defaults.set("old@example.test", forKey: "storepal_user_email")
        defaults.set([firstToken], forKey: "storepal_conversation_tokens")
        let store = ConversationStore(apiKey: "sp_live_test", defaults: defaults)
        #expect(try await store.loadInbox(client: client()).total == 1)
        #expect(try await store.loadInbox(client: client()).total == 1)
        #expect(InboxProtocol.transcript.pages == [1])
    }

    @Test func batchingPaginationAndUnreadDoNotMarkThreadsSeen() async throws {
        InboxProtocol.transcript.reset(.ordinary)
        let tokens = (0..<105).map { _ in UUID().uuidString.lowercased() }
        let client = client()
        #expect(try await client.listConversations(tokens: tokens).total == 105)
        #expect(try await client.listConversations(tokens: tokens, page: 2).conversations.count == 20)
        #expect(InboxProtocol.transcript.recorded.count == 2)
        #expect(try await client.getUnreadCount(tokens: tokens) == 105)
        #expect(InboxProtocol.transcript.recorded.allSatisfy { $0.0.hasSuffix("/lookup") })
    }

    @Test func signOutCannotRestoreInFlightMigrationCredentials() async throws {
        InboxProtocol.transcript.reset(.slowMigration)
        let (defaults, name) = defaults(); defer { defaults.removePersistentDomain(forName: name) }
        defaults.set("old@example.test", forKey: "storepal_user_email")
        let store = ConversationStore(apiKey: "sp_live_test", defaults: defaults)
        let task = Task { try await store.loadInbox(client: client()) }
        while InboxProtocol.transcript.recorded.isEmpty { await Task.yield() }
        store.clearUserData()
        await #expect(throws: CancellationError.self) { try await task.value }
        #expect(store.allTokens().isEmpty)
        #expect(store.savedEmail == nil)
    }
}
