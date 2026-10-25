import Foundation

/// SDK configuration provided by the developer at setup time.
public struct StorePalConfiguration: Sendable {
    public let apiKey: String
    public let userEmail: String?
    public let userName: String?
    public let baseURL: URL

    public init(
        apiKey: String,
        userEmail: String? = nil,
        userName: String? = nil,
        baseURL: URL = URL(string: "https://storepal.app")!
    ) {
        precondition(
            apiKey.hasPrefix("sp_live_") && apiKey.count > 8 && !apiKey.contains(where: \.isWhitespace),
            "Use an app-scoped sp_live_ key. Never embed an account-scoped sp_user_ token in an app."
        )
        self.apiKey = apiKey
        self.userEmail = userEmail
        self.userName = userName
        self.baseURL = baseURL
    }
}
