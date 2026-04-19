import AppKit
import UniformTypeIdentifiers

/// A file the user has selected but not yet uploaded.
private struct PendingAttachment {
    let url: URL
    let data: Data
    let fileName: String
    let mimeType: String
    var sizeBytes: Int { data.count }
}

private let MAX_ATTACHMENT_SIZE = 5 * 1024 * 1024
private let MAX_ATTACHMENTS_PER_PARENT = 3
private let MAX_ATTACHMENTS_TOTAL_SIZE = 10 * 1024 * 1024

/// Form for submitting new feedback.
@MainActor
final class FeedbackFormViewController: NSViewController {
    private let apiClient: APIClient
    private let config: StorePalConfiguration
    private let store: ConversationStore

    // Form views
    private let formStack = NSStackView()
    private let categoryPopup = NSPopUpButton()
    private let nameField = NSTextField()
    private let emailField = NSTextField()
    private let messageScrollView = NSScrollView()
    private let messageTextView = NSTextView()
    private let placeholderLabel = NSTextField(labelWithString: "")
    private let attachmentsStack = NSStackView()
    private let attachButton = NSButton(title: "", target: nil, action: nil)
    private let attachHintLabel = NSTextField(labelWithString: "")
    private let metadataLabel = NSTextField(labelWithString: "")
    private let submitButton = NSButton(title: "", target: nil, action: nil)
    private let statusLabel = NSTextField(labelWithString: "")
    private let spinner = NSProgressIndicator()

    // Attachment state
    private var pendingAttachments: [PendingAttachment] = []

    // Success views
    private let successContainer = NSView()

