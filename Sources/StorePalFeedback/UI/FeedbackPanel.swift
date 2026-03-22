import AppKit

/// Floating panel for the feedback UI. Uses system Liquid Glass chrome on macOS 26.
final class FeedbackPanel: NSPanel {
    init() {
        let size = NSRect(x: 0, y: 0, width: 420, height: 580)
        super.init(
            contentRect: size,
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )

        title = "Feedback"
        isMovableByWindowBackground = true
        level = .floating
        hidesOnDeactivate = false
        becomesKeyOnlyIfNeeded = true
        isReleasedWhenClosed = false
        animationBehavior = .utilityWindow

        minSize = NSSize(width: 380, height: 500)
        maxSize = NSSize(width: 500, height: 800)

        setContentSize(NSSize(width: 420, height: 580))
        center()
    }
}
