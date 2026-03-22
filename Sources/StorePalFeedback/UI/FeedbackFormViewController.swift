import AppKit

@MainActor
protocol FeedbackFormDelegate: AnyObject {
    func feedbackFormDidSubmit(conversationToken: String, email: String)
}

/// Form for submitting new feedback.
@MainActor
final class FeedbackFormViewController: NSViewController {
    private let apiClient: APIClient
    private let config: StorePalConfiguration
    private let store: ConversationStore
    private weak var delegate: FeedbackFormDelegate?

    private let stackView = NSStackView()
    private let categoryPopup = NSPopUpButton()
    private let nameField = NSTextField()
    private let emailField = NSTextField()
    private let changeIdentityButton = NSButton(title: "Change", target: nil, action: nil)
    private let messageScrollView = NSScrollView()
    private let messageTextView = NSTextView()
    private let placeholderLabel = NSTextField(labelWithString: "Describe your feedback...")
    private let metadataLabel = NSTextField(labelWithString: "")
    private let submitButton = NSButton(title: "Submit Feedback", target: nil, action: nil)
    private let statusLabel = NSTextField(labelWithString: "")
    private let spinner = NSProgressIndicator()

    /// Whether the name/email fields are currently locked (user previously submitted)
    private var identityLocked = false

    init(apiClient: APIClient, config: StorePalConfiguration, store: ConversationStore, delegate: FeedbackFormDelegate) {
        self.apiClient = apiClient
        self.config = config
        self.store = store
        self.delegate = delegate
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override func loadView() {
        let root = NSView()

        stackView.orientation = .vertical
        stackView.spacing = 10
        stackView.alignment = .leading
        stackView.edgeInsets = NSEdgeInsets(top: 16, left: 20, bottom: 20, right: 20)
        stackView.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(stackView)

        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: root.topAnchor),
            stackView.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: root.trailingAnchor),
        ])

        // Category
        addLabel("Category")
        for cat in FeedbackCategory.allCases {
            categoryPopup.addItem(withTitle: cat.displayName)
        }
        stackView.addArrangedSubview(categoryPopup)

        // Name
        addLabel("Name")
        nameField.placeholderString = "Your name"
        nameField.font = .systemFont(ofSize: 13)
        stackView.addArrangedSubview(nameField)

        // Email + Change button row
        let emailLabelRow = NSStackView()
        emailLabelRow.orientation = .horizontal
        emailLabelRow.spacing = 4
        let emailLabel = NSTextField(labelWithString: "Email")
        emailLabel.font = .systemFont(ofSize: 12, weight: .medium)
        emailLabel.textColor = .secondaryLabelColor
        emailLabelRow.addArrangedSubview(emailLabel)

        changeIdentityButton.bezelStyle = .rounded
        changeIdentityButton.controlSize = .mini
        changeIdentityButton.font = .systemFont(ofSize: 10)
        changeIdentityButton.target = self
        changeIdentityButton.action = #selector(changeIdentityTapped)
        changeIdentityButton.isHidden = true
        emailLabelRow.addArrangedSubview(changeIdentityButton)

        stackView.addArrangedSubview(emailLabelRow)

        emailField.placeholderString = "your@email.com"
        emailField.font = .systemFont(ofSize: 13)
        stackView.addArrangedSubview(emailField)

        // Message
        addLabel("Message")

        messageTextView.isRichText = false
        messageTextView.font = .systemFont(ofSize: 13)
        messageTextView.textContainerInset = NSSize(width: 6, height: 6)
        messageTextView.isAutomaticQuoteSubstitutionEnabled = false
        messageTextView.isAutomaticDashSubstitutionEnabled = false
        messageTextView.delegate = self

        messageScrollView.documentView = messageTextView
        messageScrollView.hasVerticalScroller = true
        messageScrollView.borderType = .bezelBorder
        stackView.addArrangedSubview(messageScrollView)

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
        stackView.addArrangedSubview(metadataLabel)

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

        stackView.addArrangedSubview(submitRow)

        // Width constraints
        for field in [categoryPopup, nameField, emailField, messageScrollView, submitRow] as [NSView] {
            field.translatesAutoresizingMaskIntoConstraints = false
            field.widthAnchor.constraint(equalTo: stackView.widthAnchor, constant: -40).isActive = true
        }
        emailLabelRow.translatesAutoresizingMaskIntoConstraints = false

        messageScrollView.heightAnchor.constraint(greaterThanOrEqualToConstant: 120).isActive = true

        self.view = root

        // Populate from saved identity or config
        loadIdentity()
    }

    // MARK: - Identity management

    private func loadIdentity() {
        let name = store.resolveName(configName: config.userName) ?? ""
        let email = store.resolveEmail(configEmail: config.userEmail) ?? ""

        nameField.stringValue = name
        emailField.stringValue = email

        // Lock if we have a saved identity (user has submitted before)
        if store.savedEmail != nil {
            lockIdentity()
        }
    }

    private func lockIdentity() {
        identityLocked = true
        nameField.isEditable = false
        nameField.isSelectable = false
        nameField.drawsBackground = false
        nameField.isBezeled = false
        nameField.textColor = .labelColor

        emailField.isEditable = false
        emailField.isSelectable = false
        emailField.drawsBackground = false
        emailField.isBezeled = false
        emailField.textColor = .labelColor

        changeIdentityButton.isHidden = false
    }

    private func unlockIdentity() {
        identityLocked = false
        nameField.isEditable = true
        nameField.isSelectable = true
        nameField.drawsBackground = true
        nameField.isBezeled = true
        nameField.textColor = .controlTextColor

        emailField.isEditable = true
        emailField.isSelectable = true
        emailField.drawsBackground = true
        emailField.isBezeled = true
        emailField.textColor = .controlTextColor

        changeIdentityButton.isHidden = true
    }

    @objc private func changeIdentityTapped() {
        let alert = NSAlert()
        alert.messageText = "Change your identity?"
        alert.informativeText = "If you change your email, you won't be able to see your previous feedback history."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Change")
        alert.addButton(withTitle: "Cancel")

        if alert.runModal() == .alertFirstButtonReturn {
            store.savedEmail = nil
            store.savedName = nil
            store.clearTokens()
            unlockIdentity()
        }
    }

    private func addLabel(_ text: String) {
        let label = NSTextField(labelWithString: text)
        label.font = .systemFont(ofSize: 12, weight: .medium)
        label.textColor = .secondaryLabelColor
        stackView.addArrangedSubview(label)
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
                // Save identity and token
                store.savedName = name
                store.savedEmail = email
                store.saveToken(result.conversationToken)

                spinner.stopAnimation(nil)
                spinner.isHidden = true
                showStatus("Feedback sent!", isError: false)
                messageTextView.string = ""
                updatePlaceholder()
                lockIdentity()
                setFormEnabled(true)
                delegate?.feedbackFormDidSubmit(conversationToken: result.conversationToken, email: email)
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

    private func setFormEnabled(_ enabled: Bool) {
        categoryPopup.isEnabled = enabled
        if !identityLocked {
            nameField.isEnabled = enabled
            emailField.isEnabled = enabled
        }
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