    init(apiClient: APIClient, config: StorePalConfiguration, store: ConversationStore) {
        self.apiClient = apiClient
        self.config = config
        self.store = store
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override func loadView() {
        let root = NSView()

        setupForm(in: root)
        setupSuccessView(in: root)
        successContainer.isHidden = true

        self.view = root
        loadIdentity()
    }

    // MARK: - Form setup

    private func setupForm(in root: NSView) {
        formStack.orientation = .vertical
        formStack.spacing = 10
        formStack.alignment = .leading
        formStack.edgeInsets = NSEdgeInsets(top: 16, left: 20, bottom: 20, right: 20)
        formStack.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(formStack)

        NSLayoutConstraint.activate([
            formStack.topAnchor.constraint(equalTo: root.topAnchor),
            formStack.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            formStack.trailingAnchor.constraint(equalTo: root.trailingAnchor),
        ])

        // Category
        addLabel(L10n.category, to: formStack)
        for cat in FeedbackCategory.allCases {
            categoryPopup.addItem(withTitle: cat.displayName)
        }
        formStack.addArrangedSubview(categoryPopup)

        // Name
        addLabel(L10n.name, to: formStack)
        nameField.placeholderString = L10n.namePlaceholder
        nameField.font = .systemFont(ofSize: 13)
        formStack.addArrangedSubview(nameField)

        // Email
        addLabel(L10n.email, to: formStack)
        emailField.placeholderString = L10n.emailPlaceholder
        emailField.font = .systemFont(ofSize: 13)
        formStack.addArrangedSubview(emailField)

        // Message
        addLabel(L10n.message, to: formStack)
        messageTextView.isRichText = false
        messageTextView.font = .systemFont(ofSize: 13)
        messageTextView.textContainerInset = NSSize(width: 6, height: 6)
        messageTextView.isAutomaticQuoteSubstitutionEnabled = false
        messageTextView.isAutomaticDashSubstitutionEnabled = false
        messageTextView.delegate = self
        messageScrollView.documentView = messageTextView
        messageScrollView.hasVerticalScroller = true
        messageScrollView.borderType = .bezelBorder
        formStack.addArrangedSubview(messageScrollView)

        // Placeholder
        placeholderLabel.stringValue = L10n.messagePlaceholder
        placeholderLabel.textColor = .placeholderTextColor
        placeholderLabel.font = .systemFont(ofSize: 13)
        placeholderLabel.isBezeled = false
        placeholderLabel.drawsBackground = false
        placeholderLabel.isEditable = false
        placeholderLabel.isSelectable = false
        placeholderLabel.translatesAutoresizingMaskIntoConstraints = false
        messageTextView.addSubview(placeholderLabel)
        NSLayoutConstraint.activate([
            placeholderLabel.topAnchor.constraint(equalTo: messageTextView.topAnchor, constant: 6),
            placeholderLabel.leadingAnchor.constraint(equalTo: messageTextView.leadingAnchor, constant: 10),
        ])

        // Attachments row
        let attachRow = NSStackView()
        attachRow.orientation = .horizontal
        attachRow.spacing = 8
        attachRow.alignment = .centerY

        if let paperclip = NSImage(systemSymbolName: "paperclip", accessibilityDescription: nil) {
            attachButton.image = paperclip
            attachButton.imagePosition = .imageLeading
        }
        attachButton.title = L10n.attach
        attachButton.bezelStyle = .rounded
        attachButton.controlSize = .regular
        attachButton.target = self
        attachButton.action = #selector(attachTapped)
        attachRow.addArrangedSubview(attachButton)

        attachHintLabel.stringValue = L10n.attachHint
        attachHintLabel.font = .systemFont(ofSize: 10)
        attachHintLabel.textColor = .tertiaryLabelColor
        attachRow.addArrangedSubview(attachHintLabel)
        formStack.addArrangedSubview(attachRow)

        // Selected attachments list (hidden when empty)
        attachmentsStack.orientation = .vertical
        attachmentsStack.spacing = 4
        attachmentsStack.alignment = .leading
        formStack.addArrangedSubview(attachmentsStack)

        // System info
        let meta = DeviceMetadata.collect()
        let metaString = [meta["os_version"], meta["app_name"].map { "\($0) v\(meta["app_version"] ?? "?")" }, meta["hardware"]]
            .compactMap { $0 }
            .joined(separator: " \u{00B7} ")
        metadataLabel.stringValue = metaString
        metadataLabel.font = .systemFont(ofSize: 10)
        metadataLabel.textColor = .tertiaryLabelColor
        formStack.addArrangedSubview(metadataLabel)

        // Submit row
        let submitRow = NSStackView()
        submitRow.orientation = .horizontal
        submitRow.spacing = 8

        submitButton.title = L10n.submit
        submitButton.bezelStyle = .rounded
        submitButton.controlSize = .large
        submitButton.keyEquivalent = "\r"
        submitButton.target = self
        submitButton.action = #selector(submitTapped)
        submitRow.addArrangedSubview(submitButton)

        spinner.style = .spinning
        spinner.controlSize = .small
        spinner.isHidden = true
        submitRow.addArrangedSubview(spinner)

        statusLabel.font = .systemFont(ofSize: 12)
        statusLabel.textColor = .secondaryLabelColor
        statusLabel.isHidden = true
        submitRow.addArrangedSubview(statusLabel)

        formStack.addArrangedSubview(submitRow)

        // Width constraints
        for field in [categoryPopup, nameField, emailField, messageScrollView, attachRow, attachmentsStack, submitRow] as [NSView] {
            field.translatesAutoresizingMaskIntoConstraints = false
            field.widthAnchor.constraint(equalTo: formStack.widthAnchor, constant: -40).isActive = true
        }
        messageScrollView.heightAnchor.constraint(greaterThanOrEqualToConstant: 120).isActive = true
    }

    // MARK: - Attachments

    @objc private func attachTapped() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = true
        panel.prompt = L10n.attachChoose

        if #available(macOS 11.0, *) {
            var types: [UTType] = [.png, .jpeg, .gif, .webP, .pdf, .plainText]
            if let logType = UTType(filenameExtension: "log") { types.append(logType) }
            panel.allowedContentTypes = types
        }

