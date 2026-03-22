import SwiftUI
import StorePalFeedback

/// A button that opens the StorePal feedback panel.
///
/// ```swift
/// FeedbackButton()
/// FeedbackButton("Report a Bug")
/// FeedbackButton { Image(systemName: "bubble.left") }
/// ```
public struct FeedbackButton<Label: View>: View {
    private let label: Label

    public init(@ViewBuilder label: () -> Label) {
        self.label = label()
    }

    public var body: some View {
        Button(action: { StorePalFeedback.show() }, label: { label })
    }
}

extension FeedbackButton where Label == Text {
    /// Creates a feedback button with a text label.
    public init(_ title: String = "Send Feedback") {
        self.label = Text(title)
    }
}
