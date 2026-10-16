import Foundation

/// Thread-safe API client for the StorePal REST API.
actor APIClient {
    private let config: StorePalConfiguration
    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    init(configuration: StorePalConfiguration, session: URLSession = URLSession(configuration: .default)) {
        self.config = configuration
        self.session = session

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
        metadata: [String: String]? = nil,
        attachmentIds: [String]? = nil
    ) async throws -> FeedbackCreated {
        let body = SubmitFeedbackRequest(
            name: name,
            email: email,
            category: category,
            message: message,
            metadata: metadata,
            attachmentIds: (attachmentIds?.isEmpty ?? true) ? nil : attachmentIds
        )
        return try await post("/api/v1/feedback", body: body)
    }

    // MARK: - Attachments

    /// Upload a single file as an attachment. The returned `attachmentId` must be passed
    /// into the next `submitFeedback` / `postReply` call within a few minutes to bind it.
    /// Unbound attachments are garbage-collected after one hour.
    ///
    /// Pro plan required. Max 5 MB per file; max 3 attachments per submission.
    /// Allowed types: PNG, JPEG, GIF, WebP, PDF, plain text, log files.
    func uploadAttachment(
        data: Data,
        fileName: String,
        mimeType: String
    ) async throws -> AttachmentUploaded {
        let boundary = "StorePalBoundary-\(UUID().uuidString)"
        var body = Data()

        func appendString(_ s: String) {
            if let d = s.data(using: .utf8) { body.append(d) }
        }

        appendString("--\(boundary)\r\n")
        appendString("Content-Disposition: form-data; name=\"file\"; filename=\"\(fileName)\"\r\n")
        appendString("Content-Type: \(mimeType)\r\n\r\n")
        body.append(data)
        appendString("\r\n--\(boundary)--\r\n")

        var request = URLRequest(url: makeURL("/api/v1/feedback/attachments"))
        request.httpMethod = "POST"
        request.setValue("Bearer \(config.apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.httpBody = body

        return try await perform(request)
    }

    // MARK: - Conversations

    func listConversations(email: String, page: Int = 1) async throws -> ConversationsPage {
        return try await get("/api/v1/conversations", query: [
            URLQueryItem(name: "email", value: email),
            URLQueryItem(name: "page", value: String(page)),
            URLQueryItem(name: "per_page", value: "20"),
        ])
    }

    func getConversation(token: String) async throws -> ConversationDetail {
        return try await get("/api/v1/conversations/\(token)")
    }

    func getUnreadCount(email: String) async throws -> Int {
        let response: UnreadResponse = try await get("/api/v1/conversations/unread", query: [URLQueryItem(name: "email", value: email)])
        return response.unreadCount
    }

    func postReply(
        token: String,
        message: String,
        attachmentIds: [String]? = nil
    ) async throws -> Reply {
        struct ReplyBody: Encodable {
            let message: String
            let attachmentIds: [String]?
        }
        let body = ReplyBody(
            message: message,
            attachmentIds: (attachmentIds?.isEmpty ?? true) ? nil : attachmentIds
        )
        return try await post("/api/v1/conversations/\(token)/reply", body: body)
    }

    // MARK: - Release Notes

    func getReleaseNote(version: String) async throws -> ReleaseNote? {
        do {
            return try await get("/api/v1/releases", query: [URLQueryItem(name: "version", value: version)])
        } catch StorePalError.apiError(let e) where e.code == "NOT_FOUND" || e.code == "HTTP_404" {
            return nil
        }
    }

    // MARK: - Private

    private func makeURL(_ path: String, query: [URLQueryItem] = []) -> URL {
        var components = URLComponents(url: config.baseURL, resolvingAgainstBaseURL: false)!
        components.path = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            .split(separator: "/").map(String.init).map { "/" + $0 }.joined() + path
        components.queryItems = query.isEmpty ? nil : query
        // URLSearchParams on the API treats a literal + as a space; preserve email aliases.
        components.percentEncodedQuery = components.percentEncodedQuery?.replacingOccurrences(of: "+", with: "%2B")
        components.fragment = nil
        return components.url!
    }

    private func get<T: Decodable & Sendable>(_ path: String, query: [URLQueryItem] = []) async throws -> T {
        var request = URLRequest(url: makeURL(path, query: query))
        request.setValue("Bearer \(config.apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue(Locale.preferredLanguages.joined(separator: ","), forHTTPHeaderField: "Accept-Language")

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
