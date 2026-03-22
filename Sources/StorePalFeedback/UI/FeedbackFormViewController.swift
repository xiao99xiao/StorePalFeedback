import AppKit

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
    private let placeholderLabel = NSTextField(labelWithString: "Describe your feedback...")
    private let metadataLabel = NSTextField(labelWithString: "")
    private let submitButton = NSButton(title: "Submit Feedback", target: nil, action: nil)
    private let statusLabel = NSTextField(labelWithString: "")
    private let spinner = NSProgressIndicator()

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
        addLabel("Category", to: formStack)
        for cat in FeedbackCategory.allCases {
            categoryPopup.addItem(withTitle: cat.displayName)
        }
        formStack.addArrangedSubview(categoryPopup)

        // Name
        addLabel("Name", to: formStack)
        nameField.placeholderString = "Your name"
        nameField.font = .systemFont(ofSize: 13)
        formStack.addArrangedSubview(nameField)

        // Email
        addLabel("Email", to: formStack)
        emailField.placeholderString = "your@email.com"
        emailField.font = .systemFont(ofSize: 13)
        formStack.addArrangedSubview(emailField)

        // Message
        addLabel("Message", to: formStack)
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
        for field in [categoryPopup, nameField, emailField, messageScrollView, submitRow] as [NSView] {
            field.translatesAutoresizingMaskIntoConstraints = false
            field.widthAnchor.constraint(equalTo: formStack.widthAnchor, constant: -40).isActive = true
        }
        messageScrollView.heightAnchor.constraint(greaterThanOrEqualToConstant: 120).isActive = true
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
        if let symbol = NSImage(systemSymbolName: "checkmark.circle.fill", accessibilityDescription: "Success") {
            let config = NSImage.SymbolConfiguration(pointSize: 48, weight: .light)
            checkImage.image = symbol.withSymbolConfiguration(config)
            checkImage.contentTintColor = .systemGreen
        }
        stack.addArrangedSubview(checkImage)

        // Title
        let title = NSTextField(labelWithString: "Thank you!")
        title.font = .systemFont(ofSize: 20, weight: .semibold)
        title.textColor = .labelColor
        title.alignment = .center
        stack.addArrangedSubview(title)

        // Subtitle
        let subtitle = NSTextField(wrappingLabelWithString: "Your feedback has been received. We'll review it and get back to you if needed.")
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
        let anotherButton = NSButton(title: "Send Another", target: self, action: #selector(sendAnotherTapped))
        anotherButton.bezelStyle = .rounded
        anotherButton.controlSize = .large
        stack.addArrangedSubview(anotherButton)

        // "Close" button
        let closeButton = NSButton(title: "Close", target: self, action: #selector(closeTapped))
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
            showStatus("Name and email are required.", isError: true)
            return
        }
        if message.count < 10 {
            showStatus("Message must be at least 10 characters.", isError: true)
            return
        }

        let category = FeedbackCategory.allCases[categoryPopup.indexOfSelectedItem]
        let metadata = DeviceMetadata.collect()

        setFormEnabled(false)
        spinner.isHidden = false
        spinner.startAnimation(nil)
        statusLabel.isHidden = true

        Task {
            do {
                let result = try await apiClient.submitFeedback(
                    category: category.rawValue,
                    message: message,
                    name: name,
                    email: email,
                    metadata: metadata
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
                } ?? "Something went wrong. Please try again."
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
