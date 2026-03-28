import AppKit
import WebKit

/// Displays a "What's New" dialog with app icon, update heading,
/// and a WKWebView loading the server-rendered release note page.
@MainActor
final class WhatsNewWindowController: NSObject, WKNavigationDelegate {

    private var window: NSWindow?
    private var releaseNotesURL: URL?

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
        window.title = "What's New"
        window.isMovableByWindowBackground = true

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
        let headingLabel = NSTextField(wrappingLabelWithString: "\(appName) has been updated to version \(version).")
        headingLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        headingLabel.textColor = .labelColor
        headingLabel.translatesAutoresizingMaskIntoConstraints = false
        headingLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        root.addSubview(headingLabel)

        // --- WebView ---
        let config = WKWebViewConfiguration()
        // Inject CSS: transparent background + disable horizontal scroll
        let injectCSS = WKUserScript(
            source: "var s=document.createElement('style');s.textContent=':root,html,body{background-color:transparent!important;overflow-x:hidden!important}';document.documentElement.appendChild(s);",
            injectionTime: .atDocumentStart,
            forMainFrameOnly: true
        )
        config.userContentController.addUserScript(injectCSS)

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.translatesAutoresizingMaskIntoConstraints = false
        webView.navigationDelegate = self
        if #available(macOS 13.3, *) { webView.isInspectable = false }
        webView.setValue(false, forKey: "drawsBackground")
        webView.underPageBackgroundColor = .clear
        webView.load(URLRequest(url: releaseNoteURL))
        root.addSubview(webView)

        // --- Bottom bar ---
        let bottomBar = NSView()
        bottomBar.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(bottomBar)

        if releaseNotesURL != nil {
            let linkButton = NSButton(title: "View all release notes", target: self, action: #selector(openReleaseNotes))
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

        let okButton = NSButton(title: "OK", target: self, action: #selector(dismiss))
        okButton.bezelStyle = .rounded
        okButton.keyEquivalent = "\r"
        okButton.translatesAutoresizingMaskIntoConstraints = false
        bottomBar.addSubview(okButton)
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

            webView.topAnchor.constraint(equalTo: headingLabel.bottomAnchor, constant: 12),
            webView.leadingAnchor.constraint(equalTo: headingLabel.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -padding),
            webView.bottomAnchor.constraint(equalTo: bottomBar.topAnchor, constant: -8),

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
        window = nil
    }

    @objc private func openReleaseNotes() {
        guard let url = releaseNotesURL else { return }
        NSWorkspace.shared.open(url)
    }

    // MARK: - WKNavigationDelegate

    // Open links in the default browser, not inside the WebView
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        if navigationAction.navigationType == .linkActivated, let url = navigationAction.request.url {
            NSWorkspace.shared.open(url)
            decisionHandler(.cancel)
        } else {
            decisionHandler(.allow)
        }
    }
}
