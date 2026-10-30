# StorePalFeedback

A native iOS and macOS SDK for [StorePal](https://storepal.app). Includes feedback forms, file attachments, a conversation inbox, and “What's New” release note prompts. iOS uses native SwiftUI sheets with UIKit entry points; macOS keeps its AppKit floating panel and release note window.

## Install

Add to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/xiao99xiao/StorePalFeedback.git", from: "1.3.1"),
]
```

Then add the targets you need:

```swift
.target(name: "MyApp", dependencies: [
    "StorePalSwiftUI",      // Feedback controls (re-exports StorePalFeedback)
    "StorePalWhatsNew",     // What's New prompt (optional)
]),
```

Or in Xcode: **File → Add Package Dependencies** → paste the repo URL.

## Setup

Get an API key from your [StorePal dashboard](https://storepal.app/dashboard) → Integrations tab (available on Free and Pro).

### iOS · SwiftUI

Configure once before presenting either feature. Add the automatic update modifier once to the scene's root view:

```swift
import SwiftUI
import StorePalSwiftUI
import StorePalWhatsNew

@main
struct MyApp: App {
    init() {
        StorePalFeedback.configure(apiKey: "sp_live_xxx")
    }

    var body: some Scene {
        WindowGroup {
            SettingsView()
                .whatsNewOnUpdate()
        }
    }
}

struct SettingsView: View {
    @State private var showWhatsNew = false

    var body: some View {
        Form {
            FeedbackButton("Send Feedback")
            Button("What's New") { showWhatsNew = true }
        }
        .whatsNewSheet(isPresented: $showWhatsNew)
    }
}
```

For a custom feedback action, use `.feedbackSheet(isPresented: $showFeedback)` or present `StorePalFeedbackView()` in your own sheet. To show a specific release manually, use `.whatsNewSheet(isPresented: $showWhatsNew, version: "1.2.0")`.

In SDK 1.3.1 and later, for app-specific iOS support diagnostics, prepare a context locally and pass it
to `StorePalFeedbackView(context:)`. No request is made until submission:

```swift
let context = StorePalFeedbackContext(
    metadata: ["camera_model": "GR III", "camera_firmware": "2.10"],
    attachments: [.init(fileName: "diagnostics.log", data: sanitizedLogData)],
    notice: "Camera details and a diagnostic log will be sent. You can remove the log."
)
StorePalFeedbackView(context: context)
```

Prepared files use the same visible, removable attachment list and size/count
limits as user-selected files. The caller must sanitize diagnostics and explain
its data use. SDK app/device metadata remains authoritative; custom metadata
uses the remaining capacity of the server's 20-field, 500-character budget.

### iOS · UIKit

Configure once in your app's startup flow. Present from a visible controller in the correct scene:

```swift
import StorePalFeedback
import StorePalWhatsNew

// At startup:
StorePalFeedback.configure(apiKey: "sp_live_xxx")

// In viewDidAppear, after super.viewDidAppear(animated):
StorePalWhatsNew.check(from: self)

// In button actions:
StorePalFeedback.show(from: self)
StorePalWhatsNew.show(from: self)
StorePalWhatsNew.show(from: self, version: "1.2.0")
```

The presenter must be on screen with no other modal open. The `show(from:)` methods return whether presentation started. To control presentation yourself, use `StorePalFeedback.makeViewController()` or `StorePalWhatsNew.makeViewController(version:)`. iOS never chooses an arbitrary application window.

### macOS · SwiftUI

```swift
import StorePalSwiftUI
import StorePalWhatsNew

@main
struct MyApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .feedbackPanel(apiKey: "sp_live_xxx")
                .onAppear {
                    StorePalWhatsNew.check() // Show release notes on version upgrade
                }
        }
        .commands {
            FeedbackCommands(shortcut: "f", modifiers: [.command, .shift])
        }
    }
}
```

### macOS · AppKit

```swift
import StorePalFeedback
import StorePalWhatsNew

