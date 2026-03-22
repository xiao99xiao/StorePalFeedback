import AppKit

/// Floating panel for the feedback UI.
final class FeedbackPanel: NSPanel {
    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 450),
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

        minSize = NSSize(width: 420, height: 450)
        maxSize = NSSize(width: 600, height: 800)

        setContentSize(NSSize(width: 480, height: 450))
        center()
    }

    /// Handle standard editing shortcuts (Cmd+A/C/V/X/Z) even when the host app
    /// doesn't provide them in its Edit menu.
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard event.modifierFlags.contains(.command),
              let chars = event.charactersIgnoringModifiers else {
            return super.performKeyEquivalent(with: event)
        }

        var action: Selector?
        switch chars {
        case "a": action = #selector(NSText.selectAll(_:))
        case "c": action = #selector(NSText.copy(_:))
        case "v": action = #selector(NSText.paste(_:))
        case "x": action = #selector(NSText.cut(_:))
        case "z":
            if event.modifierFlags.contains(.shift) {
                action = #selector(UndoManager.redo)
            } else {
                action = #selector(UndoManager.undo)
            }
        default: break
        }

        if let action, NSApp.sendAction(action, to: nil, from: self) {
            return true
        }

        return super.performKeyEquivalent(with: event)
    }
}
