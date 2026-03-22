import AppKit

/// Root view controller managing tab switching and navigation.
@MainActor
final class FeedbackTabViewController: NSViewController {
    private let apiClient: APIClient
    private let config: StorePalConfiguration
    private let store: ConversationStore

    private let segmentedControl = NSSegmentedControl()
    private let containerView = NSView()

    private lazy var formVC = FeedbackFormViewController(apiClient: apiClient, config: config, store: store, delegate: self)
    private lazy var conversationsVC = ConversationsListViewController(apiClient: apiClient, config: config, delegate: self)

    private var currentChild: NSViewController?
    private var detailVC: ConversationDetailViewController?

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
        root.wantsLayer = true

        // Container for child view controllers
        containerView.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(containerView)

        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: root.topAnchor),
            containerView.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            containerView.bottomAnchor.constraint(equalTo: root.bottomAnchor),
        ])

        self.view = root
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupTitlebarSegmentedControl()
        showChild(formVC)
    }

    func refreshIfNeeded() {
        if currentChild === conversationsVC {
            conversationsVC.refresh()
        }
        updateUnreadBadge()
    }

    // MARK: - Titlebar segmented control

    private func setupTitlebarSegmentedControl() {
        segmentedControl.segmentCount = 2
        segmentedControl.setLabel("Send Feedback", forSegment: 0)
        segmentedControl.setLabel("Conversations", forSegment: 1)
        segmentedControl.selectedSegment = 0
        segmentedControl.segmentStyle = .automatic
        segmentedControl.target = self
        segmentedControl.action = #selector(segmentChanged)

        let accessory = NSTitlebarAccessoryViewController()
        accessory.layoutAttribute = .bottom
        let wrapper = NSView()
        segmentedControl.translatesAutoresizingMaskIntoConstraints = false
        wrapper.addSubview(segmentedControl)
        NSLayoutConstraint.activate([
            segmentedControl.centerXAnchor.constraint(equalTo: wrapper.centerXAnchor),
            segmentedControl.centerYAnchor.constraint(equalTo: wrapper.centerYAnchor),
            wrapper.heightAnchor.constraint(equalToConstant: 32),
        ])
        accessory.view = wrapper

        // Defer adding to window until window is available
        DispatchQueue.main.async { [weak self] in
            self?.view.window?.addTitlebarAccessoryViewController(accessory)
        }

        updateUnreadBadge()
    }

    @objc private func segmentChanged() {
        detailVC = nil
        switch segmentedControl.selectedSegment {
        case 0: showChild(formVC)
        case 1:
            showChild(conversationsVC)
            conversationsVC.refresh()
        default: break
        }
    }

    // MARK: - Navigation

    private func showChild(_ vc: NSViewController) {
        if let current = currentChild {
            current.view.removeFromSuperview()
            current.removeFromParent()
        }
        addChild(vc)
        vc.view.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(vc.view)
        NSLayoutConstraint.activate([
            vc.view.topAnchor.constraint(equalTo: containerView.topAnchor),
            vc.view.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            vc.view.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            vc.view.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
        ])
        currentChild = vc
    }

    func pushConversationDetail(token: String) {
        let detail = ConversationDetailViewController(token: token, apiClient: apiClient, config: config, delegate: self)
        self.detailVC = detail
        showChild(detail)
    }

    func popToConversations() {
        detailVC = nil
        showChild(conversationsVC)
        conversationsVC.refresh()
    }

    // MARK: - Badge

    private func updateUnreadBadge() {
        guard let email = conversationsVC.userEmail, !email.isEmpty else { return }
        Task {
            let count = try? await apiClient.getUnreadCount(email: email)
            let label = (count ?? 0) > 0 ? "Conversations (\(count!))" : "Conversations"
            segmentedControl.setLabel(label, forSegment: 1)
        }
    }
}

// MARK: - Delegate callbacks

extension FeedbackTabViewController: FeedbackFormDelegate {
    func feedbackFormDidSubmit(conversationToken: String, email: String) {
        // Now we know the user's email — update conversations list
        conversationsVC.userEmail = email
        updateUnreadBadge()
    }
}

extension FeedbackTabViewController: ConversationsListDelegate {
    func conversationsListDidSelect(token: String) {
        pushConversationDetail(token: token)
    }
}

extension FeedbackTabViewController: ConversationDetailDelegate {
    func conversationDetailDidTapBack() {
        popToConversations()
    }
}
