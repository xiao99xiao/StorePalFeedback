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
    @State private var pageState: ReleasePageLoadMonitor.State = .loading
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
                    ZStack {
                        ReleaseWebView(url: url, state: $pageState, openLink: { openURL($0) }).id(reloadID)
                            .opacity(pageState == .ready ? 1 : 0)
                            .accessibilityHidden(pageState != .ready)
                        if pageState == .loading {
                            ProgressView().progressViewStyle(.circular)
                                .accessibilityLabel(localized("release.loading"))
                                .accessibilityIdentifier("storepal.release.loading")
                        } else if pageState == .failed {
                            VStack(spacing: 16) {
                                Text(localized("release.error")).multilineTextAlignment(.center)
                                Button(localized("action.retry")) { pageState = .loading; reloadID = UUID() }
                            }
                            .padding()
                            .accessibilityIdentifier("storepal.release.error")
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
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
                        } else {
                            ProgressView().progressViewStyle(.circular)
                                .accessibilityLabel(localized("release.loading"))
                                .accessibilityIdentifier("storepal.release.loading")
                        }
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
    @Binding var state: ReleasePageLoadMonitor.State
    let openLink: (URL) -> Void

    func makeCoordinator() -> ReleasePageLoadMonitor { ReleasePageLoadMonitor() }

    func makeUIView(context: Context) -> WKWebView {
        updateCallbacks(context.coordinator)
        let fontScript = WKUserScript(
            source: "const style = document.createElement('style'); style.textContent = '.prose { font-size: \(UIFont.preferredFont(forTextStyle: .body).pointSize)px !important; }'; document.head.appendChild(style);",
            injectionTime: .atDocumentEnd, forMainFrameOnly: true
        )
        let view = context.coordinator.makeWebView(userScripts: [fontScript])
        view.isOpaque = false
        view.backgroundColor = .clear
        view.accessibilityIdentifier = "storepal.release.content"
        view.accessibilityElementsHidden = state != .ready
        view.isHidden = state != .ready
        context.coordinator.load(URLRequest(url: url))
        return view
    }

    func updateUIView(_ view: WKWebView, context: Context) {
        view.accessibilityElementsHidden = state != .ready
        view.isHidden = state != .ready
        updateCallbacks(context.coordinator)
    }

    private func updateCallbacks(_ monitor: ReleasePageLoadMonitor) {
        monitor.onStateChange = { state = $0 }
        monitor.onOpenLink = openLink
    }

    static func dismantleUIView(_ view: WKWebView, coordinator: ReleasePageLoadMonitor) {
        coordinator.cancel()
    }
}
#endif
