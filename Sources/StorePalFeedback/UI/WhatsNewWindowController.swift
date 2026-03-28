import AppKit

/// Displays a "What's New" dialog showing release note content for the current version.
@MainActor
final class WhatsNewWindowController {

    private var window: NSWindow?

    func show(version: String, content: String) {
        if let existing = window, existing.isVisible {
            existing.makeKeyAndOrderFront(nil)
            return
        }

        let window = makeWindow(version: version, content: content)
        self.window = window
        window.center()
        window.makeKeyAndOrderFront(nil)
    }

    private func makeWindow(version: String, content: String) -> NSWindow {
        let window = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 420),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = ""
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        window.level = .floating

        let contentView = NSView(frame: window.contentRect(forFrameRect: window.frame))

        // Title label
        let titleLabel = NSTextField(labelWithString: "What's New in \(version)")
        titleLabel.font = .systemFont(ofSize: 20, weight: .bold)
        titleLabel.textColor = .labelColor
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(titleLabel)

        // Scroll view with text
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder

        let textView = NSTextView()
        textView.isEditable = false
        textView.isSelectable = true
        textView.drawsBackground = false
        textView.textContainerInset = NSSize(width: 0, height: 0)
        textView.textContainer?.lineFragmentPadding = 0
        textView.textContainer?.widthTracksTextView = true
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false

        // Render markdown content as attributed string
        let rendered = Self.renderMarkdown(content)
        textView.textStorage?.setAttributedString(rendered)

        scrollView.documentView = textView
        contentView.addSubview(scrollView)

        // Dismiss button
        let button = NSButton(title: "OK", target: nil, action: nil)
        button.bezelStyle = .rounded
        button.keyEquivalent = "\r"
        button.translatesAutoresizingMaskIntoConstraints = false
        button.target = self
        button.action = #selector(dismiss)
        contentView.addSubview(button)

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 48),
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24),

            scrollView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 16),
            scrollView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            scrollView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24),
            scrollView.bottomAnchor.constraint(equalTo: button.topAnchor, constant: -16),

            button.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24),
            button.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20),
            button.widthAnchor.constraint(greaterThanOrEqualToConstant: 80),
        ])

        window.contentView = contentView
        return window
    }

    @objc private func dismiss() {
        window?.close()
        window = nil
    }

    // Simple markdown to attributed string — handles headers, bold, italic, lists, and paragraphs
    private static func renderMarkdown(_ markdown: String) -> NSAttributedString {
        let result = NSMutableAttributedString()
        let bodyFont = NSFont.systemFont(ofSize: 13)
        let bodyColor = NSColor.labelColor
        let defaultAttrs: [NSAttributedString.Key: Any] = [
            .font: bodyFont,
            .foregroundColor: bodyColor,
            .paragraphStyle: {
                let p = NSMutableParagraphStyle()
                p.lineSpacing = 4
                p.paragraphSpacing = 8
                return p
            }()
        ]

        for line in markdown.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.hasPrefix("### ") {
                let text = String(trimmed.dropFirst(4))
                let attrs: [NSAttributedString.Key: Any] = [
                    .font: NSFont.systemFont(ofSize: 14, weight: .semibold),
                    .foregroundColor: bodyColor,
                ]
                result.append(NSAttributedString(string: text + "\n", attributes: attrs))
            } else if trimmed.hasPrefix("## ") {
                let text = String(trimmed.dropFirst(3))
                let attrs: [NSAttributedString.Key: Any] = [
                    .font: NSFont.systemFont(ofSize: 15, weight: .bold),
                    .foregroundColor: bodyColor,
                ]
                result.append(NSAttributedString(string: text + "\n", attributes: attrs))
            } else if trimmed.hasPrefix("# ") {
                let text = String(trimmed.dropFirst(2))
                let attrs: [NSAttributedString.Key: Any] = [
                    .font: NSFont.systemFont(ofSize: 17, weight: .bold),
                    .foregroundColor: bodyColor,
                ]
                result.append(NSAttributedString(string: text + "\n", attributes: attrs))
            } else if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") {
                let text = String(trimmed.dropFirst(2))
                result.append(NSAttributedString(string: "  •  " + text + "\n", attributes: defaultAttrs))
            } else if trimmed.isEmpty {
                result.append(NSAttributedString(string: "\n", attributes: defaultAttrs))
            } else {
                result.append(NSAttributedString(string: trimmed + "\n", attributes: defaultAttrs))
            }
        }

        return result
    }
}
