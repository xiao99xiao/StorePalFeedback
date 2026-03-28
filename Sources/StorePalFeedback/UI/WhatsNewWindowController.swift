import AppKit

/// Displays a "What's New" dialog when the app updates to a new version.
///
/// Layout: horizontal — app icon on the left, content on the right.
/// Content: heading text, scrollable markdown release notes, action buttons.
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
        let window = makeWindow(appName: resolvedName, version: version, content: content, releaseNotesURL: releaseNotesURL)
        self.window = window
        window.center()
        window.makeKeyAndOrderFront(nil)
    }

    // MARK: - Build window

    private func makeWindow(appName: String, version: String, content: String, releaseNotesURL: URL?) -> NSWindow {
        let window = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 380),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "\(appName) — What's New"
        window.isMovableByWindowBackground = true
        window.backgroundColor = .windowBackgroundColor

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

        // --- Right side container ---

        // Heading: "AppName has been updated to version X.X.X"
        let headingLabel = NSTextField(wrappingLabelWithString: "\(appName) has been updated to version \(version)")
        headingLabel.font = .systemFont(ofSize: 14, weight: .semibold)
        headingLabel.textColor = .labelColor
        headingLabel.translatesAutoresizingMaskIntoConstraints = false
        headingLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        root.addSubview(headingLabel)

        // Subheading
        let subLabel = NSTextField(labelWithString: "Release notes:")
        subLabel.font = .systemFont(ofSize: 11)
        subLabel.textColor = .secondaryLabelColor
        subLabel.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(subLabel)

        // --- Scroll view with markdown ---
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
        textView.textContainerInset = NSSize(width: 8, height: 8)
        textView.textContainer?.lineFragmentPadding = 4
        textView.textContainer?.widthTracksTextView = true
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.isAutomaticLinkDetectionEnabled = true

        let rendered = Self.renderMarkdown(content)
        textView.textStorage?.setAttributedString(rendered)

        scrollView.documentView = textView
        root.addSubview(scrollView)

        // --- Bottom bar: link on left, button on right ---
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
        let iconSize: CGFloat = 64
        let padding: CGFloat = 20
        let gap: CGFloat = 16

        NSLayoutConstraint.activate([
            // Icon — top-left, fixed size
            iconView.topAnchor.constraint(equalTo: root.topAnchor, constant: padding),
            iconView.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: padding),
            iconView.widthAnchor.constraint(equalToConstant: iconSize),
            iconView.heightAnchor.constraint(equalToConstant: iconSize),

            // Heading — top-right of icon
            headingLabel.topAnchor.constraint(equalTo: root.topAnchor, constant: padding),
            headingLabel.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: gap),
            headingLabel.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -padding),

            // Subheading
            subLabel.topAnchor.constraint(equalTo: headingLabel.bottomAnchor, constant: 8),
            subLabel.leadingAnchor.constraint(equalTo: headingLabel.leadingAnchor),

            // Scroll view — fills remaining space
            scrollView.topAnchor.constraint(equalTo: subLabel.bottomAnchor, constant: 6),
            scrollView.leadingAnchor.constraint(equalTo: headingLabel.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -padding),
            scrollView.bottomAnchor.constraint(equalTo: bottomBar.topAnchor, constant: -12),

            // Bottom bar
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

    // MARK: - Markdown rendering (using AttributedString)

    private static func renderMarkdown(_ markdown: String) -> NSAttributedString {
        // macOS 13+ supports AttributedString(markdown:) natively
        do {
            var options = AttributedString.MarkdownParsingOptions()
            options.interpretedSyntax = .inlineOnlyPreservingWhitespace
            let parsed = try AttributedString(markdown: markdown, options: options)
            let mutable = NSMutableAttributedString(parsed)

            // Apply base styling
            let fullRange = NSRange(location: 0, length: mutable.length)
            mutable.addAttribute(.font, value: NSFont.systemFont(ofSize: 13), range: fullRange)
            mutable.addAttribute(.foregroundColor, value: NSColor.labelColor, range: fullRange)

            return mutable
        } catch {
            // Fallback: plain text
            return NSAttributedString(string: markdown, attributes: [
                .font: NSFont.systemFont(ofSize: 13),
                .foregroundColor: NSColor.labelColor,
            ])
        }
    }
}
