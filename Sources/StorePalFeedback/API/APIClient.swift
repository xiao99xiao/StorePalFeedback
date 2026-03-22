import Foundation

/// Thread-safe API client for the StorePal REST API.
actor APIClient {
    private let config: StorePalConfiguration
    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    init(configuration: StorePalConfiguration) {
        self.config = configuration
        self.session = URLSession(configuration: .default)

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        self.decoder = decoder

        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        self.encoder = encoder
    }

    // MARK: - Feedback

    func submitFeedback(
        category: String,
        message: String,
        name: String? = nil,
        email: String? = nil,
        metadata: [String: String]? = nil
    ) async throws -> FeedbackCreated {
        let body = SubmitFeedbackRequest(
            name: name ?? config.userName,
            email: email ?? config.userEmail,
            category: category,
            message: message,
            metadata: metadata
        )
        return try await post("/api/v1/feedback", body: body)
    }

    // MARK: - Conversations

    func listConversations(page: Int = 1) async throws -> ConversationsPage {
        let email = config.userEmail.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? config.userEmail
        return try await get("/api/v1/conversations?email=\(email)&page=\(page)&per_page=20")
    }

    func getConversation(token: String) async throws -> ConversationDetail {
        return try await get("/api/v1/conversations/\(token)")
    }

    func getUnreadCount() async throws -> Int {
        let email = config.userEmail.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? config.userEmail
        let response: UnreadResponse = try await get("/api/v1/conversations/unread?email=\(email)")
        return response.unreadCount
    }

    func postReply(token: String, message: String) async throws -> Reply {
        struct ReplyBody: Encodable { let message: String }
        return try await post("/api/v1/conversations/\(token)/reply", body: ReplyBody(message: message))
    }

    // MARK: - Private

    private func get<T: Decodable & Sendable>(_ path: String) async throws -> T {
        let url = config.baseURL.appendingPathComponent(path)
        var request = URLRequest(url: url)
        request.setValue("Bearer \(config.apiKey)", forHTTPHeaderField: "Authorization")

        return try await perform(request)
    }

    private func post<T: Decodable & Sendable, B: Encodable>(_ path: String, body: B) async throws -> T {
        let url = config.baseURL.appendingPathComponent(path)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(config.apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try encoder.encode(body)

        return try await perform(request)
    }

    private func perform<T: Decodable & Sendable>(_ request: URLRequest) async throws -> T {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch let error as URLError {
            throw StorePalError.networkError(error)
        }

        // Check for specific error codes before decoding
        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode >= 400 {
            if let apiResponse = try? decoder.decode(APIResponse<EmptyData>.self, from: data),
               let apiError = apiResponse.error {
                switch apiError.code {
                case "COOLDOWN": throw StorePalError.cooldown
                case "REPLY_LIMIT": throw StorePalError.replyLimit
                default: throw StorePalError.apiError(apiError)
                }
            }
            throw StorePalError.apiError(StorePalAPIError(code: "HTTP_\(httpResponse.statusCode)", message: "Request failed"))
        }

        do {
            let envelope = try decoder.decode(APIResponse<T>.self, from: data)
            if let error = envelope.error {
                throw StorePalError.apiError(error)
            }
            guard let result = envelope.data else {
                throw StorePalError.apiError(StorePalAPIError(code: "NO_DATA", message: "No data in response"))
            }
            return result
        } catch let error as StorePalError {
            throw error
        } catch {
            throw StorePalError.decodingError(error)
        }
    }
}

private struct EmptyData: Decodable, Sendable {}
