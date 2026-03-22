import AppKit

/// Manages the feedback panel window.
@MainActor
final class FeedbackWindowController: NSWindowController {
    init(apiClient: APIClient, config: StorePalConfiguration, store: ConversationStore) {
        let panel = FeedbackPanel()
        let formVC = FeedbackFormViewController(apiClient: apiClient, config: config, store: store)
        super.init(window: panel)

        panel.contentViewController = formVC
        panel.title = L10n.windowTitle
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
}