// In AppDelegate.applicationDidFinishLaunching:
StorePalFeedback.configure(apiKey: "sp_live_xxx")
StorePalWhatsNew.check()

// Open the feedback panel from a menu item or button:
@IBAction func showFeedback(_ sender: Any) {
    StorePalFeedback.show()
}
```

## Feedback

On iOS, the feedback sheet includes the form, file attachments through Files, and an inbox for reading and replying to conversations. SDK 1.3.0 reads inbox summaries using private conversation tokens saved on this device. Lists and unread checks do not mark threads seen; opening a thread does. Pagination and pull to refresh remain available. The form requires a name, email, and a message of 10–5,000 characters. Replies accept up to 5,000 characters.

On macOS, feedback opens in the existing floating panel. The following window controls and menu commands are macOS only.

### Upgrading to 1.3.0

Existing installations retain their saved conversation tokens. If the old SDK had saved an email after a successful submission, the first inbox load imports that history once while the server compatibility window remains open. Import progress survives interruption and retries; subsequent loads use token-based requests only. New installations never discover conversations from a configured or typed email. The migration temporarily uses the existing email lookup and therefore shares its known privacy risk during the compatibility phase.

After legacy lookup closes, already-held tokens still work. An old installation that upgrades only after the cutoff cannot recover email-only history automatically. Cross-device recovery requires verified identity or a privately saved support link. The SDK never falls back from a failed token lookup to email or an account credential.

On sign-out, dismiss SDK UI and call `StorePalFeedback.clearUserData()` before configuring another account. This removes saved names, email and conversation access, and prevents an in-flight import from restoring old credentials. Restore an independently held private support link with `StorePalFeedback.rememberConversation(token)`. Keep tokens private; never put an account-scoped `sp_user_` token in an app.

The new inbox requires the current StorePal API, including `POST /api/v1/conversations/lookup` (also available on the legacy Supabase base URL). Custom backends must implement that endpoint before upgrading the SDK. Server-side legacy compatibility remains enabled until a separate migration cutoff decision.

### Configure

```swift
// Minimal — user fills in name and email in the form
StorePalFeedback.configure(apiKey: "sp_live_xxx")

// With known user info — fields are pre-filled
StorePalFeedback.configure(
    apiKey: "sp_live_xxx",
    userEmail: "user@example.com",
    userName: "John"
)
```

### Show / Hide / Toggle

```swift
StorePalFeedback.show()    // Open the panel
StorePalFeedback.hide()    // Close the panel
StorePalFeedback.toggle()  // Toggle visibility
```

### SwiftUI Components

```swift
// Button that opens the feedback panel
FeedbackButton()
FeedbackButton("Report a Bug")
FeedbackButton {
    Label("Feedback", systemImage: "bubble.left")
}

// Menu bar command (Cmd+Shift+F to open feedback)
.commands {
    FeedbackCommands(shortcut: "f", modifiers: [.command, .shift])
}

// Configure on view appearance
ContentView()
    .feedbackPanel(apiKey: "sp_live_xxx", userEmail: user.email)
