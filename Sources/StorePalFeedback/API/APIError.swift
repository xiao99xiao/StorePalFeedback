import Foundation

/// Error returned by the StorePal API.
public struct StorePalAPIError: Error, Sendable, Decodable {
    public let code: String
    public let message: String
}

/// Errors that can occur when using the SDK.
public enum StorePalError: Error, Sendable {
    case notConfigured
    case networkError(URLError)
    case apiError(StorePalAPIError)
    case decodingError(any Error)
    case cooldown
    case replyLimit
}
