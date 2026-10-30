# Changelog

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
