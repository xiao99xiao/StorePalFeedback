import AppKit
import MarkdownKit

/// Displays a "What's New" dialog with app icon, update message,
/// and release notes rendered via MarkdownKit.
@MainActor
final class WhatsNewWindowController {

    private var window: NSWindow?
    private var releaseNotesURL: URL?

    func show(version: String, content: String, appName: String? = nil, releaseNotesURL: URL? = nil) {
        if let existing = window, existing.isVisible {
            existing.makeKeyAndOrderFront(nil)
            return
        }

        let resolvedName = appName
            ?? Bundle.main.infoDictionary?["CFBundleDisplayName"] as? String
            ?? Bundle.main.infoDictionary?["CFBundleName"] as? String
            ?? "This App"

        self.releaseNotesURL = releaseNotesURL
        let window = makeWindow(appName: resolvedName, version: version, content: content)
        self.window = window
        window.center()
        window.makeKeyAndOrderFront(nil)
    }

    // MARK: - Build window

    private func makeWindow(appName: String, version: String, content: String) -> NSWindow {
        let window = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 400),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "\(appName) — What's New"
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
        let headingLabel = NSTextField(wrappingLabelWithString: "\(appName) has been updated to version \(version)")
        headingLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        headingLabel.textColor = .labelColor
        headingLabel.translatesAutoresizingMaskIntoConstraints = false
        headingLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        root.addSubview(headingLabel)

        // --- Scroll view with rendered markdown ---
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.drawsBackground = true
        scrollView.backgroundColor = .textBackgroundColor
        scrollView.borderType = .bezelBorder
        scrollView.scrollerStyle = .overlay
        scrollView.autohidesScrollers = true

        let textView = NSTextView()
        textView.isEditable = false
        textView.isSelectable = true
        textView.drawsBackground = false
        textView.textContainerInset = NSSize(width: 10, height: 10)
        textView.textContainer?.lineFragmentPadding = 4
        textView.textContainer?.widthTracksTextView = true
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.isAutomaticLinkDetectionEnabled = true

        let rendered = Self.renderMarkdown(content)
        textView.textStorage?.setAttributedString(rendered)

        scrollView.documentView = textView
        root.addSubview(scrollView)

        // --- Bottom bar ---
        let bottomBar = NSView()
        bottomBar.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(bottomBar)

        // "View all release notes" link (left)
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

        // "OK" button (right)
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

            scrollView.topAnchor.constraint(equalTo: headingLabel.bottomAnchor, constant: 12),
            scrollView.leadingAnchor.constraint(equalTo: headingLabel.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -padding),
            scrollView.bottomAnchor.constraint(equalTo: bottomBar.topAnchor, constant: -12),

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

    // MARK: - Markdown rendering via MarkdownKit

    private static func renderMarkdown(_ markdown: String) -> NSAttributedString {
        let doc = MarkdownParser.standard.parse(markdown)
        let labelHex = NSColor.labelColor.hexString
        let generator = AttributedStringGenerator(
            fontSize: 13,
            fontFamily: "-apple-system, Helvetica, Arial, sans-serif",
            fontColor: labelHex,
            h1Color: labelHex,
            h2Color: labelHex,
            h3Color: labelHex
        )
        return generator.generate(doc: doc) ?? NSAttributedString(string: markdown)
    }
}

private extension NSColor {
    var hexString: String {
        guard let rgb = usingColorSpace(.sRGB) else { return "#000000" }
        return String(format: "#%02x%02x%02x",
                      Int(rgb.redComponent * 255),
                      Int(rgb.greenComponent * 255),
                      Int(rgb.blueComponent * 255))
    }
}
