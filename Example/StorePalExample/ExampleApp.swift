import SwiftUI
import StorePalFeedback
import StorePalSwiftUI

@main
struct ExampleApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .feedbackPanel(apiKey: "sp_live_YOUR_KEY_HERE", whatsNew: true)
                .frame(minWidth: 400, minHeight: 350)
        }
        .commands {
            FeedbackCommands(shortcut: "f", modifiers: [.command, .shift])
        }
    }
}

struct ContentView: View {
    var body: some View {
        VStack(spacing: 20) {
            Text("StorePal SDK Example")
                .font(.title)

            Text("Press Cmd+Shift+F or click the button below to open the feedback panel.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            FeedbackButton()
                .controlSize(.large)

            FeedbackButton {
                Label("Report a Bug", systemImage: "ladybug")
            }

            Divider()
                .padding(.vertical, 4)

            Button("Show What's New") {
                StorePalFeedback.showWhatsNew()
            }
            .controlSize(.large)

            Text("Triggers a release note check for the current app version.")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(40)
    }
}
