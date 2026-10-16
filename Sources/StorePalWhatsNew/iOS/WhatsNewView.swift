#if os(iOS)
import SwiftUI
import StorePalFeedback
import WebKit

private func localized(_ key: String) -> String { StorePalLocalization.string(key) }

/// Displays an already loaded release note in a native iOS sheet.
public struct StorePalWhatsNewView: View {
    public let note: ReleaseNote
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var webError = false
    @State private var reloadID = UUID()

    public init(note: ReleaseNote) { self.note = note }

    public var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    if let name = note.appName { Text(name).font(.title2.bold()) }
                    Text(note.version).font(.subheadline).foregroundStyle(.secondary)
                }
                .padding(.horizontal)
                if let url = note.releaseNoteUrl.flatMap(URL.init(string:)), ["https", "http"].contains(url.scheme) {
                    if webError {
                        VStack(spacing: 16) {
                            Text(localized("release.error")).multilineTextAlignment(.center)
                            Button(localized("action.retry")) { webError = false; reloadID = UUID() }
                        }
                        .padding().frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        ReleaseWebView(url: url, failed: $webError, openLink: { openURL($0) }).id(reloadID)
                    }
                } else {
                    ScrollView {
                        Text(.init(note.content)).textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading).padding()
                    }
                }
                if let url = note.releasesUrl.flatMap(URL.init(string:)), ["https", "http"].contains(url.scheme) {
                    Link(localized("release.all"), destination: url).padding(.horizontal).padding(.bottom)
                }
            }
            .navigationTitle(localized("release.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(localized("success.close")) { dismiss() }
                }
            }
        }
    }
}

/// Loads an exact version for a manual presentation; failures offer an explicit retry.
struct WhatsNewLoaderView: View {
    let version: String
    @Environment(\.dismiss) private var dismiss
    @State private var note: ReleaseNote?
    @State private var error: String?
    @State private var retry = 0

    var body: some View {
        VStack {
            if let note {
                StorePalWhatsNewView(note: note)
            } else {
                NavigationStack {
                    VStack(spacing: 16) {
                        if let error {
                            Text(error).multilineTextAlignment(.center)
                            Button(localized("action.retry")) { retry += 1 }
                        } else { ProgressView() }
                    }
                    .padding()
                    .navigationTitle(localized("release.title"))
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button(localized("success.close")) { dismiss() }
                        }
                    }
                }
            }
        }
        .task(id: retry) {
            error = nil
            do {
                let result = try await StorePalFeedback.loadReleaseNote(version: version)
                try Task.checkCancellation()
                if let result { note = result } else { error = localized("release.missing") }
            } catch is CancellationError {
            } catch { self.error = localized("release.error") }
        }
    }
}

private struct ReleaseWebView: UIViewRepresentable {
    let url: URL
    @Binding var failed: Bool
    let openLink: (URL) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(owner: self) }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.userContentController.addUserScript(WKUserScript(
            source: "const style = document.createElement('style'); style.textContent = '.prose { font-size: \(UIFont.preferredFont(forTextStyle: .body).pointSize)px !important; }'; document.head.appendChild(style);",
            injectionTime: .atDocumentEnd, forMainFrameOnly: true
        ))
        let view = WKWebView(frame: .zero, configuration: configuration)
        view.isOpaque = false
        view.backgroundColor = .clear
        view.navigationDelegate = context.coordinator
        view.load(URLRequest(url: url))
        return view
    }

    func updateUIView(_ view: WKWebView, context: Context) { context.coordinator.owner = self }

    static func dismantleUIView(_ view: WKWebView, coordinator: Coordinator) {
        view.stopLoading()
        view.navigationDelegate = nil
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        var owner: ReleaseWebView
        init(owner: ReleaseWebView) { self.owner = owner }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: any Error) {
            if (error as NSError).code != NSURLErrorCancelled { owner.failed = true }
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: any Error) {
            if (error as NSError).code != NSURLErrorCancelled { owner.failed = true }
        }

        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                     decisionHandler: @escaping @MainActor @Sendable (WKNavigationActionPolicy) -> Void) {
            if navigationAction.navigationType == .linkActivated, let url = navigationAction.request.url {
                owner.openLink(url)
                decisionHandler(.cancel)
            } else { decisionHandler(.allow) }
        }
    }
}
#endif
