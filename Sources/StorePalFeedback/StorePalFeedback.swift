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

    // MARK: - Unread Count

    /// Get the number of unread conversation replies.
    /// Uses the email from `configure()` if provided, or pass one explicitly.
    public static func unreadCount(email: String? = nil) async throws -> Int {
        guard let client = shared.apiClient else { throw StorePalError.notConfigured }
        guard let resolvedEmail = email ?? shared.config?.userEmail else {
            return 0 // No email known, can't check unread
        }
        return try await client.getUnreadCount(email: resolvedEmail)
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
