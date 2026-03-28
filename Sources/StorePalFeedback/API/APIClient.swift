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
        name: String,
        email: String,
        metadata: [String: String]? = nil
    ) async throws -> FeedbackCreated {
        let body = SubmitFeedbackRequest(
            name: name,
            email: email,
            category: category,
            message: message,
            metadata: metadata
        )
        return try await post("/api/v1/feedback", body: body)
    }

    // MARK: - Conversations

    func listConversations(email: String, page: Int = 1) async throws -> ConversationsPage {
        let encoded = email.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? email
        return try await get("/api/v1/conversations?email=\(encoded)&page=\(page)&per_page=20")
    }

    func getConversation(token: String) async throws -> ConversationDetail {
        return try await get("/api/v1/conversations/\(token)")
    }

    func getUnreadCount(email: String) async throws -> Int {
        let encoded = email.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? email
        let response: UnreadResponse = try await get("/api/v1/conversations/unread?email=\(encoded)")
        return response.unreadCount
    }

    func postReply(token: String, message: String) async throws -> Reply {
        struct ReplyBody: Encodable { let message: String }
        return try await post("/api/v1/conversations/\(token)/reply", body: ReplyBody(message: message))
    }

    // MARK: - Release Notes

    func getReleaseNote(version: String) async throws -> ReleaseNote? {
        let encoded = version.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? version
        do {
            return try await get("/api/v1/releases?version=\(encoded)")
        } catch StorePalError.apiError(let e) where e.code == "NOT_FOUND" || e.code == "HTTP_404" {
            return nil
        }
    }

    // MARK: - Private

    private func makeURL(_ path: String) -> URL {
        // Use string concatenation to preserve query parameters — appendingPathComponent encodes ? as %3F
        URL(string: config.baseURL.absoluteString + path)!
    }

    private func get<T: Decodable & Sendable>(_ path: String) async throws -> T {
        var request = URLRequest(url: makeURL(path))
        request.setValue("Bearer \(config.apiKey)", forHTTPHeaderField: "Authorization")

        return try await perform(request)
    }

    private func post<T: Decodable & Sendable, B: Encodable>(_ path: String, body: B) async throws -> T {
        var request = URLRequest(url: makeURL(path))
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
