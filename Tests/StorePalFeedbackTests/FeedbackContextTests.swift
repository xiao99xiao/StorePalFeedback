import Foundation
import Testing
@testable import StorePalFeedback

@Test func customContextPreservesDeviceFieldsAndServerBudget() {
    let device = ["app_version": "1.0", "os_version": "iOS 18", "hardware": "iPhone"]
    var fields = Dictionary(uniqueKeysWithValues: (0..<30).map { (String(format: "field_%02d", $0), "value") })
    fields["app_version"] = "override"
    fields["camera_firmware"] = String(repeating: "x", count: 600)
    fields["empty"] = "  "
    let metadata = StorePalFeedbackContext(metadata: fields).mergedMetadata(device: device)
    #expect(metadata["app_version"] == "1.0")
    #expect(metadata.count == 20)
    #expect(metadata["camera_firmware"]?.count == 500)
    #expect(metadata["empty"] == nil)
}

@MainActor @Test func preparedLogIsRemovableAndReturnsForANewDraft() {
    let context = StorePalFeedbackContext(metadata: ["camera_model": "GR III"], attachments: [
        .init(fileName: "diagnostics.log", data: Data("sanitized log".utf8))
    ], notice: "Diagnostics can be removed.")
    let model = FeedbackModel(context: context)
    #expect(model.attachments.count == 1)
    #expect(model.contextNotice == context.notice)
    model.attachments.removeAll()
    #expect(model.attachments.isEmpty)
    model.resetDraft()
    #expect(model.attachments.first?.fileName == "diagnostics.log")
    model.addPreparedAttachments([.init(fileName: "unsafe\r\nheader.log", data: Data([1]))])
    #expect(model.attachments.count == 1)
    #expect(model.errorMessage != nil)
}
