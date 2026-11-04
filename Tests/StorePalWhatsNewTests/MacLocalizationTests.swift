#if os(macOS)
import AppKit
import StorePalFeedback
import Testing
@testable import StorePalWhatsNew

@MainActor @Test func releaseWindowUsesLocalizedText() throws {
    let app = NSApplication.shared
    let previousWindows = Set(app.windows.map(ObjectIdentifier.init))
    let controller = WhatsNewWindowController()
    let url = try #require(URL(string: "about:blank"))
    controller.show(version: "2.4.0", releaseNoteURL: url, appName: "Demo App", releaseNotesURL: url)
    let windows = app.windows.filter { !previousWindows.contains(ObjectIdentifier($0)) }
    defer { windows.forEach { $0.close() } }
    let window = try #require(windows.first)
    #expect(window.title == StorePalLocalization.string("release.title"))

    func descendants(of view: NSView) -> [NSView] {
        [view] + view.subviews.flatMap { descendants(of: $0) }
    }
    let views = descendants(of: try #require(window.contentView))
    let labels = views.compactMap { ($0 as? NSTextField)?.stringValue }
    let buttons = views.compactMap { ($0 as? NSButton)?.title }
    #expect(labels.contains(String(format: StorePalLocalization.string("release.updated"), "Demo App", "2.4.0")))
    #expect(buttons.contains(StorePalLocalization.string("release.all")))
    #expect(buttons.contains(StorePalLocalization.string("action.ok")))
}
#endif
