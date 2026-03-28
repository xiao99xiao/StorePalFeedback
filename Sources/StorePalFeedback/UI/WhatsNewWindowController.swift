import AppKit

/// Displays a polished "What's New" dialog with app icon, version badge,
/// and full markdown-rendered release notes.
@MainActor
final class WhatsNewWindowController {

    private var window: NSWindow?

    func show(version: String, content: String, appName: String? = nil) {
        if let existing = window, existing.isVisible {
            existing.makeKeyAndOrderFront(nil)
            return
        }

        let resolvedName = appName
            ?? Bundle.main.infoDictionary?["CFBundleName"] as? String
            ?? Bundle.main.infoDictionary?["CFBundleDisplayName"] as? String
            ?? "This App"

        let window = makeWindow(appName: resolvedName, version: version, content: content)
        self.window = window
        window.center()
        window.makeKeyAndOrderFront(nil)
    }

    // MARK: - Build window

    private func makeWindow(appName: String, version: String, content: String) -> NSWindow {
        let window = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 440, height: 480),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = ""
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        window.level = .floating
        window.backgroundColor = .windowBackgroundColor

        let root = NSView()
        root.translatesAutoresizingMaskIntoConstraints = false

        // --- App icon ---
        let iconView = NSImageView()
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.imageScaling = .scaleProportionallyUpOrDown
        iconView.image = NSApp.applicationIconImage
        iconView.wantsLayer = true
        iconView.layer?.cornerRadius = 16
        iconView.layer?.masksToBounds = true
        root.addSubview(iconView)

        // --- App name ---
        let nameLabel = NSTextField(labelWithString: appName)
        nameLabel.font = .systemFont(ofSize: 18, weight: .bold)
        nameLabel.textColor = .labelColor
        nameLabel.alignment = .center
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(nameLabel)

