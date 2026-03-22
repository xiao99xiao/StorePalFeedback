import AppKit

private let toolbarID = NSToolbar.Identifier("StorePalFeedbackToolbar")
private let navItemID = NSToolbarItem.Identifier("navButton")

/// Manages the feedback panel window and its root view controller.
@MainActor
final class FeedbackWindowController: NSWindowController, NSToolbarDelegate {
    private let apiClient: APIClient
    private let config: StorePalConfiguration
    private let store: ConversationStore

    private let navButton = NSButton(title: "My Feedbacks", target: nil, action: nil)

    private lazy var formVC = FeedbackFormViewController(apiClient: apiClient, config: config, store: store, delegate: self)
    private lazy var listVC = ConversationsListViewController(apiClient: apiClient, config: config, delegate: self)
    private var detailVC: ConversationDetailViewController?

    private var currentChild: NSViewController?

    enum Screen { case form, list, detail }
    private var currentScreen: Screen = .form

    init(apiClient: APIClient, config: StorePalConfiguration, store: ConversationStore) {
        self.apiClient = apiClient
        self.config = config
        self.store = store
        let panel = FeedbackPanel()
        super.init(window: panel)
        setupToolbar(on: panel)
        showScreen(.form)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    func showPanel() {
        window?.makeKeyAndOrderFront(nil)
    }

    func hidePanel() {
        window?.orderOut(nil)
    }

    func togglePanel() {
        if window?.isVisible == true { hidePanel() } else { showPanel() }
    }

    func refreshIfNeeded() {
        if currentScreen == .list { listVC.refresh() }
    }

    // MARK: - Toolbar

    private func setupToolbar(on window: NSWindow) {
        navButton.bezelStyle = .rounded
        navButton.target = self
        navButton.action = #selector(navButtonTapped)

        let toolbar = NSToolbar(identifier: toolbarID)
        toolbar.delegate = self
        toolbar.displayMode = .iconOnly
        toolbar.allowsUserCustomization = false

        window.toolbar = toolbar
        window.toolbarStyle = .unified
    }

    nonisolated func toolbar(_ toolbar: NSToolbar, itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier, willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {
        MainActor.assumeIsolated {
            if itemIdentifier == navItemID {
                let item = NSToolbarItem(itemIdentifier: navItemID)
                item.view = navButton
                item.label = ""
                return item
            }
            return nil
        }
    }

    nonisolated func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [.flexibleSpace, navItemID]
    }

    nonisolated func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [navItemID, .flexibleSpace]
    }

    @objc private func navButtonTapped() {
        switch currentScreen {
        case .form:
            showScreen(.list)
        case .list:
            showScreen(.form)
        case .detail:
            showScreen(.list)
        }
    }

    // MARK: - Screen management

    private func showScreen(_ screen: Screen) {
        let vc: NSViewController
        switch screen {
        case .form:
            vc = formVC
            window?.title = "Send Feedback"
            navButton.title = "My Feedbacks"
            navButton.image = NSImage(systemSymbolName: "tray.full", accessibilityDescription: "My Feedbacks")
            navButton.imagePosition = .imageLeading
        case .list:
            listVC.refresh()
            vc = listVC
            window?.title = "My Feedbacks"
            navButton.title = "Send Feedback"
            navButton.image = NSImage(systemSymbolName: "square.and.pencil", accessibilityDescription: "Send Feedback")
            navButton.imagePosition = .imageLeading
        case .detail:
            guard let detail = detailVC else { return }
            vc = detail
            window?.title = "Feedback Detail"
            navButton.title = "Back"
            navButton.image = NSImage(systemSymbolName: "chevron.left", accessibilityDescription: "Back")
            navButton.imagePosition = .imageLeading
        }

        // Swap content
        if let current = currentChild {
            current.view.removeFromSuperview()
            current.removeFromParent()
        }
        window?.contentViewController = nil

        let container = NSView(frame: window?.contentView?.bounds ?? .zero)
        container.wantsLayer = true
        vc.view.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(vc.view)
        NSLayoutConstraint.activate([
            vc.view.topAnchor.constraint(equalTo: container.topAnchor),
            vc.view.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            vc.view.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            vc.view.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])

        window?.contentView = container
        currentChild = vc
        currentScreen = screen
    }
}

// MARK: - Delegate callbacks

extension FeedbackWindowController: FeedbackFormDelegate {
    func feedbackFormDidSubmit(conversationToken: String, email: String) {
        listVC.userEmail = email
        showScreen(.list)
    }
}

extension FeedbackWindowController: ConversationsListDelegate {
    func conversationsListDidSelect(token: String) {
        detailVC = ConversationDetailViewController(token: token, apiClient: apiClient, config: config, delegate: self)
        showScreen(.detail)
    }
}

extension FeedbackWindowController: ConversationDetailDelegate {
    func conversationDetailDidTapBack() {
        showScreen(.list)
    }
}
