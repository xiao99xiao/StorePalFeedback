import SwiftUI
import StorePalFeedback

/// Menu bar commands for showing the feedback panel.
///
/// ```swift
/// @main
/// struct MyApp: App {
///     var body: some Scene {
///         WindowGroup {
///             ContentView()
///         }
///         .commands { FeedbackCommands() }
///     }
/// }
/// ```
public struct FeedbackCommands: Commands {
    private let title: String
    private let shortcut: KeyEquivalent?
    private let modifiers: EventModifiers

    /// Creates feedback menu commands.
    ///
    /// - Parameters:
    ///   - title: Menu item title (default: "Send Feedback...").
    ///   - shortcut: Keyboard shortcut key (default: none).
    ///   - modifiers: Keyboard shortcut modifiers.
    public init(
        title: String = "Send Feedback...",
        shortcut: KeyEquivalent? = nil,
        modifiers: EventModifiers = .command
    ) {
        self.title = title
        self.shortcut = shortcut
        self.modifiers = modifiers
    }

    public var body: some Commands {
        CommandGroup(after: .help) {
            if let shortcut {
                Button(title) { StorePalFeedback.show() }
                    .keyboardShortcut(shortcut, modifiers: modifiers)
            } else {
                Button(title) { StorePalFeedback.show() }
            }
        }
    }
}
