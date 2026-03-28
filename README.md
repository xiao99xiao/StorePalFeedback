# StorePalFeedback

A native macOS SDK for [StorePal](https://storepal.app). Includes a floating feedback panel and a "What's New" release note prompt — built with AppKit, designed for macOS 26 Liquid Glass.

## Install

Add to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/xiao99xiao/StorePalFeedback.git", from: "1.1.0"),
]
```

Then add the targets you need:

```swift
.target(name: "MyApp", dependencies: [
    "StorePalSwiftUI",      // Feedback panel (SwiftUI)
    "StorePalWhatsNew",     // What's New prompt (optional)
]),
```

Or in Xcode: **File → Add Package Dependencies** → paste the repo URL.

## Setup

Get an API key from your [StorePal dashboard](https://storepal.app/dashboard) → Integrations tab (requires Pro plan).

### SwiftUI

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

### AppKit

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

## Feedback Panel

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
- Auto-collected system info (macOS version, app version, hardware model)

**My Conversations**
- List of past feedback with unread indicators
- Conversation threads with message bubbles
- Reply to developer responses directly

## What's New

Show release notes when your app updates to a new version. The dialog displays a server-rendered release note page in a native window.

### How It Works

1. On app launch, `StorePalWhatsNew.check()` compares the current app version (`CFBundleShortVersionString`) with the last seen version stored in UserDefaults
2. If the version changed (and it's not the first install), it fetches the release note for the current version from the StorePal API
3. If a release note exists, it shows a dialog with the app icon, an update message, and the release note content rendered via WKWebView
4. The release note content is managed in your [StorePal dashboard](https://storepal.app/dashboard) → Release Notes

### Usage

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
| `StorePalFeedback` | `import StorePalFeedback` | Core — AppKit feedback panel + API client |
| `StorePalSwiftUI` | `import StorePalSwiftUI` | SwiftUI convenience (re-exports StorePalFeedback) |
| `StorePalWhatsNew` | `import StorePalWhatsNew` | "What's New" release note prompt |

- **Zero external dependencies** — only Foundation, AppKit, WebKit, and SwiftUI
- **Swift 6 strict concurrency** — `actor` API client, `@MainActor` UI, all models `Sendable`
- **Modular** — import only what you need

## Requirements

- macOS 13+
- Swift 6.0+
- StorePal Pro plan (for API key)

## Links

- [StorePal](https://storepal.app) — Create your account and app
- [CLI & Skill Docs](https://storepal.app/docs/cli) — Terminal and AI agent integration
- [Agent Skill](https://github.com/xiao99xiao/storepal-skills) — For Claude Code, Cursor, Windsurf
