import Foundation
import Testing
import os
@testable import StorePalFeedback

private let recordedRequests = OSAllocatedUnfairLock(initialState: [URLRequest]())
private final class DiagnosticProtocol: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool { request.url?.host == "feedback-context.test" }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func stopLoading() {}
    override func startLoading() {
        let recorded = request
        recordedRequests.withLock { $0.append(recorded) }
        let json: String
        if request.url!.path.hasSuffix("/attachments") {
            json = #"{"data":{"attachment_id":"prepared-log","file_name":"diagnostics.log","mime_type":"text/plain","size_bytes":15},"error":null}"#
        } else {
            let body: Data
            if let data = request.httpBody { body = data }
            else {
                let stream = request.httpBodyStream!
                stream.open(); defer { stream.close() }
                var data = Data(), buffer = [UInt8](repeating: 0, count: 2048)
                while stream.hasBytesAvailable {
                    let count = stream.read(&buffer, maxLength: buffer.count)
                    guard count > 0 else { break }
                    data.append(contentsOf: buffer.prefix(count))
                }
                body = data
            }
            let payload = try! JSONSerialization.jsonObject(with: body) as! [String: Any]
            let metadata = payload["metadata"] as! [String: String]
            #expect(metadata["camera_model"] == "GR III")
            #expect(metadata["camera_firmware"] == "2.10")
            #expect(metadata["os_version"] != nil && metadata["hardware"] != nil)
            #expect(payload["attachment_ids"] as? [String] == ["prepared-log"])
            json = #"{"data":{"id":"feedback","conversation_token":"801b22f4-ec6e-4e51-b33f-f3de3418492a","category":"bug","created_at":"2026-10-30"},"error":null}"#
        }
        client?.urlProtocol(self, didReceive: HTTPURLResponse(url: request.url!, statusCode: 201,
            httpVersion: nil, headerFields: ["Content-Type": "application/json"])!, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(json.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }
}

@MainActor @Test func feedbackContextUploadsLogAndBindsItsIDToMetadataSubmission() async {
    let key = "sp_live_context_test_" + UUID().uuidString
    let baseURL = URL(string: "https://feedback-context.test")!
    StorePalFeedback.configure(apiKey: key, baseURL: baseURL)
    defer { StorePalFeedback.clearUserData() }
    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [DiagnosticProtocol.self]
    StorePalFeedback.shared.apiClient = APIClient(configuration: .init(apiKey: key, baseURL: baseURL), session: URLSession(configuration: config))
    recordedRequests.withLock { $0 = [] }
    let model = FeedbackModel(context: .init(metadata: ["camera_model": "GR III", "camera_firmware": "2.10"],
        attachments: [.init(fileName: "diagnostics.log", data: Data("sanitized event".utf8))]))
    model.name = "Test"; model.email = "fixture@example.test"; model.message = "Offline diagnostics fixture"
    #expect(recordedRequests.withLock { $0.isEmpty })
    await model.submit()
    #expect(model.didSubmit && model.errorMessage == nil)
    #expect(recordedRequests.withLock { $0.map { $0.url!.path } } == ["/api/v1/feedback/attachments", "/api/v1/feedback"])
    #expect(model.attachments.first?.uploadedID == "prepared-log")
}
