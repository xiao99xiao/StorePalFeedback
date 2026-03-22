import AppKit

/// Manages the feedback panel window and its root tab view controller.
@MainActor
final class FeedbackWindowController: NSWindowController {
    private let tabVC: FeedbackTabViewController

    init(apiClient: APIClient, config: StorePalConfiguration, store: ConversationStore) {
        let panel = FeedbackPanel()
        self.tabVC = FeedbackTabViewController(apiClient: apiClient, config: config, store: store)
        super.init(window: panel)
        panel.contentViewController = tabVC
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError()
    }

    func showPanel() {
        window?.makeKeyAndOrderFront(nil)
        tabVC.refreshIfNeeded()
    }

    func hidePanel() {
        window?.orderOut(nil)
    }

    func togglePanel() {
        if window?.isVisible == true {
            hidePanel()
        } else {
            showPanel()
        }
    }
}
