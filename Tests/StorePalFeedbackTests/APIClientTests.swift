import Foundation
import Testing
@testable import StorePalFeedback

private final class MockProtocol: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let url = request.url!
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer sp_live_test")
        let status: Int
        let json: String
        if url.path.hasPrefix("/missing") {
            status = 404
            json = #"{"data":null,"error":{"code":"NOT_FOUND","message":"Missing"}}"#
        } else if url.path.hasPrefix("/denied") {
            status = 403
            json = #"{"data":null,"error":{"code":"FORBIDDEN","message":"Denied"}}"#
        } else if url.path.hasSuffix("/releases") {
            #expect(request.value(forHTTPHeaderField: "Accept-Language") != nil)
            #expect(URLComponents(url: url, resolvingAgainstBaseURL: false)?.percentEncodedQuery?.contains("+") == false)
            let items = URLComponents(url: url, resolvingAgainstBaseURL: false)!.queryItems!
            #expect(items == [URLQueryItem(name: "version", value: "1.2+ios&test=1")])
            status = 200
            json = #"{"data":{"id":"release","version":"1.2+ios&test=1","content":"Translated notes","published_at":"2026-10-16","app_name":"Demo","release_note_url":"https://example.test/demo/releases/1.2"},"error":null}"#
        } else if url.path.hasSuffix("/conversations") {
            #expect(URLComponents(url: url, resolvingAgainstBaseURL: false)?.percentEncodedQuery?.contains("+") == false)
            let items = URLComponents(url: url, resolvingAgainstBaseURL: false)!.queryItems!
            #expect(items.first?.value == "dev+ios&name@example.com")
            status = 200
            json = #"{"data":{"conversations":[],"total":0,"page":1,"per_page":20},"error":null}"#
        } else if url.path.hasSuffix("/attachments") {
            #expect(request.httpMethod == "POST")
            #expect(request.value(forHTTPHeaderField: "Content-Type")?.hasPrefix("multipart/form-data; boundary=StorePalBoundary-") == true)
            status = 201
            json = #"{"data":{"attachment_id":"upload-test","file_name":"crash.log","mime_type":"text/plain","size_bytes":10},"error":null}"#
        } else {
            #expect(request.httpMethod == "POST")
            status = 201
            json = #"{"data":{"id":"feedback","conversation_token":"token","category":"bug","created_at":"2026-10-16"},"error":null}"#
        }
        let response = HTTPURLResponse(url: url, statusCode: status, httpVersion: nil, headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(json.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

private func client(path: String = "") -> APIClient {
    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [MockProtocol.self]
    return APIClient(configuration: StorePalConfiguration(apiKey: "sp_live_test", baseURL: URL(string: "https://sdk.test\(path)/")!),
                     session: URLSession(configuration: configuration))
}

@Test func exactVersionAndLanguage() async throws {
    let note = try await client().getReleaseNote(version: "1.2+ios&test=1")
    #expect(note?.version == "1.2+ios&test=1")
    #expect(note?.releaseNoteUrl == "https://example.test/demo/releases/1.2")
}

@Test func missingReleaseIsNotAnError() async throws {
    #expect(try await client(path: "/missing").getReleaseNote(version: "1.0") == nil)
}

@Test func apiFailureIsPreserved() async {
    do {
        _ = try await client(path: "/denied").getReleaseNote(version: "1.0")
        Issue.record("Expected an API error")
    } catch StorePalError.apiError(let error) {
        #expect(error.code == "FORBIDDEN")
    } catch { Issue.record("Unexpected error: \(error)") }
}

@Test func emailQueryPreservesReservedCharacters() async throws {
    let page = try await client().importLegacyConversations(email: "dev+ios&name@example.com", page: 1)
    #expect(page.total == 0)
}

@Test func feedbackReturnsConversationToken() async throws {
    let feedback = try await client().submitFeedback(category: "bug", message: "An example bug report", name: "Test", email: "test@example.com")
    #expect(feedback.conversationToken == "token")
}

@Test func attachmentUploadDecodesBindingID() async throws {
    let file = try await client().uploadAttachment(data: Data("Test log\n".utf8), fileName: "crash.log", mimeType: "text/plain")
    #expect(file.attachmentId == "upload-test")
    #expect(file.mimeType == "text/plain")
}

@Test func deviceMetadataMatchesPlatform() {
    #if os(iOS)
    #expect(DeviceMetadata.collect()["os_version"]?.hasPrefix("iOS ") == true)
    #else
    #expect(DeviceMetadata.collect()["os_version"]?.hasPrefix("macOS ") == true)
    #endif
    #expect(DeviceMetadata.collect()["hardware"]?.isEmpty == false)
}
