import Foundation

/// Persists conversation tokens, user name, and email in UserDefaults.
@MainActor
final class ConversationStore {
    private let defaults: UserDefaults
    private let tokensKey = "storepal_conversation_tokens"
    private let emailKey = "storepal_user_email"
    private let nameKey = "storepal_user_name"

    init(apiKey: String) {
        let suite = "com.storepal.feedback.\(apiKey.prefix(16))"
        self.defaults = UserDefaults(suiteName: suite) ?? .standard
    }

    // MARK: - User identity

    var savedEmail: String? {
        get { defaults.string(forKey: emailKey) }
        set { defaults.set(newValue, forKey: emailKey) }
    }

    var savedName: String? {
        get { defaults.string(forKey: nameKey) }
        set { defaults.set(newValue, forKey: nameKey) }
    }

    /// The effective email: saved > config-provided
    func resolveEmail(configEmail: String?) -> String? {
        savedEmail ?? configEmail
    }

    func resolveName(configName: String?) -> String? {
        savedName ?? configName
    }

    // MARK: - Tokens

    func saveToken(_ token: String) {
        var tokens = allTokens()
        guard !tokens.contains(token) else { return }
        tokens.insert(token, at: 0)
        defaults.set(tokens, forKey: tokensKey)
    }

    func allTokens() -> [String] {
        defaults.stringArray(forKey: tokensKey) ?? []
    }

    func clearTokens() {
        defaults.removeObject(forKey: tokensKey)
    }
}
