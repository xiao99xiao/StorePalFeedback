import Foundation

/// Persists conversation tokens, user name, and email in UserDefaults.
@MainActor
final class ConversationStore {
    private let defaults: UserDefaults
    private let tokensKey = "storepal_conversation_tokens"
    private let emailKey = "storepal_user_email"
    private let nameKey = "storepal_user_name"
    private let migrationKey = "storepal_token_inbox_migration_v1"
    private let migrationEmailKey = "storepal_token_inbox_legacy_email"
    private let migrationPageKey = "storepal_token_inbox_legacy_page"
    private(set) var generation = 0

    init(apiKey: String, defaults: UserDefaults? = nil) {
        let suite = "com.storepal.feedback.\(apiKey.prefix(16))"
        self.defaults = defaults ?? UserDefaults(suiteName: suite) ?? .standard
        if self.defaults.object(forKey: migrationKey) == nil {
            let legacyEmail = self.defaults.string(forKey: emailKey)
            // Only pre-existing saved identity can trigger the one-time import.
            // Configuring a new installation with an email must never discover threads.
            if let legacyEmail, !legacyEmail.isEmpty {
                self.defaults.set(legacyEmail, forKey: migrationEmailKey)
                self.defaults.set(false, forKey: migrationKey)
            } else { self.defaults.set(true, forKey: migrationKey) }
        }
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
        guard let token = UUID(uuidString: token)?.uuidString.lowercased() else { return }
        var tokens = allTokens()
        guard !tokens.contains(token) else { return }
        tokens.insert(token, at: 0)
        defaults.set(tokens, forKey: tokensKey)
    }

    func allTokens() -> [String] {
        var seen = Set<String>()
        return (defaults.stringArray(forKey: tokensKey) ?? []).compactMap { value in
            guard let token = UUID(uuidString: value)?.uuidString.lowercased(), seen.insert(token).inserted else { return nil }
            return token
        }
    }

    func clearTokens() {
        generation += 1
        defaults.removeObject(forKey: tokensKey)
        finishMigration()
    }

    func clearUserData() {
        clearTokens()
        defaults.removeObject(forKey: emailKey)
        defaults.removeObject(forKey: nameKey)
    }

    private func finishMigration() {
        defaults.set(true, forKey: migrationKey)
        defaults.removeObject(forKey: migrationEmailKey)
        defaults.removeObject(forKey: migrationPageKey)
    }

    func loadInbox(client: APIClient, page: Int = 1) async throws -> ConversationsPage {
        let generation = self.generation
        if !defaults.bool(forKey: migrationKey), let email = defaults.string(forKey: migrationEmailKey) {
            var next = max(1, defaults.integer(forKey: migrationPageKey))
            do {
                while true {
                    let result = try await client.importLegacyConversations(email: email, page: next)
                    try Task.checkCancellation()
                    guard self.generation == generation else { throw CancellationError() }
                    guard result.page == next, result.perPage > 0 else {
                        throw StorePalError.apiError(StorePalAPIError(code: "INVALID_RESPONSE", message: "Could not import older conversations."))
                    }
                    result.conversations.forEach { saveToken($0.conversationToken) }
                    if result.conversations.isEmpty || result.page >= (result.total + result.perPage - 1) / result.perPage {
                        finishMigration()
                        break
                    }
                    next += 1
                    defaults.set(next, forKey: migrationPageKey)
                }
            } catch StorePalError.apiError(let error) where error.code == "USER_TOKEN_REQUIRED" {
                // The compatibility window closed. Keep all capabilities already held;
                // never fall back to email discovery or ask for an account token.
                guard self.generation == generation else { throw CancellationError() }
                finishMigration()
            }
        }
        let result = try await client.listConversations(tokens: allTokens(), page: page)
        guard self.generation == generation else { throw CancellationError() }
        return result
    }
}
