#if os(iOS)
import SwiftUI
import StorePalFeedback

extension View {
    /// Presents the native iOS feedback form. Call StorePalFeedback.configure(apiKey:) first.
    public func feedbackSheet(isPresented: Binding<Bool>) -> some View {
        sheet(isPresented: isPresented) { StorePalFeedbackView() }
    }
}
#endif
