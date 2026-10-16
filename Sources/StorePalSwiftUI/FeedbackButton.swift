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
    #if os(iOS)
    @State private var isPresented = false
    #endif

    public init(@ViewBuilder label: () -> Label) {
        self.label = label()
    }

    public var body: some View {
        #if os(iOS)
        Button(action: { isPresented = true }, label: { label })
            .feedbackSheet(isPresented: $isPresented)
        #else
        Button(action: { StorePalFeedback.show() }, label: { label })
        #endif
    }
}

extension FeedbackButton where Label == Text {
    /// Creates a feedback button with a text label.
    public init(_ title: String = StorePalLocalization.string("window.title")) {
        self.label = Text(title)
    }
}
