#if os(macOS)
import AppKit
import Testing
@testable import StorePalFeedback

@MainActor @Test func feedbackPanelUsesLocalizedTitle() {
    _ = NSApplication.shared
    let panel = FeedbackPanel()
    defer { panel.close() }
    #expect(panel.title == StorePalLocalization.string("window.title"))
}
#endif
