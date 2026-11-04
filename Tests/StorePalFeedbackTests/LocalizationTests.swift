import Foundation
import Testing
@testable import StorePalFeedback

@Test func allNineCompiledTranslationsHaveMatchingKeysAndFormatArguments() throws {
    let bundle = Bundle.module
    let languages = bundle.localizations.filter { $0 != "Base" }
    #expect(Set(languages.map { $0.lowercased() }) == ["en", "zh-hans", "zh-hant", "ja", "ko", "de", "fr", "es", "pt-br"])
    func strings(_ language: String) throws -> [String: String] {
        let directory = try #require(bundle.url(forResource: language, withExtension: "lproj"))
        let data = try Data(contentsOf: directory.appendingPathComponent("Localizable.strings"))
        return try #require(PropertyListSerialization.propertyList(from: data, format: nil) as? [String: String])
    }
    let english = try strings("en")
    let pattern = try NSRegularExpression(pattern: #"%(?:\d+\$)?[@df]"#)
    func placeholders(_ value: String) -> [String] {
        let text = value as NSString
        return pattern.matches(in: value, range: NSRange(location: 0, length: text.length))
            .map { text.substring(with: $0.range) }.sorted()
    }
    for language in languages {
        let translated = try strings(language)
        #expect(Set(translated.keys) == Set(english.keys), "Incomplete translation: \(language)")
        for (key, value) in translated {
            #expect(!value.isEmpty, "Empty translation: \(language)/\(key)")
            #expect(placeholders(value) == placeholders(english[key] ?? ""), "Invalid format arguments: \(language)/\(key)")
        }
    }
    let traditional = try strings(languages.first { $0.lowercased() == "zh-hant" } ?? "zh-Hant")
    #expect(traditional["window.title"] == "傳送回饋")
    #expect(traditional["success.close"] == "關閉")
}

@Test(arguments: [
    ("RATE_LIMITED", "status.rate_limited"),
    ("HTTP_429", "status.rate_limited"),
    ("UNAUTHORIZED", "status.auth"),
    ("INVALID_API_KEY", "status.auth"),
    ("VALIDATION_ERROR", "status.validation"),
    ("COOLDOWN", "conversation.cooldown"),
    ("REPLY_LIMIT", "conversation.reply_limit"),
    ("UNKNOWN_SERVER_ERROR", "status.error"),
])
func serverDiagnosticsDoNotReplaceLocalizedUI(code: String, key: String) {
    let diagnostic = "English server diagnostic that must not appear in localized SDK UI."
    let error = StorePalError.apiError(StorePalAPIError(code: code, message: diagnostic))
    #expect(L10n.errorMessage(error) == L10n.string(key))
    #expect(L10n.errorMessage(error) != diagnostic)
    if case .apiError(let detail) = error { #expect(detail.message == diagnostic) }
}

@Test func networkErrorsUseLocalizedSDKGuidance() {
    #expect(L10n.errorMessage(StorePalError.networkError(URLError(.notConnectedToInternet))) == L10n.string("status.network"))
}
