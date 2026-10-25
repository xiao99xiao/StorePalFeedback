import Foundation
import Testing
@testable import StorePalFeedback

/// Opt-in release verification against a disposable, notification-disabled QA app.
/// The private fixture file is never copied into the SDK or published artifacts.
@MainActor
@Test(.enabled(if: ProcessInfo.processInfo.environment["STOREPAL_LIVE_QA_STATE"] != nil))
func hostedCapabilityInboxAndUpgradeImport() async throws {
    let path = try #require(ProcessInfo.processInfo.environment["STOREPAL_LIVE_QA_STATE"])
    let state = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: URL(fileURLWithPath: path))) as? [String: String])
    let key = try #require(state["app_key"]), token = try #require(state["conversation_token"])
    let client = APIClient(configuration: StorePalConfiguration(apiKey: key))
    let inbox = try await client.listConversations(tokens: [token])
    #expect(inbox.total == 1)
    #expect(inbox.conversations.first?.hasUnreadReply == true)
    #expect(try await client.getUnreadCount(tokens: [token]) == 1)
    let suite = "storepal-live-qa-" + UUID().uuidString
    let defaults = try #require(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    let email = try #require(state["email"])
    defaults.set(email, forKey: "storepal_user_email")
    let store = ConversationStore(apiKey: key, defaults: defaults)
    #expect(try await store.loadInbox(client: client).total == 1)
    #expect(store.allTokens().count == 1)
}
