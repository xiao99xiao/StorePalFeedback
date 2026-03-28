import AppKit
import StorePalFeedback

/// "What's New" release note prompt — shows release notes when the app updates.
///
/// Usage:
/// ```swift
/// // In applicationDidFinishLaunching or .onAppear:
/// StorePalWhatsNew.check()
///
/// // Or manually (e.g. from a menu item):
/// StorePalWhatsNew.show(version: "1.2.0")
/// ```
///
/// Requires `StorePalFeedback.configure(apiKey:)` to be called first.
@MainActor
public final class StorePalWhatsNew {
    public static let shared = StorePalWhatsNew()

    private var windowController: WhatsNewWindowController?

    private static let lastSeenVersionKey = "com.storepal.lastSeenVersion"

    private init() {}

    // MARK: - Public API

    /// Check if the app version changed since last launch and show release notes if available.
    /// Call this once after `StorePalFeedback.configure()`, e.g. in `applicationDidFinishLaunching`.
    ///
    /// Does nothing on first install (no previous version to compare against).
    public static func check() {
        Task { @MainActor in
            await shared.performCheck()
        }
    }

    /// Manually show release notes for a specific version.
    /// Useful for a "What's New" menu item or testing.
    ///
    /// - Parameter version: Version to look up. Defaults to CFBundleShortVersionString.
    public static func show(version: String? = nil) {
        Task { @MainActor in
            await shared.fetchAndShow(version: version)
        }
    }

    // MARK: - Internal

    private func performCheck() async {
        let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
        guard !currentVersion.isEmpty else { return }

        let lastSeen = UserDefaults.standard.string(forKey: Self.lastSeenVersionKey) ?? ""
        UserDefaults.standard.set(currentVersion, forKey: Self.lastSeenVersionKey)

        // Don't show on first install
        guard !lastSeen.isEmpty, currentVersion != lastSeen else { return }

        await fetchAndShow(version: currentVersion)
    }

    private func fetchAndShow(version: String?) async {
        let v = version ?? (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "")
        guard !v.isEmpty else {
            print("[StorePal] Could not determine app version")
            return
        }

        guard let note = await StorePalFeedback.fetchReleaseNote(version: v) else {
            print("[StorePal] No release note found for version \(v)")
            return
        }

        guard let embedUrlString = note.releaseNoteUrl, let embedURL = URL(string: embedUrlString) else {
            print("[StorePal] No release note URL available for version \(v)")
            return
        }

        let appName = note.appName
            ?? Bundle.main.infoDictionary?["CFBundleDisplayName"] as? String
            ?? Bundle.main.infoDictionary?["CFBundleName"] as? String
            ?? "This App"

        if windowController == nil {
            windowController = WhatsNewWindowController()
        }
        let releasesURL = note.releasesUrl.flatMap { URL(string: $0) }
        windowController?.show(
            version: note.version,
            releaseNoteURL: embedURL,
            appName: appName,
            releaseNotesURL: releasesURL
        )
    }
}
