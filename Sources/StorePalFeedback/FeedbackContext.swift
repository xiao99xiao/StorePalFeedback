import Foundation

/// App-supplied diagnostics for one feedback draft. Nothing is uploaded until
/// the user submits. Prepared attachments appear in the normal removable list.
public struct StorePalFeedbackContext: Sendable {
    public let metadata: [String: String]
    public let attachments: [StorePalFeedbackAttachment]
    public let notice: String?

    public init(metadata: [String: String] = [:], attachments: [StorePalFeedbackAttachment] = [], notice: String? = nil) {
        self.metadata = metadata
        self.attachments = attachments
        self.notice = notice
    }

    /// The server accepts 20 fields, 500 characters each. Keep SDK environment
    /// fields authoritative and give custom fields a deterministic remaining budget.
    func mergedMetadata(device: [String: String]) -> [String: String] {
        var result = device
        for key in metadata.keys.sorted() where result[key] == nil && result.count < 20 {
            let value = metadata[key]!.trimmingCharacters(in: .whitespacesAndNewlines)
            if !value.isEmpty { result[key] = String(value.prefix(500)) }
        }
        return result
    }
}

public struct StorePalFeedbackAttachment: Sendable {
    public let fileName: String
    public let mimeType: String
    public let data: Data

    public init(fileName: String, mimeType: String = "text/plain", data: Data) {
        self.fileName = fileName
        self.mimeType = mimeType
        self.data = data
    }
}
