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

    /// Pre-select a feedback category when the form opens.
    public static var defaultCategory: String?

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
    public static func configure(
        apiKey: String,
        userEmail: String? = nil,
        userName: String? = nil,
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

    // MARK: - Release Notes (used by StorePalWhatsNew)

    /// Fetch a release note for a specific version. Returns nil if not found.
    /// Used by `StorePalWhatsNew` — you don't typically call this directly.
    public static func fetchReleaseNote(version: String) async -> ReleaseNote? {
        guard let apiClient = shared.apiClient else {
            print("[StorePal] Not configured — call StorePalFeedback.configure() first")
            return nil
        }
        do {
            return try await apiClient.getReleaseNote(version: version)
        } catch {
            print("[StorePal] Failed to fetch release note: \(error)")
            return nil
        }
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
