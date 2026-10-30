#if os(iOS)
import SwiftUI
import UniformTypeIdentifiers

private enum FeedbackTab: Hashable { case compose, conversations }

/// The native iOS feedback form and conversation inbox. Configure StorePal before presenting it.
public struct StorePalFeedbackView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var model: FeedbackModel
    @State private var selectedTab = FeedbackTab.compose

    public init(context: StorePalFeedbackContext = .init()) {
        _model = StateObject(wrappedValue: FeedbackModel(context: context))
    }

    public var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                FeedbackForm(model: model)
                    .navigationTitle(L10n.windowTitle)
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button(L10n.close) { dismiss() }.disabled(model.isSubmitting)
                        }
                    }
            }
            .tag(FeedbackTab.compose)
            .tabItem { Label(L10n.windowTitle, systemImage: "square.and.pencil") }
            NavigationStack {
                ConversationList(model: model)
                    .navigationTitle(L10n.string("conversation.title"))
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button(L10n.close) { dismiss() }
                        }
                    }
            }
            .tag(FeedbackTab.conversations)
            .tabItem { Label(L10n.string("conversation.title"), systemImage: "bubble.left.and.bubble.right") }
        }
        .interactiveDismissDisabled(model.isSubmitting)
        .task(id: selectedTab) {
            if selectedTab == .conversations { await model.loadConversations() }
        }
    }
}

private struct FeedbackForm: View {
    @ObservedObject var model: FeedbackModel
    @State private var importing = false

    var body: some View {
        VStack {
            if model.didSubmit {
                VStack(spacing: 16) {
                    Image(systemName: "checkmark.circle.fill").font(.largeTitle).foregroundStyle(.green)
                        .accessibilityHidden(true)
                    Text(L10n.successTitle).font(.title2.bold())
                    Text(L10n.successSubtitle).foregroundStyle(.secondary).multilineTextAlignment(.center)
                    Button(L10n.sendAnother) { model.resetDraft() }.buttonStyle(.borderedProminent)
                }
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Form {
                    Section {
                        Picker(L10n.category, selection: $model.category) {
                            ForEach(FeedbackCategory.allCases, id: \.rawValue) { category in
                                Text(category.displayName).tag(category)
                            }
                        }
                        TextField(L10n.name, text: $model.name).textContentType(.name)
                        TextField(L10n.email, text: $model.email)
                            .textContentType(.emailAddress).keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never).autocorrectionDisabled()
                    }
                    Section {
                        TextField(L10n.messagePlaceholder, text: $model.message, axis: .vertical)
                            .lineLimit(5...12).accessibilityLabel(L10n.message)
                    } header: {
                        Text(L10n.message)
                    } footer: {
                        Text(L10n.string("form.message.hint"))
                    }
                    Section {
                        ForEach(model.attachments) { attachment in
                            HStack {
                                Label(attachment.fileName, systemImage: "doc").lineLimit(2)
                                Spacer()
                                Button(role: .destructive) {
                                    model.attachments.removeAll { $0.id == attachment.id }
                                } label: { Image(systemName: "minus.circle") }
                                .accessibilityLabel(L10n.attachRemove)
                            }
                        }
                        Button { importing = true } label: { Label(L10n.attach, systemImage: "paperclip") }
                            .disabled(model.attachments.count >= 3)
                    } footer: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(L10n.attachHint)
                            if let notice = model.contextNotice { Text(notice) }
                        }
                    }
                    if let error = model.errorMessage {
                        Section { Text(error).foregroundStyle(.red).accessibilityAddTraits(.updatesFrequently) }
                    }
                    Section {
                        Button {
                            Task { await model.submit() }
                        } label: {
                            HStack {
                                Text(L10n.submit)
                                if model.isSubmitting { Spacer(); ProgressView() }
                            }
                        }
                        .disabled(!model.canSubmit)
                    }
                }
                .disabled(model.isSubmitting)
                .scrollDismissesKeyboard(.interactively)
                .fileImporter(isPresented: $importing,
                              allowedContentTypes: [.png, .jpeg, .gif, .webP, .pdf, .plainText, UTType(filenameExtension: "log") ?? .plainText],
                              allowsMultipleSelection: true) { result in
                    switch result {
                    case .success(let urls): model.addAttachments(urls)
                    case .failure: model.errorMessage = L10n.attachReadFailed
                    }
                }
            }
        }
    }
}

