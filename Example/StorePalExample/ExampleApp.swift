import SwiftUI
import StorePalSwiftUI

@main
struct ExampleApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .feedbackPanel(apiKey: "sp_live_YOUR_KEY_HERE")
                .frame(minWidth: 400, minHeight: 300)
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

            HStack {
                Text("Unread replies:")
                UnreadCountBadge()
            }
        }
        .padding(40)
    }
}
