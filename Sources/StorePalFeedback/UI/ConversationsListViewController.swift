import AppKit

@MainActor
protocol ConversationsListDelegate: AnyObject {
    func conversationsListDidSelect(token: String)
}

/// List of past feedback conversations with unread indicators.
@MainActor
final class ConversationsListViewController: NSViewController, NSTableViewDataSource, NSTableViewDelegate {
    private let apiClient: APIClient
    private let config: StorePalConfiguration
    private weak var delegate: ConversationsListDelegate?

    /// The email to list conversations for. Updated when the user submits feedback.
    var userEmail: String?

    private let scrollView = NSScrollView()
    private let tableView = NSTableView()
    private let emptyLabel = NSTextField(labelWithString: "No conversations yet")
    private let loadingSpinner = NSProgressIndicator()
    private var conversations: [ConversationSummary] = []

    private static let dateFormatter: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .short
        return f
    }()

    init(apiClient: APIClient, config: StorePalConfiguration, delegate: ConversationsListDelegate) {
        self.apiClient = apiClient
        self.config = config
        self.userEmail = config.userEmail
        self.delegate = delegate
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override func loadView() {
        let root = NSView()

        // Table setup
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("conversation"))
        column.title = ""
        tableView.addTableColumn(column)
        tableView.headerView = nil
        tableView.rowHeight = 64
        tableView.dataSource = self
        tableView.delegate = self
        tableView.style = .plain
        tableView.selectionHighlightStyle = .regular

        scrollView.documentView = tableView
        scrollView.hasVerticalScroller = true
        scrollView.drawsBackground = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(scrollView)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: root.topAnchor, constant: 44),
            scrollView.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: root.bottomAnchor),
        ])

        // Empty state
        emptyLabel.font = .systemFont(ofSize: 14)
        emptyLabel.textColor = .tertiaryLabelColor
        emptyLabel.alignment = .center
        emptyLabel.translatesAutoresizingMaskIntoConstraints = false
        emptyLabel.isHidden = true
        root.addSubview(emptyLabel)
        NSLayoutConstraint.activate([
            emptyLabel.centerXAnchor.constraint(equalTo: root.centerXAnchor),
            emptyLabel.centerYAnchor.constraint(equalTo: root.centerYAnchor),
        ])

        // Loading
        loadingSpinner.style = .spinning
        loadingSpinner.controlSize = .regular
        loadingSpinner.translatesAutoresizingMaskIntoConstraints = false
        loadingSpinner.isHidden = true
        root.addSubview(loadingSpinner)
        NSLayoutConstraint.activate([
            loadingSpinner.centerXAnchor.constraint(equalTo: root.centerXAnchor),
            loadingSpinner.centerYAnchor.constraint(equalTo: root.centerYAnchor),
        ])

        self.view = root
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        refresh()
    }

    func refresh() {
        guard let email = userEmail, !email.isEmpty else {
            conversations = []
            tableView.reloadData()
            emptyLabel.stringValue = "Submit feedback to see your conversations"
            emptyLabel.isHidden = false
            scrollView.isHidden = true
            return
        }

        loadingSpinner.isHidden = false
        loadingSpinner.startAnimation(nil)
        emptyLabel.isHidden = true

        Task {
            do {
                let page = try await apiClient.listConversations(email: email)
                conversations = page.conversations
                tableView.reloadData()
                emptyLabel.isHidden = !conversations.isEmpty
                scrollView.isHidden = conversations.isEmpty
            } catch {
                conversations = []
                tableView.reloadData()
                emptyLabel.stringValue = "Couldn't load conversations"
                emptyLabel.isHidden = false
                scrollView.isHidden = true
            }
            loadingSpinner.stopAnimation(nil)
            loadingSpinner.isHidden = true
        }
    }

    // MARK: - NSTableViewDataSource

    nonisolated func numberOfRows(in tableView: NSTableView) -> Int {
        MainActor.assumeIsolated { conversations.count }
    }

    // MARK: - NSTableViewDelegate

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let convo = conversations[row]

        let cell = NSView()

        // Unread dot
        let dot = UnreadBadgeView()
        dot.translatesAutoresizingMaskIntoConstraints = false
        dot.isHidden = !convo.hasUnreadReply
        cell.addSubview(dot)

        // Category tag
        let tag = CategoryTagView()
        tag.category = convo.category
        tag.translatesAutoresizingMaskIntoConstraints = false
        cell.addSubview(tag)

        // Message preview
        let preview = NSTextField(labelWithString: convo.message)
        preview.font = .systemFont(ofSize: 13, weight: convo.hasUnreadReply ? .semibold : .regular)
        preview.textColor = .labelColor
        preview.lineBreakMode = .byTruncatingTail
        preview.maximumNumberOfLines = 1
        preview.translatesAutoresizingMaskIntoConstraints = false
        cell.addSubview(preview)

        // Date
        let dateStr = Self.relativeDate(from: convo.lastReplyAt ?? convo.createdAt)
        let dateLabel = NSTextField(labelWithString: dateStr)
        dateLabel.font = .systemFont(ofSize: 11)
        dateLabel.textColor = .tertiaryLabelColor
        dateLabel.translatesAutoresizingMaskIntoConstraints = false
        cell.addSubview(dateLabel)

        // Reply count
        let replyLabel = NSTextField(labelWithString: convo.replyCount > 0 ? "\(convo.replyCount) replies" : "")
        replyLabel.font = .systemFont(ofSize: 11)
        replyLabel.textColor = .tertiaryLabelColor
        replyLabel.translatesAutoresizingMaskIntoConstraints = false
        cell.addSubview(replyLabel)

        NSLayoutConstraint.activate([
            dot.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 12),
            dot.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
            dot.widthAnchor.constraint(equalToConstant: 8),
            dot.heightAnchor.constraint(equalToConstant: 8),

            tag.leadingAnchor.constraint(equalTo: dot.trailingAnchor, constant: 8),
            tag.topAnchor.constraint(equalTo: cell.topAnchor, constant: 12),

            dateLabel.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -12),
            dateLabel.topAnchor.constraint(equalTo: cell.topAnchor, constant: 12),

            preview.leadingAnchor.constraint(equalTo: tag.leadingAnchor),
            preview.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -12),
            preview.topAnchor.constraint(equalTo: tag.bottomAnchor, constant: 4),

            replyLabel.leadingAnchor.constraint(equalTo: tag.leadingAnchor),
            replyLabel.topAnchor.constraint(equalTo: preview.bottomAnchor, constant: 2),
        ])

        return cell
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        let row = tableView.selectedRow
        guard row >= 0 && row < conversations.count else { return }
        tableView.deselectRow(row)
        delegate?.conversationsListDidSelect(token: conversations[row].conversationToken)
    }

    // MARK: - Date formatting

    private static func relativeDate(from iso: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let date = formatter.date(from: iso) ?? ISO8601DateFormatter().date(from: iso) else {
            return iso
        }
        return dateFormatter.localizedString(for: date, relativeTo: Date())
    }
}
