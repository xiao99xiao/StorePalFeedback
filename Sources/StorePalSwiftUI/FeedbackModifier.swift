import SwiftUI
import StorePalFeedback

/// View modifier that configures StorePal and optionally shows a keyboard shortcut.
///
/// ```swift
/// @main
/// struct MyApp: App {
///     var body: some Scene {
///         WindowGroup {
///             ContentView()
///                 .feedbackPanel(apiKey: "sp_live_xxx")
///         }
///     }
/// }
/// ```
struct FeedbackPanelModifier: ViewModifier {
    let apiKey: String
    let userEmail: String?
    let userName: String?

    func body(content: Content) -> some View {
        content
            .onAppear {
                StorePalFeedback.configure(
                    apiKey: apiKey,
                    userEmail: userEmail,
                    userName: userName
                )
            }
    }
}

extension View {
    /// Configures the StorePal feedback SDK on this view's appearance.
    ///
    /// - Parameters:
    ///   - apiKey: Your StorePal API key (`sp_live_` prefix).
    ///   - userEmail: Optional user email (user can fill in the form).
    ///   - userName: Optional user name (user can fill in the form).
    public func feedbackPanel(
        apiKey: String,
        userEmail: String? = nil,
        userName: String? = nil
    ) -> some View {
        modifier(FeedbackPanelModifier(apiKey: apiKey, userEmail: userEmail, userName: userName))
    }
}
