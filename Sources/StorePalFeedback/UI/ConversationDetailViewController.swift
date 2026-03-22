import AppKit

@MainActor
protocol ConversationDetailDelegate: AnyObject {
    func conversationDetailDidTapBack()
}

/// Thread view showing the original feedback and all replies.
@MainActor
final class ConversationDetailViewController: NSViewController {
    private let token: String
    private let apiClient: APIClient
    private let config: StorePalConfiguration
    private weak var delegate: ConversationDetailDelegate?

    private let backButton = NSButton()
    private let headerStack = NSStackView()
    private let scrollView = NSScrollView()
    private let messagesStack = NSStackView()
    private let replyField = NSTextField()
    private let sendButton = NSButton()
    private let statusLabel = NSTextField(labelWithString: "")
    private let loadingSpinner = NSProgressIndicator()

    private var detail: ConversationDetail?
    private var cooldownTimer: Timer?
    private var cooldownRemaining = 0

    init(token: String, apiClient: APIClient, config: StorePalConfiguration, delegate: ConversationDetailDelegate) {
        self.token = token
        self.apiClient = apiClient
        self.config = config
        self.delegate = delegate
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override func loadView() {
        let root = NSView()

        // Back button + header
        backButton.title = "Back"
        backButton.bezelStyle = .accessoryBarAction
        backButton.target = self
        backButton.action = #selector(backTapped)
        backButton.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(backButton)

        headerStack.orientation = .horizontal
        headerStack.spacing = 8
        headerStack.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(headerStack)

        // Messages scroll
        messagesStack.orientation = .vertical
        messagesStack.spacing = 8
        messagesStack.alignment = .leading

        let docView = NSView()
        docView.wantsLayer = true
        messagesStack.translatesAutoresizingMaskIntoConstraints = false
        docView.addSubview(messagesStack)

        scrollView.documentView = docView
        scrollView.hasVerticalScroller = true
        scrollView.drawsBackground = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(scrollView)

        // Reply bar
        let replyBar = NSStackView()
        replyBar.orientation = .horizontal
        replyBar.spacing = 8
        replyBar.translatesAutoresizingMaskIntoConstraints = false

        replyField.placeholderString = "Type a reply..."
        replyField.font = .systemFont(ofSize: 13)
        replyField.target = self
        replyField.action = #selector(sendTapped)
        replyBar.addArrangedSubview(replyField)

        sendButton.title = "Send"
        sendButton.bezelStyle = .push
        sendButton.target = self
        sendButton.action = #selector(sendTapped)
        replyBar.addArrangedSubview(sendButton)

        root.addSubview(replyBar)

        // Status
        statusLabel.font = .systemFont(ofSize: 11)
        statusLabel.textColor = .tertiaryLabelColor
        statusLabel.isHidden = true
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(statusLabel)

        // Loading
        loadingSpinner.style = .spinning
        loadingSpinner.controlSize = .regular
        loadingSpinner.translatesAutoresizingMaskIntoConstraints = false
        loadingSpinner.isHidden = true
        root.addSubview(loadingSpinner)

        // Layout
        NSLayoutConstraint.activate([
            backButton.topAnchor.constraint(equalTo: root.topAnchor, constant: 48),
            backButton.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 12),

            headerStack.centerYAnchor.constraint(equalTo: backButton.centerYAnchor),
            headerStack.leadingAnchor.constraint(equalTo: backButton.trailingAnchor, constant: 8),

            scrollView.topAnchor.constraint(equalTo: backButton.bottomAnchor, constant: 8),
            scrollView.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: replyBar.topAnchor, constant: -8),

            messagesStack.topAnchor.constraint(equalTo: docView.topAnchor, constant: 12),
            messagesStack.leadingAnchor.constraint(equalTo: docView.leadingAnchor, constant: 16),
            messagesStack.trailingAnchor.constraint(equalTo: docView.trailingAnchor, constant: -16),
            messagesStack.bottomAnchor.constraint(lessThanOrEqualTo: docView.bottomAnchor, constant: -12),
            messagesStack.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -32),

            replyBar.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 16),
            replyBar.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -16),
            replyBar.bottomAnchor.constraint(equalTo: statusLabel.topAnchor, constant: -4),

            statusLabel.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 16),
            statusLabel.bottomAnchor.constraint(equalTo: root.bottomAnchor, constant: -12),

            loadingSpinner.centerXAnchor.constraint(equalTo: root.centerXAnchor),
            loadingSpinner.centerYAnchor.constraint(equalTo: root.centerYAnchor),
        ])

        self.view = root
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        loadConversation()
    }

    // MARK: - Load

    private func loadConversation() {
        loadingSpinner.isHidden = false
        loadingSpinner.startAnimation(nil)
        scrollView.isHidden = true

        Task {
            do {
                let detail = try await apiClient.getConversation(token: token)
                self.detail = detail
                renderMessages(detail)
                scrollView.isHidden = false
            } catch {
                showStatus("Couldn't load conversation", isError: true)
            }
            loadingSpinner.stopAnimation(nil)
            loadingSpinner.isHidden = true
        }
    }

    private func renderMessages(_ detail: ConversationDetail) {
        // Clear existing
        messagesStack.arrangedSubviews.forEach { $0.removeFromSuperview() }

        // Header
        let tag = CategoryTagView()
        tag.category = detail.feedback.category
        headerStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        headerStack.addArrangedSubview(tag)

        let dateStr = formatDate(detail.feedback.createdAt)
        let dateLabel = NSTextField(labelWithString: "Started \(dateStr)")
        dateLabel.font = .systemFont(ofSize: 12)
        dateLabel.textColor = .tertiaryLabelColor
        headerStack.addArrangedSubview(dateLabel)

        // Original message
        let original = MessageBubbleView(
            message: detail.feedback.message,
            sender: "You",
            date: formatDate(detail.feedback.createdAt),
            isFromUser: true
        )
        original.translatesAutoresizingMaskIntoConstraints = false
        messagesStack.addArrangedSubview(original)

        // Alignment: user messages trailing, developer messages leading
        NSLayoutConstraint.activate([
            original.trailingAnchor.constraint(equalTo: messagesStack.trailingAnchor),
        ])

        // Replies
        for reply in detail.replies {
            let isUser = reply.senderType == "user"
            let bubble = MessageBubbleView(
                message: reply.message,
                sender: isUser ? "You" : "Developer",
                date: formatDate(reply.createdAt),
                isFromUser: isUser
            )
            bubble.translatesAutoresizingMaskIntoConstraints = false
            messagesStack.addArrangedSubview(bubble)

            if isUser {
                bubble.trailingAnchor.constraint(equalTo: messagesStack.trailingAnchor).isActive = true
            } else {
                bubble.leadingAnchor.constraint(equalTo: messagesStack.leadingAnchor).isActive = true
            }
        }

        // Check reply limit
        let userReplies = detail.replies.filter { $0.senderType == "user" }.count
        if userReplies >= 20 {
            replyField.isEnabled = false
            sendButton.isEnabled = false
            showStatus("Reply limit reached", isError: false)
        }

        // Scroll to bottom
        DispatchQueue.main.async { [weak self] in
            guard let docView = self?.scrollView.documentView else { return }
            let point = NSPoint(x: 0, y: docView.bounds.height)
            self?.scrollView.contentView.scroll(to: point)
        }
    }

    // MARK: - Reply

    @objc private func sendTapped() {
        let text = replyField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        sendButton.isEnabled = false
        replyField.isEnabled = false

        Task {
            do {
                let reply = try await apiClient.postReply(token: token, message: text)
                replyField.stringValue = ""
                replyField.isEnabled = true
                sendButton.isEnabled = true
                statusLabel.isHidden = true

                // Append bubble
                let bubble = MessageBubbleView(
                    message: reply.message,
                    sender: "You",
                    date: formatDate(reply.createdAt),
                    isFromUser: true
                )
                bubble.translatesAutoresizingMaskIntoConstraints = false
                messagesStack.addArrangedSubview(bubble)
                bubble.trailingAnchor.constraint(equalTo: messagesStack.trailingAnchor).isActive = true

                // Scroll to bottom
                DispatchQueue.main.async { [weak self] in
                    guard let docView = self?.scrollView.documentView else { return }
                    let point = NSPoint(x: 0, y: docView.bounds.height)
                    self?.scrollView.contentView.scroll(to: point)
                }
            } catch StorePalError.cooldown {
                startCooldown()
            } catch StorePalError.replyLimit {
                replyField.isEnabled = false
                sendButton.isEnabled = false
                showStatus("Reply limit reached", isError: false)
            } catch {
                replyField.isEnabled = true
                sendButton.isEnabled = true
                showStatus("Couldn't send reply", isError: true)
            }
        }
    }

    private func startCooldown() {
        cooldownRemaining = 30
        sendButton.isEnabled = false
        updateCooldownLabel()

        cooldownTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.cooldownRemaining -= 1
                if self.cooldownRemaining <= 0 {
                    self.cooldownTimer?.invalidate()
                    self.cooldownTimer = nil
                    self.sendButton.isEnabled = true
                    self.replyField.isEnabled = true
                    self.statusLabel.isHidden = true
                } else {
                    self.updateCooldownLabel()
                }
            }
        }
    }

    private func updateCooldownLabel() {
        showStatus("Wait \(cooldownRemaining)s before replying", isError: false)
        replyField.isEnabled = false
    }

    @objc private func backTapped() {
        cooldownTimer?.invalidate()
        delegate?.conversationDetailDidTapBack()
    }

    // MARK: - Helpers

    private func showStatus(_ text: String, isError: Bool) {
        statusLabel.stringValue = text
        statusLabel.textColor = isError ? .systemRed : .tertiaryLabelColor
        statusLabel.isHidden = false
    }

    private func formatDate(_ iso: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let date = formatter.date(from: iso) ?? ISO8601DateFormatter().date(from: iso) else {
            return iso
        }
        let relative = RelativeDateTimeFormatter()
        relative.unitsStyle = .short
        return relative.localizedString(for: date, relativeTo: Date())
    }
}