```

### What the Panel Includes

The floating panel has two tabs:

**Send Feedback**
- Category picker (Bug Report, Feature Request, Question, Other)
- Name and email fields
- Message text area
- File attachments (Free and Pro) — screenshots, PDFs, or `.log` files
- Auto-collected diagnostic context (OS version, app version/build, app name, locale, hardware model)

**My Conversations**
- List of past feedback with unread indicators
- Conversation threads with message bubbles
- Reply to developer responses directly

### File Attachments

On Free and Pro, users can attach files to their
feedback. The built-in panel exposes an **Attach** button next to the message
field. Limits:

- Up to 3 files per submission
- 5 MB per file, 10 MB total
- Images (PNG, JPEG, GIF, WebP), PDF, plain text, and `.log`

Attachments appear alongside each feedback item in your StorePal dashboard and
in the new-feedback email notification.

For a custom networking integration, use the [REST API documentation](https://storepal.app/native-sdk) and Dashboard → Integrations. Upload each file to `POST /api/v1/feedback/attachments`, then pass the returned IDs as `attachment_ids` to `POST /api/v1/feedback` or the conversation reply endpoint. The SDK's API client is internal.

Unbound uploads are garbage-collected after one hour, so call `submitFeedback`
(or `postReply` for an in-thread attachment) promptly after upload.

## What's New

Show release notes when your app updates to a new version. The prompt displays the hosted release note page in WKWebView: a sheet on iOS and a window on macOS. Links open outside the embedded view. iOS includes loading, retry, missing-note, and web-loading failure states.

### How It Works

1. `.whatsNewOnUpdate()` (iOS SwiftUI), `StorePalWhatsNew.check(from:)` (iOS UIKit), or `StorePalWhatsNew.check()` (macOS) compares the installed app version (`CFBundleShortVersionString`) with the last seen version in UserDefaults
2. If the version changed (and it's not the first install), it fetches the release note for the current version from the StorePal API
3. If a release note exists, it displays that exact version; the version is marked seen after presentation. Failed or missing API responses remain eligible for a later check. On iOS SwiftUI, returning to an active scene checks again
4. The release note content is managed in your [StorePal dashboard](https://storepal.app/dashboard) → Release Notes

### macOS Usage

```swift
import StorePalWhatsNew

// Auto-check on launch (call after StorePalFeedback.configure)
StorePalWhatsNew.check()

// Manually show release notes (e.g. from a "What's New" menu item)
StorePalWhatsNew.show()

// Show for a specific version
StorePalWhatsNew.show(version: "2.1.0")
```

### Prerequisites

- Create release notes in the StorePal dashboard with version numbers that match your app's `CFBundleShortVersionString` (e.g. "1.2.0")
- Call `StorePalFeedback.configure(apiKey:)` before using `StorePalWhatsNew`

## Architecture

| Target | Import | For |
|--------|--------|-----|
| `StorePalFeedback` | `import StorePalFeedback` | Core — iOS feedback sheet, UIKit presentation, AppKit panel, shared API client |
| `StorePalSwiftUI` | `import StorePalSwiftUI` | SwiftUI convenience (re-exports StorePalFeedback) |
| `StorePalWhatsNew` | `import StorePalWhatsNew` | "What's New" release note prompt |

- **Zero external dependencies** — Apple frameworks only
- **Swift 6 strict concurrency** — `actor` API client, `@MainActor` UI, all models `Sendable`
- **Modular** — import only what you need
- **Privacy manifests included** — declares app-local UserDefaults usage, support data and attachments, and no tracking. Feedback includes the diagnostic fields listed above; review these alongside your app's own data use.

## Requirements

- macOS 13+
- iOS / iPadOS 16+ (iOS support starts with SDK 1.2.0)
- Swift 6.0+
- An app-scoped StorePal API key (Free or Pro)

## Examples and validation

- `Example/`: the existing macOS Swift package example. Replace its API-key placeholder before use.
- `Example-iOS/`: iPhone/iPad example and simulator UI tests. Run `xcodegen generate --spec Example-iOS/project.yml` and open the generated project. Replace the API-key placeholder in `Sources/ExampleApp.swift` for your app.
- `swift test`: shared API request/response, metadata, and upgrade-tracking regression tests on macOS. The same package tests can run on iOS with Xcode's `StorePalFeedback-Package` scheme.
- For local UI tests, run `node Example-iOS/mock-api.mjs`, then test the generated `StorePalExample-iOS` scheme on a simulator. Test launch arguments use a local fixture and never call production. See [Example-iOS/README.md](Example-iOS/README.md).

## Links

- [StorePal](https://storepal.app) — Create your account and app
- [CLI & Skill Docs](https://storepal.app/docs/cli) — Terminal and AI agent integration
- [Agent Skill](https://github.com/xiao99xiao/storepal-skills) — For Claude Code, Cursor, Windsurf
