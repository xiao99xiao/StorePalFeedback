import AppKit

/// Floating panel for the feedback UI.
final class FeedbackPanel: NSPanel {
    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 420),
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

        minSize = NSSize(width: 420, height: 360)
        maxSize = NSSize(width: 600, height: 600)

        setContentSize(NSSize(width: 480, height: 420))
        center()
    }
}
