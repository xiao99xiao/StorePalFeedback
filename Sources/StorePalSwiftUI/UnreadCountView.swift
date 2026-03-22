import SwiftUI
import StorePalFeedback

/// Displays the unread feedback count, refreshing periodically.
///
/// ```swift
/// // In a toolbar or sidebar
/// FeedbackButton {
///     Label("Feedback", systemImage: "bubble.left")
/// }
/// .overlay(alignment: .topTrailing) {
///     UnreadCountBadge()
/// }
/// ```
public struct UnreadCountBadge: View {
    @State private var count = 0

    public init() {}

    public var body: some View {
        Group {
            if count > 0 {
                Text("\(count)")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(.red, in: Capsule())
            }
        }
        .task {
            count = (try? await StorePalFeedback.unreadCount()) ?? 0
        }
    }
}
