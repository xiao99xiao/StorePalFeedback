#if os(iOS)
import Combine
import Foundation
import UniformTypeIdentifiers

struct PendingAttachment: Identifiable {
    let id = UUID()
    let fileName: String
    let mimeType: String
    let data: Data
    var uploadedID: String?
}

/// A sheet owns its draft and request state; networking and storage are shared with macOS.
@MainActor
final class FeedbackModel: ObservableObject {
    @Published var name: String
    @Published var email: String
    @Published var category: FeedbackCategory
    @Published var message = ""
    @Published var attachments: [PendingAttachment] = []
    @Published var errorMessage: String?
    @Published private(set) var conversationError: String?
    @Published private(set) var isSubmitting = false
    @Published private(set) var didSubmit = false
    @Published private(set) var conversations: [ConversationSummary] = []
    @Published private(set) var isLoading = false
    @Published private(set) var hasMore = false
    private var page = 0

    let client: APIClient?
    private let store: ConversationStore?

    init() {
        let sdk = StorePalFeedback.shared
        client = sdk.apiClient
        store = sdk.store
        name = sdk.store?.resolveName(configName: sdk.config?.userName) ?? ""
        email = sdk.store?.resolveEmail(configEmail: sdk.config?.userEmail) ?? ""
        category = StorePalFeedback.defaultCategory.flatMap(FeedbackCategory.init(rawValue:)) ?? .bug
    }

    var canSubmit: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && name.count <= 200 && email.contains("@")
            && message.trimmingCharacters(in: .whitespacesAndNewlines).count >= 10
            && message.utf16.count <= 5000 && !isSubmitting
    }

    func addAttachments(_ urls: [URL]) {
        errorMessage = nil
        for url in urls {
            guard attachments.count < 3 else {
                errorMessage = String(format: L10n.attachMaxFiles, 3)
                return
            }
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            do {
                let values = try url.resourceValues(forKeys: [.fileSizeKey, .contentTypeKey])
                guard let size = values.fileSize, size > 0, size <= 5 * 1024 * 1024 else {
                    errorMessage = String(format: L10n.attachTooLarge, url.lastPathComponent)
                    return
                }
                guard attachments.reduce(0, { $0 + $1.data.count }) + size <= 10 * 1024 * 1024 else {
                    errorMessage = L10n.attachTotalTooLarge
                    return
                }
                let mime = url.pathExtension.lowercased() == "log"
                    ? "text/plain" : values.contentType?.preferredMIMEType ?? "application/octet-stream"
                guard ["image/png", "image/jpeg", "image/gif", "image/webp", "application/pdf", "text/plain"].contains(mime) else {
                    errorMessage = L10n.string("form.attach.unsupported")
                    return
                }
                let data = try Data(contentsOf: url)
                guard !data.isEmpty, data.count <= 5 * 1024 * 1024,
                      attachments.reduce(0, { $0 + $1.data.count }) + data.count <= 10 * 1024 * 1024 else {
                    errorMessage = L10n.attachTotalTooLarge
                    return
                }
                attachments.append(PendingAttachment(fileName: url.lastPathComponent, mimeType: mime, data: data))
            } catch {
                errorMessage = L10n.attachReadFailed
            }
        }
    }

    func submit() async {
        guard canSubmit else { return }
        guard let client else { errorMessage = L10n.string("sdk.not_configured"); return }
        let generation = store?.generation
        isSubmitting = true
        errorMessage = nil
        defer { isSubmitting = false }
        do {
            // Retain successful uploads if a later upload or submission needs a retry.
            for index in attachments.indices where attachments[index].uploadedID == nil {
                let file = attachments[index]
                let result = try await client.uploadAttachment(data: file.data, fileName: file.fileName, mimeType: file.mimeType)
                attachments[index].uploadedID = result.attachmentId
            }
            let result = try await client.submitFeedback(
                category: category.rawValue,
                message: message.trimmingCharacters(in: .whitespacesAndNewlines),
                name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                email: email.trimmingCharacters(in: .whitespacesAndNewlines),
                metadata: DeviceMetadata.collect(),
                attachmentIds: attachments.compactMap(\.uploadedID)
            )
            guard generation == store?.generation, StorePalFeedback.shared.apiClient === client else { throw CancellationError() }
            store?.savedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
            store?.savedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
            store?.saveToken(result.conversationToken)
            didSubmit = true
        } catch {
            errorMessage = Self.message(for: error)
        }
    }

    func resetDraft() {
        message = ""
        attachments = []
        errorMessage = nil
        didSubmit = false
    }

    func loadConversations(reset: Bool = true) async {
        guard !isLoading else { return }
        guard let client, let store else { conversationError = L10n.string("sdk.not_configured"); return }
        isLoading = true
        conversationError = nil
        defer { isLoading = false }
        do {
            let nextPage = reset ? 1 : page + 1
            let result = try await store.loadInbox(client: client, page: nextPage)
            try Task.checkCancellation()
            conversations = reset ? result.conversations : conversations + result.conversations
            page = result.page
            hasMore = conversations.count < result.total
        } catch is CancellationError {
        } catch {
            conversationError = Self.message(for: error)
        }
    }

    func markConversationSeen(_ token: String) {
        conversations = conversations.map { item in
            guard item.conversationToken == token else { return item }
            return ConversationSummary(id: item.id, conversationToken: item.conversationToken, category: item.category,
                message: item.message, replyCount: item.replyCount, lastReplyAt: item.lastReplyAt,
                hasUnreadReply: false, createdAt: item.createdAt)
        }
    }

    static func message(for error: any Error) -> String {
        switch error {
        case StorePalError.apiError(let detail): detail.message
        case StorePalError.cooldown: L10n.string("conversation.cooldown")
        case StorePalError.replyLimit: L10n.string("conversation.reply_limit")
        case StorePalError.notConfigured: L10n.string("sdk.not_configured")
        default: L10n.genericError
        }
    }
}
#endif
