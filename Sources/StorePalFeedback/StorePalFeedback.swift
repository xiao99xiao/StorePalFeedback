import AppKit

/// Main entry point for the StorePal Feedback SDK.
///
/// Usage:
/// ```swift
/// // Configure once at launch (email and name are optional)
/// StorePalFeedback.configure(apiKey: "sp_live_xxx")
///
/// // Or with known user info
/// StorePalFeedback.configure(apiKey: "sp_live_xxx", userEmail: user.email, userName: user.name)
///
/// // Show the feedback panel
/// StorePalFeedback.show()
/// ```
@MainActor
public final class StorePalFeedback {
    public static let shared = StorePalFeedback()

    private var config: StorePalConfiguration?
    private var apiClient: APIClient?
    private var store: ConversationStore?
    private var windowController: FeedbackWindowController?
    private var whatsNewController: WhatsNewWindowController?
    private var whatsNewEnabled = false

    /// Pre-select a feedback category when the form opens.
    public static var defaultCategory: String?

    private static let lastSeenVersionKey = "com.storepal.lastSeenVersion"

    private init() {}

    // MARK: - Configure

    /// Configure the SDK with your StorePal API key.
    /// Call this once, typically in `applicationDidFinishLaunching`.
    ///
    /// - Parameters:
    ///   - apiKey: Your StorePal API key (`sp_live_` prefix).
    ///   - userEmail: Current user's email (optional — user can fill it in the form).
    ///   - userName: Current user's name (optional — user can fill it in the form).
    ///   - baseURL: Custom API base URL (default: https://storepal.app).
    /// Configure the SDK with your StorePal API key.
    /// Call this once, typically in `applicationDidFinishLaunching`.
    ///
    /// - Parameters:
    ///   - apiKey: Your StorePal API key (`sp_live_` prefix).
    ///   - userEmail: Current user's email (optional — user can fill it in the form).
    ///   - userName: Current user's name (optional — user can fill it in the form).
    ///   - whatsNew: Enable "What's New" prompt — shows release notes on version upgrade.
    ///   - baseURL: Custom API base URL (default: https://storepal.app).
    public static func configure(
        apiKey: String,
        userEmail: String? = nil,
        userName: String? = nil,
        whatsNew: Bool = false,
        baseURL: URL = URL(string: "https://storepal.app")!
    ) {
        let config = StorePalConfiguration(
            apiKey: apiKey,
            userEmail: userEmail,
            userName: userName,
            baseURL: baseURL
        )
        shared.config = config
        shared.apiClient = APIClient(configuration: config)
        shared.store = ConversationStore(apiKey: apiKey)
        shared.whatsNewEnabled = whatsNew

        if whatsNew {
            Task { @MainActor in
                await shared.checkWhatsNew()
            }
        }
    }

    // MARK: - Show / Hide

    /// Show the feedback panel. Creates the window on first call.
    public static func show() {
        shared.ensureWindow()
        shared.windowController?.showPanel()
    }

    /// Hide the feedback panel.
    public static func hide() {
        shared.windowController?.hidePanel()
    }

    /// Toggle the feedback panel visibility.
    public static func toggle() {
        shared.ensureWindow()
        shared.windowController?.togglePanel()
    }

    // MARK: - What's New

    /// Manually trigger a "What's New" check, regardless of whether the version changed.
    /// Useful for a "What's New" menu item.
    ///
    /// - Parameter version: Version to look up. Defaults to CFBundleShortVersionString.
    public static func showWhatsNew(version: String? = nil) {
        Task { @MainActor in
            await shared.showWhatsNewForVersion(version)
        }
    }

    private func checkWhatsNew() async {
        guard let apiClient else { return }

        let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
        guard !currentVersion.isEmpty else { return }

        let lastSeen = UserDefaults.standard.string(forKey: Self.lastSeenVersionKey) ?? ""

        // Save current version immediately so we don't re-prompt on next launch
        UserDefaults.standard.set(currentVersion, forKey: Self.lastSeenVersionKey)

        // Only show if version actually changed (not on first install)
        guard !lastSeen.isEmpty, currentVersion != lastSeen else { return }

        do {
            if let note = try await apiClient.getReleaseNote(version: currentVersion) {
                showWhatsNewDialog(version: note.version, content: note.content)
            }
        } catch {
            // Silently fail — what's new is a nice-to-have, not critical
        }
    }

    private func showWhatsNewForVersion(_ override: String?) async {
        guard let apiClient else {
            print("[StorePal] Not configured — call StorePalFeedback.configure() first")
            return
        }
        let version = override ?? (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "")
        guard !version.isEmpty else {
            print("[StorePal] Could not determine app version (CFBundleShortVersionString missing)")
            return
        }

        do {
            if let note = try await apiClient.getReleaseNote(version: version) {
                showWhatsNewDialog(version: note.version, content: note.content)
            } else {
                print("[StorePal] No release note found for version \(version)")
            }
        } catch {
            print("[StorePal] Failed to fetch release note: \(error)")
        }
    }

    private func showWhatsNewDialog(version: String, content: String) {
        if whatsNewController == nil {
            whatsNewController = WhatsNewWindowController()
        }
        whatsNewController?.show(version: version, content: content)
    }

    // MARK: - Private

    private func ensureWindow() {
        guard windowController == nil else { return }
        guard let apiClient, let config, let store else {
            assertionFailure("StorePalFeedback.configure() must be called before show()")
            return
        }
        windowController = FeedbackWindowController(apiClient: apiClient, config: config, store: store)
    }
}
