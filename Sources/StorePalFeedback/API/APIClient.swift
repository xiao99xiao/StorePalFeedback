import Foundation

/// Thread-safe API client for the StorePal REST API.
actor APIClient {
    private let config: StorePalConfiguration
    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder
    private var inboxCache: (tokens: [String], conversations: [ConversationSummary])?

    init(configuration: StorePalConfiguration, session: URLSession? = nil) {
        self.config = configuration
        self.session = session ?? URLSession(configuration: .default, delegate: RejectRedirects(), delegateQueue: nil)

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        self.decoder = decoder

        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        self.encoder = encoder
    }

    deinit { session.invalidateAndCancel() }

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
        let result: FeedbackCreated = try await post("/api/v1/feedback", body: body)
        inboxCache = nil
        return result
    }

    // MARK: - Attachments

    /// Upload a single file as an attachment. The returned `attachmentId` must be passed
    /// into the next `submitFeedback` / `postReply` call within a few minutes to bind it.
    /// Unbound attachments are garbage-collected after one hour.
    ///
    /// Available on Free and Pro. Max 5 MB per file; max 3 attachments per submission.
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

    /// Only used to migrate an existing installation during the server compatibility phase.
    func importLegacyConversations(email: String, page: Int) async throws -> ConversationsPage {
        return try await get("/api/v1/conversations", query: [
            URLQueryItem(name: "email", value: email),
            URLQueryItem(name: "page", value: String(page)),
            URLQueryItem(name: "per_page", value: "20"),
        ])
    }

    func listConversations(tokens: [String], page: Int = 1) async throws -> ConversationsPage {
        guard page > 0 else { throw StorePalError.apiError(StorePalAPIError(code: "VALIDATION_ERROR", message: "Page must be positive.")) }
        let normalized = Array(Set(tokens.compactMap { UUID(uuidString: $0)?.uuidString.lowercased() })).sorted()
        if page == 1 || inboxCache?.tokens != normalized {
            var conversations: [String: ConversationSummary] = [:]
            for offset in stride(from: 0, to: normalized.count, by: 100) {
                struct Lookup: Encodable { let tokens: [String] }
                let batch = Array(normalized[offset..<min(offset + 100, normalized.count)])
                let result: ConversationsPage = try await post("/api/v1/conversations/lookup", body: Lookup(tokens: batch))
                try Task.checkCancellation()
                for item in result.conversations where batch.contains(item.conversationToken.lowercased()) { conversations[item.id] = item }
            }
            let sorted = conversations.values.sorted { $0.createdAt == $1.createdAt ? $0.id > $1.id : $0.createdAt > $1.createdAt }
            inboxCache = (normalized, sorted)
        }
        let items = inboxCache?.conversations ?? []
        let offset = min(items.count, (page - 1).multipliedReportingOverflow(by: 20).overflow ? items.count : (page - 1) * 20)
        return ConversationsPage(conversations: Array(items.dropFirst(offset).prefix(20)), total: items.count, page: page, perPage: 20)
    }

    func getConversation(token: String) async throws -> ConversationDetail {
        let result: ConversationDetail = try await get("/api/v1/conversations/\(token)")
        inboxCache = nil
        return result
    }

    func getUnreadCount(tokens: [String]) async throws -> Int {
        _ = try await listConversations(tokens: tokens)
        return inboxCache?.conversations.filter(\.hasUnreadReply).count ?? 0
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
        let result: Reply = try await post("/api/v1/conversations/\(token)/reply", body: body)
        inboxCache = nil
        return result
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
        request.setValue("swift/1.3.0", forHTTPHeaderField: "X-StorePal-SDK")
        request.setValue(Locale.preferredLanguages.joined(separator: ","), forHTTPHeaderField: "Accept-Language")

        return try await perform(request)
    }

    private func post<T: Decodable & Sendable, B: Encodable>(_ path: String, body: B) async throws -> T {
        var request = URLRequest(url: makeURL(path))
        request.httpMethod = "POST"
        request.setValue("Bearer \(config.apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("swift/1.3.0", forHTTPHeaderField: "X-StorePal-SDK")
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
        if let httpResponse = response as? HTTPURLResponse, !(200...299).contains(httpResponse.statusCode) {
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

/// A redirect must never forward an app key or private conversation capabilities.
private final class RejectRedirects: NSObject, URLSessionTaskDelegate {
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest, completionHandler: @escaping @Sendable (URLRequest?) -> Void) {
        completionHandler(nil)
    }
}
