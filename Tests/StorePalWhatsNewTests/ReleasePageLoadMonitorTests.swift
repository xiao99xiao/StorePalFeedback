#if os(macOS)
import AppKit
import Testing
import WebKit
@testable import StorePalWhatsNew

@Suite(.serialized)
@MainActor
struct ReleasePageLoadMonitorTests {
    private func host(_ monitor: ReleasePageLoadMonitor, html: String) -> (NSWindow, WKWebView) {
        _ = NSApplication.shared
        let webView = monitor.makeWebView()
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 400, height: 200),
                              styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = webView
        window.orderFront(nil)
        webView.alphaValue = 0 // Same hidden-page rendering used beneath the native indicator.
        webView.loadHTMLString(html, baseURL: nil)
        return (window, webView)
    }

    private func wait(_ condition: () -> Bool) async throws -> Bool {
        for _ in 0..<250 {
            if condition() { return true }
            try await Task.sleep(for: .milliseconds(20))
        }
        return false
    }

    private func evaluate(_ script: String, in webView: WKWebView) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
            webView.evaluateJavaScript(script) { _, error in
                if let error { continuation.resume(throwing: error) }
                else { continuation.resume() }
            }
        }
    }

    private let shell = #"""
    <!doctype html><div id="root"><div class="animate-spin" role="progressbar">Loading</div></div>
    <script>window.finishArticle = () => document.getElementById('root').innerHTML =
    '<main class="release-note-embed"><article class="prose">The real release note</article></main>';</script>
    """#

    @Test func waitsForTheArticleAfterNavigationFinishes() async throws {
        let monitor = ReleasePageLoadMonitor()
        let (window, view) = host(monitor, html: shell)
        defer { monitor.cancel(); window.close() }
        #expect(try await wait { !view.isLoading })
        #expect(monitor.state == .loading)
        try await evaluate("window.finishArticle()", in: view)
        #expect(try await wait { monitor.state == .ready })
    }

    @Test func aRenderedHostedErrorEndsNativeLoading() async throws {
        let monitor = ReleasePageLoadMonitor()
        let (window, view) = host(monitor, html: shell)
        defer { monitor.cancel(); window.close() }
        #expect(try await wait { !view.isLoading })
        try await evaluate("document.getElementById('root').innerHTML = '<p>Release note not found.</p>'", in: view)
        #expect(try await wait { monitor.state == .failed })
    }

    @Test func theHiddenPageCanCompleteItsOwnAsyncWork() async throws {
        let monitor = ReleasePageLoadMonitor()
        let html = shell + "<script>window.addEventListener('load', () => setTimeout(window.finishArticle, 150));</script>"
        let (window, _) = host(monitor, html: html)
        defer { monitor.cancel(); window.close() }
        #expect(try await wait { monitor.state == .ready })
    }

    @Test func staticHTMLFromCustomBackendsStillLoads() async throws {
        let monitor = ReleasePageLoadMonitor()
        let (window, _) = host(monitor, html: "<!doctype html><h2>Already rendered content</h2>")
        defer { monitor.cancel(); window.close() }
        #expect(try await wait { monitor.state == .ready })
    }

    @Test func anUnfinishedPageTimesOutInsteadOfSpinningForever() async throws {
        let monitor = ReleasePageLoadMonitor(timeout: .seconds(1))
        let (window, _) = host(monitor, html: shell)
        defer { monitor.cancel(); window.close() }
        #expect(try await wait { monitor.state == .failed })
    }

    @Test func cancellationStopsPendingLoadingCallbacks() async throws {
        let monitor = ReleasePageLoadMonitor(timeout: .milliseconds(100))
        let (window, view) = host(monitor, html: shell)
        defer { window.close() }
        monitor.cancel()
        #expect(view.navigationDelegate == nil)
        try await Task.sleep(for: .milliseconds(200))
        #expect(monitor.state == .loading)
    }
}
#endif