        // --- Version badge ---
        let versionContainer = NSView()
        versionContainer.translatesAutoresizingMaskIntoConstraints = false
        versionContainer.wantsLayer = true
        versionContainer.layer?.cornerRadius = 10
        versionContainer.layer?.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.1).cgColor

        let versionLabel = NSTextField(labelWithString: "Version \(version)")
        versionLabel.font = .systemFont(ofSize: 11, weight: .medium)
        versionLabel.textColor = .controlAccentColor
        versionLabel.alignment = .center
        versionLabel.translatesAutoresizingMaskIntoConstraints = false
        versionContainer.addSubview(versionLabel)
        root.addSubview(versionContainer)

        // --- Separator ---
        let separator = NSBox()
        separator.boxType = .separator
        separator.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(separator)

        // --- Scroll view + rendered markdown ---
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.scrollerStyle = .overlay
        scrollView.autohidesScrollers = true

        let textView = NSTextView()
        textView.isEditable = false
        textView.isSelectable = true
        textView.drawsBackground = false
        textView.textContainerInset = NSSize(width: 4, height: 4)
        textView.textContainer?.lineFragmentPadding = 0
        textView.textContainer?.widthTracksTextView = true
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.isAutomaticLinkDetectionEnabled = true

        let rendered = Self.renderMarkdown(content)
        textView.textStorage?.setAttributedString(rendered)

        scrollView.documentView = textView
        root.addSubview(scrollView)

        // --- Continue button ---
        let button = NSButton(title: "Continue", target: self, action: #selector(dismiss))
        button.bezelStyle = .rounded
        button.controlSize = .large
        button.keyEquivalent = "\r"
        button.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(button)

        // --- Layout ---
        NSLayoutConstraint.activate([
            iconView.topAnchor.constraint(equalTo: root.topAnchor, constant: 40),
            iconView.centerXAnchor.constraint(equalTo: root.centerXAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 64),
            iconView.heightAnchor.constraint(equalToConstant: 64),

            nameLabel.topAnchor.constraint(equalTo: iconView.bottomAnchor, constant: 12),
            nameLabel.centerXAnchor.constraint(equalTo: root.centerXAnchor),
            nameLabel.leadingAnchor.constraint(greaterThanOrEqualTo: root.leadingAnchor, constant: 24),

            versionContainer.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 8),
            versionContainer.centerXAnchor.constraint(equalTo: root.centerXAnchor),

            versionLabel.topAnchor.constraint(equalTo: versionContainer.topAnchor, constant: 4),
            versionLabel.bottomAnchor.constraint(equalTo: versionContainer.bottomAnchor, constant: -4),
            versionLabel.leadingAnchor.constraint(equalTo: versionContainer.leadingAnchor, constant: 12),
            versionLabel.trailingAnchor.constraint(equalTo: versionContainer.trailingAnchor, constant: -12),

            separator.topAnchor.constraint(equalTo: versionContainer.bottomAnchor, constant: 16),
            separator.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 24),
            separator.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -24),

            scrollView.topAnchor.constraint(equalTo: separator.bottomAnchor, constant: 12),
            scrollView.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 28),
            scrollView.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -28),
            scrollView.bottomAnchor.constraint(equalTo: button.topAnchor, constant: -16),

            button.centerXAnchor.constraint(equalTo: root.centerXAnchor),
            button.bottomAnchor.constraint(equalTo: root.bottomAnchor, constant: -20),
            button.widthAnchor.constraint(greaterThanOrEqualToConstant: 120),
        ])

        window.contentView = root
        return window
    }

    @objc private func dismiss() {
        window?.close()
        window = nil
    }

    // MARK: - Markdown rendering

    /// Renders a markdown string to NSAttributedString with support for:
    /// headings (#, ##, ###), bold (**), italic (*), strikethrough (~~),
    /// links [text](url), unordered lists (- / *), and numbered lists (1.)
    private static func renderMarkdown(_ markdown: String) -> NSAttributedString {
        let result = NSMutableAttributedString()
        let bodyFont = NSFont.systemFont(ofSize: 13)
        let bodyColor = NSColor.labelColor
        let secondaryColor = NSColor.secondaryLabelColor

        let bodyParagraph: NSMutableParagraphStyle = {
            let p = NSMutableParagraphStyle()
            p.lineSpacing = 3
            p.paragraphSpacing = 6
            return p
        }()

        let listParagraph: NSMutableParagraphStyle = {
            let p = NSMutableParagraphStyle()
            p.lineSpacing = 2
            p.paragraphSpacing = 3
            p.headIndent = 20
            p.firstLineHeadIndent = 8
            return p
        }()

        for line in markdown.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.hasPrefix("### ") {
                let text = String(trimmed.dropFirst(4))
                let heading = applyInlineFormatting(text, baseFont: .systemFont(ofSize: 13, weight: .semibold), color: bodyColor)
                heading.addAttribute(.paragraphStyle, value: bodyParagraph, range: NSRange(location: 0, length: heading.length))
                heading.append(NSAttributedString(string: "\n"))
                result.append(heading)
            } else if trimmed.hasPrefix("## ") {
                let text = String(trimmed.dropFirst(3))
                let heading = applyInlineFormatting(text, baseFont: .systemFont(ofSize: 14, weight: .bold), color: bodyColor)
                heading.addAttribute(.paragraphStyle, value: bodyParagraph, range: NSRange(location: 0, length: heading.length))
                heading.append(NSAttributedString(string: "\n"))
                result.append(heading)
            } else if trimmed.hasPrefix("# ") {
                let text = String(trimmed.dropFirst(2))
                let heading = applyInlineFormatting(text, baseFont: .systemFont(ofSize: 16, weight: .bold), color: bodyColor)
                heading.addAttribute(.paragraphStyle, value: bodyParagraph, range: NSRange(location: 0, length: heading.length))
                heading.append(NSAttributedString(string: "\n"))
                result.append(heading)
            } else if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") {
                let text = String(trimmed.dropFirst(2))
                let bullet = NSMutableAttributedString(string: "•  ", attributes: [.font: bodyFont, .foregroundColor: secondaryColor])
                let body = applyInlineFormatting(text, baseFont: bodyFont, color: bodyColor)
                body.addAttribute(.paragraphStyle, value: listParagraph, range: NSRange(location: 0, length: body.length))
                bullet.append(body)
                bullet.append(NSAttributedString(string: "\n"))
                result.append(bullet)
            } else if let match = trimmed.range(of: #"^\d+\.\s+"#, options: .regularExpression) {
                let prefix = String(trimmed[match])
                let text = String(trimmed[match.upperBound...])
                let number = NSMutableAttributedString(string: prefix, attributes: [.font: bodyFont, .foregroundColor: secondaryColor])
                let body = applyInlineFormatting(text, baseFont: bodyFont, color: bodyColor)
                body.addAttribute(.paragraphStyle, value: listParagraph, range: NSRange(location: 0, length: body.length))
                number.append(body)
                number.append(NSAttributedString(string: "\n"))
                result.append(number)
            } else if trimmed.isEmpty {
                result.append(NSAttributedString(string: "\n", attributes: [.font: NSFont.systemFont(ofSize: 6)]))
            } else {
                let body = applyInlineFormatting(trimmed, baseFont: bodyFont, color: bodyColor)
                body.addAttribute(.paragraphStyle, value: bodyParagraph, range: NSRange(location: 0, length: body.length))
                body.append(NSAttributedString(string: "\n"))
                result.append(body)
            }
        }

        return result
    }

    /// Applies inline markdown formatting: **bold**, *italic*, ~~strikethrough~~, [links](url)
    private static func applyInlineFormatting(_ text: String, baseFont: NSFont, color: NSColor) -> NSMutableAttributedString {
        let result = NSMutableAttributedString(string: text, attributes: [.font: baseFont, .foregroundColor: color])

        // Links: [text](url)
        let linkPattern = try! NSRegularExpression(pattern: #"\[([^\]]+)\]\(([^)]+)\)"#)
        var offset = 0
        for match in linkPattern.matches(in: text, range: NSRange(location: 0, length: (text as NSString).length)) {
            let fullRange = NSRange(location: match.range.location + offset, length: match.range.length)
            let linkText = (text as NSString).substring(with: match.range(at: 1))
            let url = (text as NSString).substring(with: match.range(at: 2))

            let replacement = NSAttributedString(string: linkText, attributes: [
                .font: baseFont,
                .foregroundColor: NSColor.controlAccentColor,
                .underlineStyle: NSUnderlineStyle.single.rawValue,
                .link: URL(string: url) as Any,
            ])
            result.replaceCharacters(in: fullRange, with: replacement)
            offset += linkText.count - match.range.length
        }

        // Bold: **text**
        applyPattern(#"\*\*(.+?)\*\*"#, in: result) { range, inner in
            let bold = NSFont.systemFont(ofSize: baseFont.pointSize, weight: .semibold)
            result.replaceCharacters(in: range, with: NSAttributedString(string: inner, attributes: [.font: bold, .foregroundColor: color]))
        }

        // Italic: *text* (but not **)
        applyPattern(#"(?<!\*)\*(?!\*)(.+?)(?<!\*)\*(?!\*)"#, in: result) { range, inner in
            let italic = NSFontManager.shared.font(withFamily: baseFont.familyName ?? "System", traits: .italicFontMask, weight: 5, size: baseFont.pointSize) ?? baseFont
            result.replaceCharacters(in: range, with: NSAttributedString(string: inner, attributes: [.font: italic, .foregroundColor: color]))
        }

        // Strikethrough: ~~text~~
        applyPattern(#"~~(.+?)~~"#, in: result) { range, inner in
            result.replaceCharacters(in: range, with: NSAttributedString(string: inner, attributes: [
                .font: baseFont,
                .foregroundColor: NSColor.tertiaryLabelColor,
                .strikethroughStyle: NSUnderlineStyle.single.rawValue,
            ]))
        }

        // Inline code: `text`
        applyPattern(#"`(.+?)`"#, in: result) { range, inner in
            let mono = NSFont.monospacedSystemFont(ofSize: baseFont.pointSize - 1, weight: .regular)
            result.replaceCharacters(in: range, with: NSAttributedString(string: inner, attributes: [
                .font: mono,
                .foregroundColor: color,
                .backgroundColor: NSColor.quaternaryLabelColor,
            ]))
        }

        return result
    }

    private static func applyPattern(_ pattern: String, in attributed: NSMutableAttributedString, handler: (NSRange, String) -> Void) {
        let regex = try! NSRegularExpression(pattern: pattern)
        // Process matches in reverse order to keep ranges valid
        let matches = regex.matches(in: attributed.string, range: NSRange(location: 0, length: attributed.mutableString.length))
        for match in matches.reversed() {
            let inner = (attributed.string as NSString).substring(with: match.range(at: 1))
            handler(match.range, inner)
        }
    }
}
