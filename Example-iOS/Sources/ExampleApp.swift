import SwiftUI
import StorePalSwiftUI
import StorePalWhatsNew

@main
struct ExampleApp: App {
    init() {
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("--ui-testing") {
            if arguments.contains("--reset-sdk") {
                UserDefaults.standard.removeObject(forKey: "com.storepal.lastSeenVersion")
                UserDefaults(suiteName: "com.storepal.feedback.sp_live_ui_test")?.removePersistentDomain(forName: "com.storepal.feedback.sp_live_ui_test")
            }
            if arguments.contains("--upgrade") {
                UserDefaults.standard.set("0.9.0", forKey: "com.storepal.lastSeenVersion")
            }
            let path = arguments.contains("--offline") ? "/offline" : ""
            StorePalFeedback.configure(apiKey: "sp_live_ui_test", baseURL: URL(string: "http://127.0.0.1:8766\(path)")!)
        } else {
            // Replace with your app-scoped Pro API key from Dashboard → Integrations.
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
