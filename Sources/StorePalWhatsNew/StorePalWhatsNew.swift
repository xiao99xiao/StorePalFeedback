import Foundation
import StorePalFeedback
#if os(macOS)
import AppKit
#endif

/// Release note prompts for macOS and iOS. Configure StorePalFeedback first.
@MainActor
public final class StorePalWhatsNew {
    public static let shared = StorePalWhatsNew()
    private let tracker = ReleaseVersionTracker()
    private var checking = false
    #if os(macOS)
    private var windowController: WhatsNewWindowController?
    #endif

    private init() {}

    static var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
    }

    /// Returns the installed version's note after an upgrade. First install sets a baseline.
    /// Failed or missing notes remain eligible for a later check.
    public static func releaseNoteForUpdate() async -> ReleaseNote? {
        guard !shared.checking, shared.tracker.needsPresentation(version: currentVersion) else { return nil }
        shared.checking = true
        defer { shared.checking = false }
        return await StorePalFeedback.fetchReleaseNote(version: currentVersion)
    }

    /// Records a version after its release notes have appeared.
    public static func markAsSeen(version: String) {
        shared.tracker.markPresented(version: version)
    }

    #if os(macOS)
    /// Shows the installed version's notes after an upgrade. Skips first install.
    public static func check() {
        Task {
            guard let note = await releaseNoteForUpdate(), shared.present(note) else { return }
            markAsSeen(version: note.version)
        }
    }

    /// Manually opens an exact version, or the installed version by default.
    public static func show(version: String? = nil) {
        Task {
            guard let note = await StorePalFeedback.fetchReleaseNote(version: version ?? currentVersion) else { return }
            _ = shared.present(note)
        }
    }

    private func present(_ note: ReleaseNote) -> Bool {
        guard let url = note.releaseNoteUrl.flatMap(URL.init(string:)) else { return false }
        if windowController == nil { windowController = WhatsNewWindowController() }
        let appName = note.appName
            ?? Bundle.main.infoDictionary?["CFBundleDisplayName"] as? String
            ?? Bundle.main.infoDictionary?["CFBundleName"] as? String ?? "This App"
        windowController?.show(version: note.version, releaseNoteURL: url, appName: appName,
                               releaseNotesURL: note.releasesUrl.flatMap(URL.init(string:)))
        return true
    }
    #endif
}
