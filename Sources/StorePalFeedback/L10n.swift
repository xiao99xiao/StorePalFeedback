import Foundation

/// Shared localized SDK text, including the optional What's New target.
public enum StorePalLocalization {
    public static func string(_ key: String) -> String { L10n.string(key) }
}

/// Localized string helper using Bundle.module for Swift Package resources.
enum L10n {
    static func string(_ key: String) -> String {
        NSLocalizedString(key, bundle: .module, comment: "")
    }

    /// Keep server diagnostics available in API errors, but show SDK-owned translations in the UI.
    static func errorMessage(_ error: any Error) -> String {
        switch error {
        case StorePalError.networkError:
            string("status.network")
        case StorePalError.cooldown:
            string("conversation.cooldown")
        case StorePalError.replyLimit:
            string("conversation.reply_limit")
        case StorePalError.notConfigured:
            string("sdk.not_configured")
        case StorePalError.apiError(let detail):
            switch detail.code {
            case "RATE_LIMITED", "HTTP_429": string("status.rate_limited")
            case "UNAUTHORIZED", "INVALID_API_KEY", "INVALID_TOKEN", "HTTP_401", "HTTP_403", "FORBIDDEN":
                string("status.auth")
            case "VALIDATION_ERROR": string("status.validation")
            case "COOLDOWN": string("conversation.cooldown")
            case "REPLY_LIMIT": string("conversation.reply_limit")
            default: genericError
            }
        default:
            genericError
        }
    }

    // Window
    static var windowTitle: String { string("window.title") }

    // Form
    static var category: String { string("form.category") }
    static var name: String { string("form.name") }
    static var namePlaceholder: String { string("form.name.placeholder") }
    static var email: String { string("form.email") }
    static var emailPlaceholder: String { string("form.email.placeholder") }
    static var message: String { string("form.message") }
    static var messagePlaceholder: String { string("form.message.placeholder") }
    static var submit: String { string("form.submit") }

    // Categories
    static var categoryBug: String { string("category.bug") }
    static var categoryFeature: String { string("category.feature") }
    static var categoryQuestion: String { string("category.question") }
    static var categoryOther: String { string("category.other") }

    // Validation
    static var nameEmailRequired: String { string("validation.name_email_required") }
    static var messageTooShort: String { string("validation.message_too_short") }

    // Status
    static var genericError: String { string("status.error") }

    // Success
    static var successTitle: String { string("success.title") }
    static var successSubtitle: String { string("success.subtitle") }
    static var sendAnother: String { string("success.send_another") }
    static var close: String { string("success.close") }

    // Attachments
    static var attach: String { string("form.attach") }
    static var attachHint: String { string("form.attach.hint") }
    static var attachChoose: String { string("form.attach.choose") }
    static var attachRemove: String { string("form.attach.remove") }
    static var attachMaxFiles: String { string("form.attach.max_files") }
    static var attachTooLarge: String { string("form.attach.too_large") }
    static var attachTotalTooLarge: String { string("form.attach.total_too_large") }
    static var attachReadFailed: String { string("form.attach.read_failed") }
    static var attachUploading: String { string("form.attach.uploading") }
}
