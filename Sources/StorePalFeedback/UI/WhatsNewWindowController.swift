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

    // MARK: - Markdown rendering (markdown → HTML → NSAttributedString)

    private static func renderMarkdown(_ markdown: String) -> NSAttributedString {
        let html = markdownToHTML(markdown)

        // Wrap in styled HTML so NSAttributedString picks up fonts/colors
        let styledHTML = """
        <html>
        <head><style>
        body {
            font-family: -apple-system, sans-serif;
            font-size: 13px;
            color: \(NSColor.labelColor.cssHex);
            line-height: 1.5;
        }
        h1 { font-size: 17px; font-weight: bold; margin: 12px 0 4px; }
        h2 { font-size: 15px; font-weight: bold; margin: 10px 0 4px; }
        h3 { font-size: 14px; font-weight: 600; margin: 8px 0 4px; }
        p { margin: 0 0 8px; }
        ul, ol { padding-left: 20px; margin: 0 0 8px; }
        li { margin: 2px 0; }
        blockquote {
            border-left: 3px solid \(NSColor.separatorColor.cssHex);
            padding-left: 10px;
            margin: 4px 0 8px 0;
            color: \(NSColor.secondaryLabelColor.cssHex);
        }
        code {
            font-family: Menlo, monospace;
            font-size: 12px;
            background: \(NSColor.quaternaryLabelColor.cssHex);
            padding: 1px 4px;
            border-radius: 3px;
        }
        pre {
            background: \(NSColor.quaternaryLabelColor.cssHex);
            padding: 8px;
            border-radius: 4px;
            overflow-x: auto;
            margin: 4px 0 8px;
        }
        pre code { background: none; padding: 0; }
        a { color: \(NSColor.controlAccentColor.cssHex); }
        del { color: \(NSColor.tertiaryLabelColor.cssHex); }
        </style></head>
        <body>\(html)</body>
        </html>
        """

        guard let data = styledHTML.data(using: .utf8),
              let attributed = NSAttributedString(
                html: data,
                options: [.characterEncoding: String.Encoding.utf8.rawValue],
                documentAttributes: nil
              ) else {
            return NSAttributedString(string: markdown, attributes: [
                .font: NSFont.systemFont(ofSize: 13),
                .foregroundColor: NSColor.labelColor,
            ])
        }

        return attributed
    }

    /// Minimal markdown → HTML converter covering common release note syntax.
    private static func markdownToHTML(_ markdown: String) -> String {
        var html = ""
        var inList = false
        var listType = ""
        var inCodeBlock = false

        for line in markdown.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Fenced code blocks
            if trimmed.hasPrefix("```") {
                if inCodeBlock {
                    html += "</code></pre>"
                    inCodeBlock = false
                } else {
                    closeList(&html, &inList, &listType)
                    html += "<pre><code>"
                    inCodeBlock = true
                }
                continue
            }
            if inCodeBlock {
                html += escapeHTML(line) + "\n"
                continue
            }

            // Close list if current line is not a list item
            let isUnorderedItem = trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ")
            let isOrderedItem = trimmed.range(of: #"^\d+\.\s"#, options: .regularExpression) != nil
            if inList && !isUnorderedItem && !isOrderedItem {
                closeList(&html, &inList, &listType)
            }

            if trimmed.isEmpty {
                if !inList { html += "<br>" }
                continue
            }

            // Headings
            if trimmed.hasPrefix("### ") {
                closeList(&html, &inList, &listType)
                html += "<h3>\(inlineFormat(String(trimmed.dropFirst(4))))</h3>"
            } else if trimmed.hasPrefix("## ") {
                closeList(&html, &inList, &listType)
                html += "<h2>\(inlineFormat(String(trimmed.dropFirst(3))))</h2>"
            } else if trimmed.hasPrefix("# ") {
                closeList(&html, &inList, &listType)
                html += "<h1>\(inlineFormat(String(trimmed.dropFirst(2))))</h1>"
            }
            // Blockquote
            else if trimmed.hasPrefix("> ") {
                closeList(&html, &inList, &listType)
                html += "<blockquote><p>\(inlineFormat(String(trimmed.dropFirst(2))))</p></blockquote>"
            }
            // Unordered list
            else if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") {
                if !inList || listType != "ul" {
                    closeList(&html, &inList, &listType)
                    html += "<ul>"
                    inList = true
                    listType = "ul"
                }
                html += "<li>\(inlineFormat(String(trimmed.dropFirst(2))))</li>"
            }
            // Ordered list
            else if let match = trimmed.range(of: #"^\d+\.\s+"#, options: .regularExpression) {
                if !inList || listType != "ol" {
                    closeList(&html, &inList, &listType)
                    html += "<ol>"
                    inList = true
                    listType = "ol"
                }
                html += "<li>\(inlineFormat(String(trimmed[match.upperBound...])))</li>"
            }
            // Horizontal rule
            else if trimmed == "---" || trimmed == "***" || trimmed == "___" {
                closeList(&html, &inList, &listType)
                html += "<hr>"
            }
            // Paragraph
            else {
                html += "<p>\(inlineFormat(trimmed))</p>"
            }
        }

        closeList(&html, &inList, &listType)
        if inCodeBlock { html += "</code></pre>" }

        return html
    }

    private static func closeList(_ html: inout String, _ inList: inout Bool, _ listType: inout String) {
        if inList {
            html += listType == "ol" ? "</ol>" : "</ul>"
            inList = false
            listType = ""
        }
    }

    /// Apply inline formatting: bold, italic, strikethrough, inline code, links, images
    private static func inlineFormat(_ text: String) -> String {
        var s = escapeHTML(text)
        // Inline code (before other formatting to avoid conflicts)
        s = s.replacingOccurrences(of: #"`(.+?)`"#, with: "<code>$1</code>", options: .regularExpression)
        // Images: ![alt](url)
        s = s.replacingOccurrences(of: #"!\[([^\]]*)\]\(([^)]+)\)"#, with: "<img src=\"$2\" alt=\"$1\" style=\"max-width:100%\">", options: .regularExpression)
        // Links: [text](url)
        s = s.replacingOccurrences(of: #"\[([^\]]+)\]\(([^)]+)\)"#, with: "<a href=\"$2\">$1</a>", options: .regularExpression)
        // Bold: **text** or __text__
        s = s.replacingOccurrences(of: #"\*\*(.+?)\*\*"#, with: "<strong>$1</strong>", options: .regularExpression)
        s = s.replacingOccurrences(of: #"__(.+?)__"#, with: "<strong>$1</strong>", options: .regularExpression)
        // Italic: *text* or _text_
        s = s.replacingOccurrences(of: #"(?<!\*)\*(?!\*)(.+?)(?<!\*)\*(?!\*)"#, with: "<em>$1</em>", options: .regularExpression)
        s = s.replacingOccurrences(of: #"(?<!_)_(?!_)(.+?)(?<!_)_(?!_)"#, with: "<em>$1</em>", options: .regularExpression)
        // Strikethrough: ~~text~~
        s = s.replacingOccurrences(of: #"~~(.+?)~~"#, with: "<del>$1</del>", options: .regularExpression)
        return s
    }

    private static func escapeHTML(_ text: String) -> String {
        text.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }
}

// MARK: - NSColor CSS helper

private extension NSColor {
    var cssHex: String {
        guard let rgb = usingColorSpace(.sRGB) else { return "#000000" }
        let r = Int(rgb.redComponent * 255)
        let g = Int(rgb.greenComponent * 255)
        let b = Int(rgb.blueComponent * 255)
        return String(format: "#%02x%02x%02x", r, g, b)
    }
}
