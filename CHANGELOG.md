# Changelog

## 1.3.2 — 2026-11-04

- Add complete Traditional Chinese (`zh-Hant`) translations across macOS and iOS, bringing the SDK to nine interface languages.
- Localize macOS What's New window titles, update headings, action buttons, fallback app names, and the default feedback menu command in all nine SDK languages.
- Use the localized feedback title when creating the macOS panel.
- Localize network and API error messages in macOS and iOS instead of exposing English server diagnostics in the built-in UI.
- Request release notes in the host app's selected language so content and native UI agree when the system prefers a language the host does not support.
- Add compiled translation, error-message, macOS window, and iOS localization regressions; declare the iOS example's supported languages.

## 1.3.1 — 2026-10-31

- Add opt-in `StorePalFeedbackContext` metadata and prepared attachments to the native iOS draft.
- Show prepared logs in the normal removable attachment list; upload only on explicit submission.
- Preserve SDK environment fields and the API's metadata/attachment limits.
- Add isolated upload/binding, removal/reset and metadata-budget regressions.

## 1.2.0 — 2026-10-16

- Support iOS / iPadOS 16+ alongside macOS 13+ in all three package products.
- Add native iOS feedback forms, file attachments, conversation history, unread indicators, and replies.
- Add SwiftUI feedback buttons and sheet modifiers, plus UIKit presentation from an explicit view controller.
- Add automatic and manual What's New sheets with exact-version lookup, loading and retry states, and external links.
- Preserve macOS entry points, panels, and menu commands.
- Record upgrades after presentation so a failed API request does not consume an update prompt.
- Send the preferred language with release lookups and correctly encode version and email query values.
- Include an iPhone/iPad example, local API fixtures, and API, upgrade, and UI regression coverage.
- Bundle privacy manifests for feedback data and app-local UserDefaults usage.