        panel.beginSheetModal(for: view.window!) { [weak self] response in
            guard response == .OK, let self else { return }
            for url in panel.urls {
                self.handleSelectedFile(url)
            }
        }
    }

    private func handleSelectedFile(_ url: URL) {
        guard pendingAttachments.count < MAX_ATTACHMENTS_PER_PARENT else {
            showStatus(String(format: L10n.attachMaxFiles, MAX_ATTACHMENTS_PER_PARENT), isError: true)
            return
        }

        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            showStatus(L10n.attachReadFailed, isError: true)
            return
        }

        let fileName = url.lastPathComponent
        guard data.count > 0, data.count <= MAX_ATTACHMENT_SIZE else {
            showStatus(String(format: L10n.attachTooLarge, fileName), isError: true)
            return
        }

        let totalAfter = pendingAttachments.reduce(0) { $0 + $1.sizeBytes } + data.count
        guard totalAfter <= MAX_ATTACHMENTS_TOTAL_SIZE else {
            showStatus(L10n.attachTotalTooLarge, isError: true)
            return
        }

        let mime = mimeType(forExtension: url.pathExtension.lowercased())
        pendingAttachments.append(PendingAttachment(url: url, data: data, fileName: fileName, mimeType: mime))
        renderAttachments()
        statusLabel.isHidden = true
    }

    private func mimeType(forExtension ext: String) -> String {
        switch ext {
        case "png": return "image/png"
        case "jpg", "jpeg": return "image/jpeg"
        case "gif": return "image/gif"
        case "webp": return "image/webp"
        case "pdf": return "application/pdf"
        case "txt", "log": return "text/plain"
        default: return "application/octet-stream"
        }
    }

    private func renderAttachments() {
        attachmentsStack.arrangedSubviews.forEach { $0.removeFromSuperview() }

        for (index, att) in pendingAttachments.enumerated() {
            let row = NSStackView()
            row.orientation = .horizontal
            row.spacing = 6
            row.alignment = .centerY

            let icon = NSImageView()
            let symbolName = att.mimeType.hasPrefix("image/") ? "photo" : "doc.text"
            if let img = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil) {
                icon.image = img
                icon.contentTintColor = .secondaryLabelColor
            }
            icon.setContentHuggingPriority(.required, for: .horizontal)
            row.addArrangedSubview(icon)

            let name = NSTextField(labelWithString: att.fileName)
            name.font = .systemFont(ofSize: 12)
            name.lineBreakMode = .byTruncatingMiddle
            row.addArrangedSubview(name)

            let size = NSTextField(labelWithString: humanSize(att.sizeBytes))
            size.font = .systemFont(ofSize: 11)
            size.textColor = .tertiaryLabelColor
            size.setContentHuggingPriority(.required, for: .horizontal)
            row.addArrangedSubview(size)

            let remove = NSButton(title: "", target: self, action: #selector(removeAttachmentTapped(_:)))
            remove.bezelStyle = .circular
            remove.controlSize = .small
            remove.tag = index
            if let xmark = NSImage(systemSymbolName: "xmark", accessibilityDescription: L10n.attachRemove) {
                remove.image = xmark
                remove.imagePosition = .imageOnly
            }
            remove.setContentHuggingPriority(.required, for: .horizontal)
            row.addArrangedSubview(remove)

            attachmentsStack.addArrangedSubview(row)
            row.translatesAutoresizingMaskIntoConstraints = false
            row.widthAnchor.constraint(equalTo: attachmentsStack.widthAnchor).isActive = true
        }
    }

    @objc private func removeAttachmentTapped(_ sender: NSButton) {
        let idx = sender.tag
        guard idx >= 0, idx < pendingAttachments.count else { return }
        pendingAttachments.remove(at: idx)
        renderAttachments()
    }

    private func humanSize(_ bytes: Int) -> String {
        if bytes < 1024 { return "\(bytes) B" }
        if bytes < 1024 * 1024 { return String(format: "%.1f KB", Double(bytes) / 1024) }
        return String(format: "%.1f MB", Double(bytes) / (1024 * 1024))
    }

    // MARK: - Success view

    private func setupSuccessView(in root: NSView) {
        successContainer.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(successContainer)

        NSLayoutConstraint.activate([
            successContainer.topAnchor.constraint(equalTo: root.topAnchor),
            successContainer.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            successContainer.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            successContainer.bottomAnchor.constraint(equalTo: root.bottomAnchor),
        ])

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.spacing = 12
        stack.alignment = .centerX
        stack.translatesAutoresizingMaskIntoConstraints = false
        successContainer.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: successContainer.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: successContainer.centerYAnchor, constant: -20),
            stack.widthAnchor.constraint(lessThanOrEqualTo: successContainer.widthAnchor, constant: -60),
        ])

        // Checkmark icon
        let checkImage = NSImageView()
        if let symbol = NSImage(systemSymbolName: "checkmark.circle.fill", accessibilityDescription: nil) {
            let config = NSImage.SymbolConfiguration(pointSize: 48, weight: .light)
            checkImage.image = symbol.withSymbolConfiguration(config)
            checkImage.contentTintColor = .systemGreen
        }
        stack.addArrangedSubview(checkImage)

        // Title
        let title = NSTextField(labelWithString: L10n.successTitle)
        title.font = .systemFont(ofSize: 20, weight: .semibold)
        title.textColor = .labelColor
        title.alignment = .center
        stack.addArrangedSubview(title)

        // Subtitle
        let subtitle = NSTextField(wrappingLabelWithString: L10n.successSubtitle)
        subtitle.font = .systemFont(ofSize: 13)
        subtitle.textColor = .secondaryLabelColor
        subtitle.alignment = .center
        stack.addArrangedSubview(subtitle)

        // Spacer
        let spacer = NSView()
        spacer.translatesAutoresizingMaskIntoConstraints = false
        spacer.heightAnchor.constraint(equalToConstant: 8).isActive = true
        stack.addArrangedSubview(spacer)

        // "Send Another" button
        let anotherButton = NSButton(title: L10n.sendAnother, target: self, action: #selector(sendAnotherTapped))
        anotherButton.bezelStyle = .rounded
        anotherButton.controlSize = .large
        stack.addArrangedSubview(anotherButton)

        // "Close" button
        let closeButton = NSButton(title: L10n.close, target: self, action: #selector(closeTapped))
        closeButton.bezelStyle = .rounded
        closeButton.controlSize = .regular
        stack.addArrangedSubview(closeButton)
    }

    // MARK: - Identity

    private func loadIdentity() {
        nameField.stringValue = store.resolveName(configName: config.userName) ?? ""
        emailField.stringValue = store.resolveEmail(configEmail: config.userEmail) ?? ""
    }

    private func addLabel(_ text: String, to stack: NSStackView) {
        let label = NSTextField(labelWithString: text)
        label.font = .systemFont(ofSize: 12, weight: .medium)
        label.textColor = .secondaryLabelColor
        stack.addArrangedSubview(label)
    }

    // MARK: - Submit

    @objc private func submitTapped() {
        let name = nameField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let email = emailField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let message = messageTextView.string.trimmingCharacters(in: .whitespacesAndNewlines)

        if name.isEmpty || email.isEmpty {
            showStatus(L10n.nameEmailRequired, isError: true)
            return
        }
        if message.count < 10 {
            showStatus(L10n.messageTooShort, isError: true)
            return
        }

        let category = FeedbackCategory.allCases[categoryPopup.indexOfSelectedItem]
        let metadata = DeviceMetadata.collect()
        let attachmentsToUpload = pendingAttachments

        setFormEnabled(false)
        spinner.isHidden = false
        spinner.startAnimation(nil)
        statusLabel.isHidden = true

        Task {
            do {
                // Upload attachments first so we can bind them atomically with the feedback insert.
                var attachmentIds: [String] = []
                for (index, att) in attachmentsToUpload.enumerated() {
                    showStatus(String(format: L10n.attachUploading, index + 1, attachmentsToUpload.count), isError: false)
                    let uploaded = try await apiClient.uploadAttachment(
                        data: att.data,
                        fileName: att.fileName,
                        mimeType: att.mimeType
                    )
                    attachmentIds.append(uploaded.attachmentId)
                }

                statusLabel.isHidden = true
                let result = try await apiClient.submitFeedback(
                    category: category.rawValue,
                    message: message,
                    name: name,
                    email: email,
                    metadata: metadata,
                    attachmentIds: attachmentIds.isEmpty ? nil : attachmentIds
                )
                store.savedName = name
                store.savedEmail = email
                store.saveToken(result.conversationToken)

                spinner.stopAnimation(nil)
                spinner.isHidden = true
                showSuccessView()
            } catch {
                spinner.stopAnimation(nil)
                spinner.isHidden = true
                let msg = (error as? StorePalError).flatMap { err -> String? in
                    if case .apiError(let e) = err { return e.message }
                    return nil
                } ?? L10n.genericError
                showStatus(msg, isError: true)
                setFormEnabled(true)
            }
        }
    }

    // MARK: - Success / Reset

    private func showSuccessView() {
        formStack.isHidden = true
        successContainer.isHidden = false
    }

    @objc private func sendAnotherTapped() {
        messageTextView.string = ""
        pendingAttachments.removeAll()
        renderAttachments()
        updatePlaceholder()
        statusLabel.isHidden = true
        setFormEnabled(true)
        successContainer.isHidden = true
        formStack.isHidden = false
    }

    @objc private func closeTapped() {
        view.window?.close()
    }

    // MARK: - Helpers

    private func setFormEnabled(_ enabled: Bool) {
        categoryPopup.isEnabled = enabled
        nameField.isEnabled = enabled
        emailField.isEnabled = enabled
        messageTextView.isEditable = enabled
        submitButton.isEnabled = enabled
        attachButton.isEnabled = enabled
        for row in attachmentsStack.arrangedSubviews {
            for sub in (row as? NSStackView)?.arrangedSubviews ?? [] {
                if let btn = sub as? NSButton { btn.isEnabled = enabled }
            }
        }
    }

    private func showStatus(_ text: String, isError: Bool) {
        statusLabel.stringValue = text
        statusLabel.textColor = isError ? .systemRed : .systemGreen
        statusLabel.isHidden = false
    }

    private func updatePlaceholder() {
        placeholderLabel.isHidden = !messageTextView.string.isEmpty
    }
}

extension FeedbackFormViewController: NSTextViewDelegate {
    func textDidChange(_ notification: Notification) {
        updatePlaceholder()
    }
}
