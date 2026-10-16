#if os(iOS)
import Foundation
import Testing
@testable import StorePalFeedback

@MainActor
@Test func attachmentCountAndSizeLimits() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let small = directory.appendingPathComponent("report.log")
    try Data("Diagnostic log".utf8).write(to: small)
    let model = FeedbackModel()
    model.addAttachments([small, small, small, small])
    #expect(model.attachments.count == 3)
    #expect(model.errorMessage != nil)
    #expect(model.attachments.first?.mimeType == "text/plain")

    let large = directory.appendingPathComponent("large.log")
    try Data(count: 5 * 1024 * 1024 + 1).write(to: large)
    let other = FeedbackModel()
    other.addAttachments([large])
    #expect(other.attachments.isEmpty)
    #expect(other.errorMessage != nil)
}

@MainActor
@Test func totalAttachmentLimitAndUnsupportedType() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let file = directory.appendingPathComponent("report.log")
    try Data(count: 4 * 1024 * 1024).write(to: file)
    let model = FeedbackModel()
    model.addAttachments([file, file, file])
    #expect(model.attachments.count == 2)
    #expect(model.errorMessage != nil)
    let unsupported = directory.appendingPathComponent("archive.zip")
    try Data("invalid".utf8).write(to: unsupported)
    let other = FeedbackModel()
    other.addAttachments([unsupported])
    #expect(other.attachments.isEmpty)
    #expect(other.errorMessage != nil)
}
#endif
