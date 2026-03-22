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

    private let scrollView = NSScrollView()
    private let stackView = NSStackView()
    private let categoryPopup = NSPopUpButton()
    private let nameField = NSTextField()
    private let emailField = NSTextField()
    private let messageScrollView = NSScrollView()
    private let messageTextView = NSTextView()
    private let placeholderLabel = NSTextField(labelWithString: "Describe your feedback...")
    private let metadataLabel = NSTextField(labelWithString: "")
    private let submitButton = NSButton()
    private let statusLabel = NSTextField(labelWithString: "")
    private let spinner = NSProgressIndicator()

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

        // Scroll view wrapping the form
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.drawsBackground = false
        scrollView.documentView = NSView()
        root.addSubview(scrollView)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: root.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: root.bottomAnchor),
        ])

        // Stack view inside scroll view
        stackView.orientation = .vertical
        stackView.spacing = 12
        stackView.alignment = .leading
        stackView.translatesAutoresizingMaskIntoConstraints = false

        let docView = scrollView.documentView!
        docView.addSubview(stackView)
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: docView.topAnchor, constant: 52),
            stackView.leadingAnchor.constraint(equalTo: docView.leadingAnchor, constant: 20),
            stackView.trailingAnchor.constraint(equalTo: docView.trailingAnchor, constant: -20),
            stackView.bottomAnchor.constraint(lessThanOrEqualTo: docView.bottomAnchor, constant: -20),
            stackView.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -40),
        ])

        // Title
        let title = NSTextField(labelWithString: "Send Feedback")
        title.font = .systemFont(ofSize: 18, weight: .bold)
        title.textColor = .labelColor
        stackView.addArrangedSubview(title)

        // Category
        let categoryLabel = NSTextField(labelWithString: "Category")
        categoryLabel.font = .systemFont(ofSize: 12, weight: .medium)
        categoryLabel.textColor = .secondaryLabelColor
        stackView.addArrangedSubview(categoryLabel)

        for cat in FeedbackCategory.allCases {
            categoryPopup.addItem(withTitle: cat.displayName)
        }
        categoryPopup.translatesAutoresizingMaskIntoConstraints = false
        stackView.addArrangedSubview(categoryPopup)
        categoryPopup.widthAnchor.constraint(equalTo: stackView.widthAnchor).isActive = true

        // Name
        addFormField(label: "Name", field: nameField, placeholder: "Your name")
        nameField.stringValue = config.userName ?? ""

        // Email
        addFormField(label: "Email", field: emailField, placeholder: "your@email.com")
        emailField.stringValue = config.userEmail ?? ""

        // Message
        let messageLabel = NSTextField(labelWithString: "Message")
        messageLabel.font = .systemFont(ofSize: 12, weight: .medium)
        messageLabel.textColor = .secondaryLabelColor
        stackView.addArrangedSubview(messageLabel)

        messageScrollView.hasVerticalScroller = true
        messageScrollView.borderType = .bezelBorder
        messageScrollView.translatesAutoresizingMaskIntoConstraints = false
        messageTextView.isRichText = false
        messageTextView.font = .systemFont(ofSize: 13)
        messageTextView.textContainerInset = NSSize(width: 8, height: 8)
        messageTextView.isAutomaticQuoteSubstitutionEnabled = false
        messageTextView.isAutomaticDashSubstitutionEnabled = false
        messageTextView.delegate = self
        messageScrollView.documentView = messageTextView

        stackView.addArrangedSubview(messageScrollView)
        NSLayoutConstraint.activate([
            messageScrollView.widthAnchor.constraint(equalTo: stackView.widthAnchor),
            messageScrollView.heightAnchor.constraint(greaterThanOrEqualToConstant: 120),
        ])

        // Placeholder overlay
        placeholderLabel.textColor = .placeholderTextColor
        placeholderLabel.font = .systemFont(ofSize: 13)
        placeholderLabel.translatesAutoresizingMaskIntoConstraints = false
        messageTextView.addSubview(placeholderLabel)
        NSLayoutConstraint.activate([
            placeholderLabel.topAnchor.constraint(equalTo: messageTextView.topAnchor, constant: 8),
            placeholderLabel.leadingAnchor.constraint(equalTo: messageTextView.leadingAnchor, constant: 12),
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

        submitButton.title = "Submit Feedback"
        submitButton.bezelStyle = .push
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
        submitRow.widthAnchor.constraint(equalTo: stackView.widthAnchor).isActive = true

        self.view = root
    }

    private func addFormField(label text: String, field: NSTextField, placeholder: String) {
        let label = NSTextField(labelWithString: text)
        label.font = .systemFont(ofSize: 12, weight: .medium)
        label.textColor = .secondaryLabelColor
        stackView.addArrangedSubview(label)

        field.placeholderString = placeholder
        field.font = .systemFont(ofSize: 13)
        field.translatesAutoresizingMaskIntoConstraints = false
        stackView.addArrangedSubview(field)
        field.widthAnchor.constraint(equalTo: stackView.widthAnchor).isActive = true
    }

    // MARK: - Submit

    @objc private func submitTapped() {
        let message = messageTextView.string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !nameField.stringValue.isEmpty,
              !emailField.stringValue.isEmpty,
              message.count >= 10 else {
            showStatus("Please fill in all fields (message must be at least 10 characters).", isError: true)
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
                    name: nameField.stringValue,
                    email: emailField.stringValue,
                    metadata: metadata
                )
                store.saveToken(result.conversationToken)
                spinner.stopAnimation(nil)
                spinner.isHidden = true
                showStatus("Feedback sent!", isError: false)
                messageTextView.string = ""
                updatePlaceholder()
                setFormEnabled(true)
                delegate?.feedbackFormDidSubmit(conversationToken: result.conversationToken, email: emailField.stringValue)
            } catch {
                spinner.stopAnimation(nil)
                spinner.isHidden = true
                let message = (error as? StorePalError).flatMap { err -> String? in
                    if case .apiError(let e) = err { return e.message }
                    return nil
                } ?? "Something went wrong. Please try again."
                showStatus(message, isError: true)
                setFormEnabled(true)
            }
        }
    }

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
