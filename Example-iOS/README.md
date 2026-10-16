# iOS SDK example

Requires Xcode with the iOS SDK and XcodeGen. Supports iPhone and iPad on iOS 16+.

```sh
cd Example-iOS
xcodegen generate
open StorePalExample-iOS.xcodeproj
```

For your own app, replace `sp_live_REPLACE_ME` in `Sources/ExampleApp.swift` with an app-scoped Pro API key from Dashboard → Integrations. Publish a release matching `CFBundleShortVersionString` to try What's New. Code signing is disabled in the example's simulator configuration; set up your own signing for a physical device.

The default screen demonstrates `FeedbackButton`, a custom `feedbackSheet(isPresented:)` action, automatic `whatsNewOnUpdate()`, and manual `whatsNewSheet(isPresented:)`. `UIKitSettingsExample` also compiles the UIKit APIs.

To run UI tests without a StorePal account or production requests:

```sh
node mock-api.mjs
# In another terminal:
xcodebuild -project StorePalExample-iOS.xcodeproj \
  -scheme StorePalExample-iOS \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  CODE_SIGNING_ALLOWED=NO test
```

UI tests launch with `--ui-testing`, using `sp_live_ui_test` and `http://127.0.0.1:8766`. `--reset-sdk` clears only the example's SDK state, `--upgrade` seeds a previous version, and `--offline` selects the fixture's failure response. These flags are confined to the example app.