private struct ConversationList: View {
    @ObservedObject var model: FeedbackModel

    var body: some View {
        List {
            if model.isLoading && model.conversations.isEmpty { ProgressView() }
            if let error = model.conversationError {
                Section {
                    Text(error).foregroundStyle(.red)
                    Button(L10n.string("action.retry")) { Task { await model.loadConversations() } }
                }
            } else if model.conversations.isEmpty && !model.isLoading {
                Text(L10n.string("conversation.empty")).foregroundStyle(.secondary)
            }
            ForEach(model.conversations) { conversation in
                NavigationLink {
                    ConversationView(token: conversation.conversationToken, client: model.client) {
                        model.markConversationSeen(conversation.conversationToken)
                    }
                } label: {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(FeedbackCategory(rawValue: conversation.category)?.displayName ?? conversation.category)
                                .font(.headline)
                            if conversation.hasUnreadReply {
                                Image(systemName: "circle.fill").foregroundStyle(.tint).font(.caption2)
                                    .accessibilityLabel(L10n.string("conversation.unread"))
                            }
                        }
                        Text(conversation.message).lineLimit(2).foregroundStyle(.secondary)
                    }
                }
            }
            if model.hasMore {
                Button(L10n.string("action.load_more")) { Task { await model.loadConversations(reset: false) } }
                    .disabled(model.isLoading)
            }
        }
        .refreshable { await model.loadConversations() }
    }
}

private struct ConversationView: View {
    let token: String
    let client: APIClient?
    let onRead: @MainActor () -> Void
    @State private var detail: ConversationDetail?
    @State private var reply = ""
    @State private var errorMessage: String?
    @State private var isSending = false
    @State private var loading = false

    var body: some View {
        List {
            if loading { ProgressView() }
            if let detail {
                Section(L10n.message) { Text(detail.feedback.message).textSelection(.enabled) }
                ForEach(detail.replies) { message in
                    Section(L10n.string(message.senderType == "developer" ? "conversation.developer" : "conversation.you")) {
                        Text(message.message).textSelection(.enabled)
                    }
                }
                Section {
                    TextField(L10n.string("conversation.reply_placeholder"), text: $reply, axis: .vertical)
                        .lineLimit(2...8)
                    Button {
                        Task { await send() }
                    } label: {
                        HStack {
                            Text(L10n.string("conversation.send"))
                            if isSending { Spacer(); ProgressView() }
                        }
                    }
                    .disabled(reply.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || reply.utf16.count > 5000 || isSending)
                }
                .disabled(isSending)
            }
            if let errorMessage {
                Section {
                    Text(errorMessage).foregroundStyle(.red)
                    if detail == nil {
                        Button(L10n.string("action.retry")) { Task { await load() } }
                    }
                }
            }
        }
        .navigationTitle(L10n.string("conversation.title"))
        .task { await load() }
        .refreshable { await load() }
        .scrollDismissesKeyboard(.interactively)
    }

    private func load() async {
        guard let client, !loading else { return }
        loading = true
        defer { loading = false }
        do {
            let result = try await client.getConversation(token: token)
            try Task.checkCancellation()
            detail = result
            onRead()
            errorMessage = nil
        } catch is CancellationError {
        } catch { errorMessage = FeedbackModel.message(for: error) }
    }

    private func send() async {
        guard let client, !isSending else { return }
        isSending = true
        errorMessage = nil
        defer { isSending = false }
        do {
            _ = try await client.postReply(token: token, message: reply.trimmingCharacters(in: .whitespacesAndNewlines))
            reply = ""
            await load()
        } catch { errorMessage = FeedbackModel.message(for: error) }
    }
}
#endif
