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
            apiKey.hasPrefix("sp_live_") || apiKey.hasPrefix("sp_user_"),
            "StorePal API key must start with sp_live_ or sp_user_"
        )
        self.apiKey = apiKey
        self.userEmail = userEmail
        self.userName = userName
        self.baseURL = baseURL
    }
}
