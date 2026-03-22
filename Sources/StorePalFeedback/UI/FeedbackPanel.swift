import AppKit

/// Floating panel for the feedback UI. Uses system Liquid Glass chrome on macOS 26.
final class FeedbackPanel: NSPanel {
    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 580),
            styleMask: [.titled, .closable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: true
        )

        titlebarAppearsTransparent = true
        titleVisibility = .hidden
        isMovableByWindowBackground = true
        level = .floating
        hidesOnDeactivate = false
        becomesKeyOnlyIfNeeded = true
        isReleasedWhenClosed = false
        animationBehavior = .utilityWindow

        minSize = NSSize(width: 360, height: 480)
        maxSize = NSSize(width: 500, height: 800)

        setFrameAutosaveName("StorePalFeedback")

        if !setFrameUsingName(frameAutosaveName) {
            center()
        }
    }
}
