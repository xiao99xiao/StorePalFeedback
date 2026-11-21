#if os(macOS)
import AppKit
import WebKit
import StorePalFeedback

/// Displays a "What's New" dialog with app icon, update heading,
/// and a WKWebView whose asynchronous article loading is covered by native controls.
@MainActor
final class WhatsNewWindowController: NSObject, NSWindowDelegate {

    private var window: NSWindow?
    private var releaseNotesURL: URL?
    private var releaseNoteURL: URL?
    private var pageMonitor: ReleasePageLoadMonitor?
    private weak var contentContainer: NSView?
    private weak var webView: WKWebView?
    private weak var loadingIndicator: NSProgressIndicator?
    private weak var errorStack: NSStackView?

    func show(version: String, releaseNoteURL: URL, appName: String, releaseNotesURL: URL? = nil) {
        if let existing = window, existing.isVisible {
            NSApp.activate(ignoringOtherApps: true)
            existing.makeKeyAndOrderFront(nil)
            return
        }

        self.releaseNotesURL = releaseNotesURL
        let window = makeWindow(appName: appName, version: version, releaseNoteURL: releaseNoteURL)
        self.window = window
        window.center()
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    // MARK: - Build window

    private func makeWindow(appName: String, version: String, releaseNoteURL: URL) -> NSWindow {
        let window = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 620, height: 340),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = StorePalLocalization.string("release.title")
        window.isMovableByWindowBackground = true
        window.delegate = self

        let root = NSView()
        root.translatesAutoresizingMaskIntoConstraints = false

        // --- Left: App icon ---
        let iconView = NSImageView()
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.imageScaling = .scaleProportionallyUpOrDown
        iconView.image = NSApp.applicationIconImage
        iconView.wantsLayer = true
        iconView.layer?.cornerRadius = 14
        iconView.layer?.masksToBounds = true
        root.addSubview(iconView)

        // --- Right: heading ---
        let headingLabel = NSTextField(wrappingLabelWithString: String(
            format: StorePalLocalization.string("release.updated"), appName, version
        ))
        headingLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        headingLabel.textColor = .labelColor
        headingLabel.translatesAutoresizingMaskIntoConstraints = false
        headingLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        root.addSubview(headingLabel)

        // --- Content, native loading indicator, and retry state ---
        let content = NSView()
        content.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(content)
        contentContainer = content
        self.releaseNoteURL = releaseNoteURL

        let spinner = NSProgressIndicator()
        spinner.style = .spinning
        spinner.isDisplayedWhenStopped = false
        spinner.identifier = NSUserInterfaceItemIdentifier("storepal.release.loading")
        spinner.setAccessibilityLabel(StorePalLocalization.string("release.loading"))
        spinner.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(spinner)
        loadingIndicator = spinner

        let error = NSStackView()
        error.orientation = .vertical
        error.alignment = .centerX
        error.spacing = 12
        error.identifier = NSUserInterfaceItemIdentifier("storepal.release.error")
        error.translatesAutoresizingMaskIntoConstraints = false
        let errorLabel = NSTextField(wrappingLabelWithString: StorePalLocalization.string("release.error"))
        errorLabel.alignment = .center
        error.addArrangedSubview(errorLabel)
        let retryButton = NSButton(title: StorePalLocalization.string("action.retry"), target: self, action: #selector(retryLoading))
        retryButton.bezelStyle = .rounded
        error.addArrangedSubview(retryButton)
        content.addSubview(error)
        errorStack = error
        NSLayoutConstraint.activate([
            spinner.centerXAnchor.constraint(equalTo: content.centerXAnchor),
            spinner.centerYAnchor.constraint(equalTo: content.centerYAnchor),
            error.centerXAnchor.constraint(equalTo: content.centerXAnchor),
            error.centerYAnchor.constraint(equalTo: content.centerYAnchor),
            error.widthAnchor.constraint(lessThanOrEqualTo: content.widthAnchor),
        ])
        loadReleasePage()

        // --- Bottom bar ---
        let bottomBar = NSView()
        bottomBar.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(bottomBar)

        if releaseNotesURL != nil {
            let linkButton = NSButton(title: StorePalLocalization.string("release.all"), target: self, action: #selector(openReleaseNotes))
            linkButton.bezelStyle = .inline
            linkButton.isBordered = false
            linkButton.contentTintColor = .controlAccentColor
            linkButton.font = .systemFont(ofSize: 11)
            linkButton.translatesAutoresizingMaskIntoConstraints = false
            bottomBar.addSubview(linkButton)
            NSLayoutConstraint.activate([
                linkButton.leadingAnchor.constraint(equalTo: bottomBar.leadingAnchor),
                linkButton.centerYAnchor.constraint(equalTo: bottomBar.centerYAnchor),
            ])
        }

        let okButton = NSButton(title: StorePalLocalization.string("action.ok"), target: self, action: #selector(dismiss))
        okButton.bezelStyle = .rounded
        okButton.keyEquivalent = "\r"
        okButton.translatesAutoresizingMaskIntoConstraints = false
        bottomBar.addSubview(okButton)
        window.initialFirstResponder = okButton
        NSLayoutConstraint.activate([
            okButton.trailingAnchor.constraint(equalTo: bottomBar.trailingAnchor),
            okButton.centerYAnchor.constraint(equalTo: bottomBar.centerYAnchor),
            okButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 80),
        ])

        // --- Layout ---
        let padding: CGFloat = 20
        let gap: CGFloat = 16

        NSLayoutConstraint.activate([
            iconView.topAnchor.constraint(equalTo: root.topAnchor, constant: padding),
            iconView.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: padding),
            iconView.widthAnchor.constraint(equalToConstant: 64),
            iconView.heightAnchor.constraint(equalToConstant: 64),

            headingLabel.topAnchor.constraint(equalTo: root.topAnchor, constant: padding + 4),
            headingLabel.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: gap),
            headingLabel.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -padding),

            content.topAnchor.constraint(equalTo: headingLabel.bottomAnchor, constant: 12),
            content.leadingAnchor.constraint(equalTo: headingLabel.leadingAnchor),
            content.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -padding),
            content.bottomAnchor.constraint(equalTo: bottomBar.topAnchor, constant: -8),

            bottomBar.leadingAnchor.constraint(equalTo: headingLabel.leadingAnchor),
            bottomBar.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -padding),
            bottomBar.bottomAnchor.constraint(equalTo: root.bottomAnchor, constant: -padding),
            bottomBar.heightAnchor.constraint(equalToConstant: 28),
        ])

        window.contentView = root
        return window
    }

    @objc private func dismiss() {
        window?.close()
    }

    func windowWillClose(_ notification: Notification) {
        guard notification.object as? NSWindow === window else { return }
        pageMonitor?.cancel()
        pageMonitor = nil
        window = nil
    }

    @objc private func retryLoading() { loadReleasePage() }

    private func loadReleasePage() {
        guard let container = contentContainer, let url = releaseNoteURL else { return }
        pageMonitor?.cancel()
        webView?.removeFromSuperview()
        let monitor = ReleasePageLoadMonitor()
        let injectCSS = WKUserScript(
            source: "var s=document.createElement('style');s.textContent=':root,html,body{background-color:transparent!important;overflow-x:hidden!important;margin:0!important;padding:0!important}.release-note-embed>div{padding:0!important}';document.documentElement.appendChild(s);",
            injectionTime: .atDocumentStart, forMainFrameOnly: true
        )
        let view = monitor.makeWebView(userScripts: [injectCSS])
        view.translatesAutoresizingMaskIntoConstraints = false
        view.identifier = NSUserInterfaceItemIdentifier("storepal.release.content")
        if #available(macOS 13.3, *) { view.isInspectable = false }
        view.setValue(false, forKey: "drawsBackground")
        view.underPageBackgroundColor = .clear
        container.addSubview(view, positioned: .below, relativeTo: loadingIndicator)
        NSLayoutConstraint.activate([
            view.topAnchor.constraint(equalTo: container.topAnchor),
            view.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            view.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            view.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])
        webView = view
        pageMonitor = monitor
        monitor.onStateChange = { [weak self] in self?.updateContentState($0) }
        monitor.onOpenLink = { NSWorkspace.shared.open($0) }
        updateContentState(.loading)
        monitor.load(URLRequest(url: url))
    }

    private func updateContentState(_ state: ReleasePageLoadMonitor.State) {
        webView?.alphaValue = state == .ready ? 1 : 0
        // AppKit hiding can suspend the page's async fetch/timers. Keep it running
        // transparently; the observer hides its DOM from accessibility until ready.
        webView?.setAccessibilityHidden(state != .ready)
        errorStack?.isHidden = state != .failed
        if state == .loading { loadingIndicator?.startAnimation(nil) }
        else { loadingIndicator?.stopAnimation(nil) }
    }

    @objc private func openReleaseNotes() {
        guard let url = releaseNotesURL else { return }
        NSWorkspace.shared.open(url)
    }

}

#endif
