# StorePalFeedback

A native macOS feedback SDK for [StorePal](https://storepal.app). Provides a floating feedback panel with a submission form and conversation thread UI, built with AppKit and designed for macOS 26 Liquid Glass.

## Install

Add to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/xiao99xiao/StorePalFeedback.git", from: "0.1.0"),
]
```

Then add the target you need:

```swift
// AppKit app
.target(name: "MyApp", dependencies: ["StorePalFeedback"]),

// SwiftUI app
.target(name: "MyApp", dependencies: ["StorePalSwiftUI"]),
```

Or in Xcode: **File → Add Package Dependencies** → paste the repo URL.

## Setup

Get an API key from your [StorePal dashboard](https://storepal.app/dashboard) → Integrations tab (requires Pro plan).

### AppKit

```swift
import StorePalFeedback

// In AppDelegate.applicationDidFinishLaunching:
StorePalFeedback.configure(apiKey: "sp_live_xxx")

// Open the feedback panel from a menu item or button:
@IBAction func showFeedback(_ sender: Any) {
    StorePalFeedback.show()
}
```

### SwiftUI

```swift
import StorePalSwiftUI

@main
struct MyApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .feedbackPanel(apiKey: "sp_live_xxx")
        }
        .commands {
            FeedbackCommands(shortcut: "f", modifiers: [.command, .shift])
        }
    }
}
```

## Usage

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

All parameters except `apiKey` are optional. If email and name are not provided, the user enters them in the feedback form.

### Show / Hide / Toggle

```swift
StorePalFeedback.show()    // Open the panel
StorePalFeedback.hide()    // Close the panel
StorePalFeedback.toggle()  // Toggle visibility
```

### Unread Count

Check if there are unread developer replies:

```swift
Task {
    let count = try await StorePalFeedback.unreadCount()
    // Update your badge
}
```

### SwiftUI Components

`StorePalSwiftUI` provides ready-made components:

```swift
// Button that opens the feedback panel
FeedbackButton()
FeedbackButton("Report a Bug")
FeedbackButton {
    Label("Feedback", systemImage: "bubble.left")
}

// Unread count badge overlay
FeedbackButton()
    .overlay(alignment: .topTrailing) {
        UnreadCountBadge()
    }

// Menu bar command (Cmd+Shift+F to open feedback)
.commands {
    FeedbackCommands(shortcut: "f", modifiers: [.command, .shift])
}

// Configure on view appearance
ContentView()
    .feedbackPanel(apiKey: "sp_live_xxx", userEmail: user.email)
```

## What the Panel Includes

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

## Requirements

- macOS 13+
- Swift 6.0+
- StorePal Pro plan (for API key)

## Architecture

| Target | Import | For |
|--------|--------|-----|
| `StorePalFeedback` | `import StorePalFeedback` | AppKit apps |
| `StorePalSwiftUI` | `import StorePalSwiftUI` | SwiftUI apps (re-exports StorePalFeedback) |

- **Zero dependencies** — only Foundation and AppKit/SwiftUI
- **Swift 6 strict concurrency** — `actor` API client, `@MainActor` UI, all models `Sendable`
- **Floating NSPanel** — doesn't steal focus from the main window

## Links

- [StorePal](https://storepal.app) — Create your account and app
- [CLI & Skill Docs](https://storepal.app/docs/cli) — Terminal and AI agent integration
- [Agent Skill](https://github.com/xiao99xiao/storepal-skills) — For Claude Code, Cursor, Windsurf
