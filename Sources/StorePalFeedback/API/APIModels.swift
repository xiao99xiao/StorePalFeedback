import Foundation

// MARK: - Generic envelope

struct APIResponse<T: Decodable & Sendable>: Decodable, Sendable {
    let data: T?
    let error: StorePalAPIError?
}

// MARK: - Feedback

struct SubmitFeedbackRequest: Encodable, Sendable {
    let name: String
    let email: String
    let category: String
    let message: String
    let metadata: [String: String]?
}

public struct FeedbackCreated: Decodable, Sendable {
    public let id: String
    public let conversationToken: String
    public let category: String
    public let createdAt: String
}

// MARK: - Conversations

public struct ConversationSummary: Decodable, Sendable, Identifiable {
    public let id: String
    public let conversationToken: String
    public let category: String
    public let message: String
    public let replyCount: Int
    public let lastReplyAt: String?
    public let hasUnreadReply: Bool
    public let createdAt: String
}

struct ConversationsPage: Decodable, Sendable {
    let conversations: [ConversationSummary]
    let total: Int
    let page: Int
    let perPage: Int
}

public struct ConversationDetail: Decodable, Sendable {
    public let feedback: FeedbackDetail
    public let replies: [Reply]
}

public struct FeedbackDetail: Decodable, Sendable {
    public let id: String
    public let name: String
    public let email: String
    public let category: String
    public let message: String
    public let metadata: [String: String]?
    public let replyCount: Int
    public let lastReplyAt: String?
    public let createdAt: String
}

public struct Reply: Decodable, Sendable, Identifiable {
    public let id: String
    public let senderType: String
    public let message: String
    public let createdAt: String
}

// MARK: - Unread

struct UnreadResponse: Decodable, Sendable {
    let unreadCount: Int
}

// MARK: - Release Notes

public struct ReleaseNote: Decodable, Sendable {
    public let id: String
    public let version: String
    public let content: String
    public let publishedAt: String
}

// MARK: - Category helpers

public enum FeedbackCategory: String, CaseIterable, Sendable {
    case bug = "bug"
    case feature = "feature"
    case question = "question"
    case other = "other"

    public var displayName: String {
        switch self {
        case .bug: L10n.categoryBug
        case .feature: L10n.categoryFeature
        case .question: L10n.categoryQuestion
        case .other: L10n.categoryOther
        }
    }
}
