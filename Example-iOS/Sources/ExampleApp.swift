import SwiftUI
import StorePalSwiftUI
import StorePalWhatsNew

@main
struct ExampleApp: App {
    init() {
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("--ui-testing") {
            let apiKey = "sp_live_ui_test"
            let suite = "com.storepal.feedback.\(apiKey.prefix(16))"
            let defaults = UserDefaults(suiteName: suite)!
            if arguments.contains("--reset-sdk") {
                UserDefaults.standard.removeObject(forKey: "com.storepal.lastSeenVersion")
                defaults.removePersistentDomain(forName: suite)
            }
            if arguments.contains("--legacy-email") {
                // State written by SDK 1.2.0, before the capability inbox migration.
                defaults.set("legacy@example.com", forKey: "storepal_user_email")
            }
            if arguments.contains("--legacy-token") {
                defaults.set("saved@example.com", forKey: "storepal_user_email")
                defaults.set(["33333333-3333-4333-8333-333333333333"], forKey: "storepal_conversation_tokens")
            }
            if arguments.contains("--upgrade") {
                UserDefaults.standard.set("0.9.0", forKey: "com.storepal.lastSeenVersion")
            }
            let path = arguments.contains("--offline") ? "/offline" : arguments.contains("--strict-server") ? "/strict" : ""
            let email = arguments.contains("--configured-email") ? "someone-else@example.com" : nil
            StorePalFeedback.configure(apiKey: apiKey, userEmail: email, baseURL: URL(string: "http://127.0.0.1:8766\(path)")!)
        } else {
            // Replace with your app-scoped API key from Dashboard → Integrations.
            StorePalFeedback.configure(apiKey: "sp_live_REPLACE_ME")
        }
    }

    var body: some Scene {
        WindowGroup { ExampleSettings().whatsNewOnUpdate() }
    }
}

private struct ExampleSettings: View {
    @State private var showFeedback = false
    @State private var showWhatsNew = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Support") {
                    FeedbackButton()
                    Button("Custom Feedback Action") { showFeedback = true }
                }
                Section("Updates") {
                    Button("What’s New") { showWhatsNew = true }
                }
            }
            .navigationTitle("StorePal iOS Example")
        }
        .feedbackSheet(isPresented: $showFeedback)
        .whatsNewSheet(isPresented: $showWhatsNew)
    }
}

/// UIKit clients present from their own controller; no global scene lookup is needed.
final class UIKitSettingsExample: UIViewController {
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        StorePalWhatsNew.check(from: self)
    }

    @IBAction func sendFeedback() { StorePalFeedback.show(from: self) }
    @IBAction func showWhatsNew() { StorePalWhatsNew.show(from: self) }
}
