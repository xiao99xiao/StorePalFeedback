import AppKit

/// A small blue dot indicating unread replies.
@MainActor
final class UnreadBadgeView: NSView {
    override var intrinsicContentSize: NSSize { NSSize(width: 8, height: 8) }

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.cornerRadius = 4
        layer?.backgroundColor = NSColor.systemBlue.cgColor
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }
}
