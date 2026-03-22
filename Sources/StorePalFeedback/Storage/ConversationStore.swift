import Foundation

/// Persists conversation tokens in UserDefaults so the user can view past conversations.
@MainActor
final class ConversationStore {
    private let defaults: UserDefaults
    private let key = "storepal_conversation_tokens"

    init(apiKey: String) {
        let suite = "com.storepal.feedback.\(apiKey.prefix(16))"
        self.defaults = UserDefaults(suiteName: suite) ?? .standard
    }

    func saveToken(_ token: String) {
        var tokens = allTokens()
        guard !tokens.contains(token) else { return }
        tokens.insert(token, at: 0)
        defaults.set(tokens, forKey: key)
    }

    func allTokens() -> [String] {
        defaults.stringArray(forKey: key) ?? []
    }

    func removeToken(_ token: String) {
        var tokens = allTokens()
        tokens.removeAll { $0 == token }
        defaults.set(tokens, forKey: key)
    }
}
