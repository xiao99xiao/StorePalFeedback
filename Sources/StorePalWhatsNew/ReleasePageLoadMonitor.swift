import Foundation
import WebKit

/// Navigation can finish before the hosted React page has fetched and rendered its note.
/// Keep the native loading UI in charge until the actual article is ready.
@MainActor
final class ReleasePageLoadMonitor: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
    enum State: Equatable { case loading, ready, failed }

    private(set) var state: State = .loading
    var onStateChange: ((State) -> Void)?
    var onOpenLink: ((URL) -> Void)?

    private weak var webView: WKWebView?
    private let timeout: Duration
    private var timeoutTask: Task<Void, Never>?
    private static let handlerName = "storepalReleasePage"

    init(timeout: Duration = .seconds(30)) {
        self.timeout = timeout
        super.init()
    }

    deinit { timeoutTask?.cancel() }

    func makeWebView(userScripts: [WKUserScript] = []) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        let messages = configuration.userContentController
        messages.add(WeakReleaseMessageHandler(self), contentWorld: .defaultClient, name: Self.handlerName)
        messages.addUserScript(WKUserScript(source: Self.observationScript, injectionTime: .atDocumentStart,
                                           forMainFrameOnly: true, in: .defaultClient))
        userScripts.forEach(messages.addUserScript)
        let view = WKWebView(frame: .zero, configuration: configuration)
        view.navigationDelegate = self
        webView = view
        return view
    }

    func load(_ request: URLRequest) {
        guard let webView else { return }
        beginLoading()
        webView.load(request)
    }

    func cancel() {
        timeoutTask?.cancel()
        timeoutTask = nil
        onStateChange = nil
        onOpenLink = nil
        webView?.navigationDelegate = nil
        webView?.configuration.userContentController.removeScriptMessageHandler(forName: Self.handlerName, contentWorld: .defaultClient)
        webView?.stopLoading()
        webView = nil
    }

    private func beginLoading() {
        timeoutTask?.cancel()
        let wasLoading = state == .loading
        state = .loading
        if !wasLoading { onStateChange?(.loading) }
        let timeout = timeout
        timeoutTask = Task { [weak self] in
            do { try await Task.sleep(for: timeout) } catch { return }
            self?.finish(.failed)
        }
    }

    private func finish(_ result: State) {
        guard state == .loading, webView != nil else { return }
        timeoutTask?.cancel()
        timeoutTask = nil
        state = result
        if result == .failed { webView?.stopLoading() }
        onStateChange?(result)
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.frameInfo.isMainFrame, message.webView === webView, let value = message.body as? String else { return }
        switch value {
        case "ready": finish(.ready)
        case "failed": finish(.failed)
        default: break
        }
    }

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        beginLoading()
    }

    // didFinish is deliberately not a readiness signal: the SPA may still be fetching content.

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: any Error) {
        handleNavigationError(error)
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: any Error) {
        handleNavigationError(error)
    }

    private func handleNavigationError(_ error: any Error) {
        let error = error as NSError
        if error.domain == NSURLErrorDomain && error.code == NSURLErrorCancelled { return }
        finish(.failed)
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) { finish(.failed) }

    func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse,
                 decisionHandler: @escaping @MainActor @Sendable (WKNavigationResponsePolicy) -> Void) {
        if navigationResponse.isForMainFrame,
           let response = navigationResponse.response as? HTTPURLResponse, response.statusCode >= 400 {
            finish(.failed)
            decisionHandler(.cancel)
        } else {
            decisionHandler(.allow)
        }
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping @MainActor @Sendable (WKNavigationActionPolicy) -> Void) {
        if navigationAction.navigationType == .linkActivated, let url = navigationAction.request.url {
            onOpenLink?(url)
            decisionHandler(.cancel)
        } else {
            decisionHandler(.allow)
        }
    }

    private static let observationScript = #"""
    (() => {
      let finished = false;
      let scheduled = false;
      let body = null;
      let originalAriaHidden = null;
      let originalVisibility = '';
      let originalVisibilityPriority = '';
      const observer = new MutationObserver(schedule);
      function report(state) {
        if (finished) return;
        finished = true;
        observer.disconnect();
        if (state === 'ready' && body) {
          if (originalAriaHidden === null) body.removeAttribute('aria-hidden');
          else body.setAttribute('aria-hidden', originalAriaHidden);
          if (originalVisibility) body.style.setProperty('visibility', originalVisibility, originalVisibilityPriority);
          else body.style.removeProperty('visibility');
        }
        window.webkit.messageHandlers.storepalReleasePage.postMessage(state);
      }
      function inspect() {
        scheduled = false;
        if (finished) return;
        // Keep the hidden webpage's loading/error controls out of assistive navigation.
        if (document.body && body !== document.body) {
          body = document.body;
          originalAriaHidden = body.getAttribute('aria-hidden');
          originalVisibility = body.style.getPropertyValue('visibility');
          originalVisibilityPriority = body.style.getPropertyPriority('visibility');
        }
        if (body?.getAttribute('aria-hidden') !== 'true') body?.setAttribute('aria-hidden', 'true');
        if (body && (body.style.getPropertyValue('visibility') !== 'hidden' || body.style.getPropertyPriority('visibility') !== 'important')) {
          body.style.setProperty('visibility', 'hidden', 'important');
        }
        const declared = document.querySelector('[data-storepal-release-state]')?.getAttribute('data-storepal-release-state');
        if (declared === 'error') { report('failed'); return; }
        if (declared === 'ready' || document.querySelector('.release-note-embed .prose')) {
          report('ready');
          return;
        }
        if (declared === 'loading' || document.readyState === 'loading') return;
        if (document.querySelector('.animate-spin, [role="progressbar"], [aria-busy="true"]')) return;
        const root = document.getElementById('root');
        if (root) {
          // Empty SPA shell: wait. A rendered non-article state is the hosted error page.
          if (root.childElementCount > 0) report('failed');
          return;
        }
        // Custom backends may serve an already-rendered HTML document without the SPA.
        if (document.body) report('ready');
      }
      function schedule() {
        if (scheduled || finished) return;
        scheduled = true;
        // WebKit can suspend animation frames while the native layer hides the page.
        // Observe completed DOM mutations without waiting for a visible web paint.
        queueMicrotask(inspect);
      }
      observer.observe(document, { subtree: true, childList: true, attributes: true });
      document.addEventListener('DOMContentLoaded', schedule, { once: true });
      schedule();
    })();
    """#
}

@MainActor
private final class WeakReleaseMessageHandler: NSObject, WKScriptMessageHandler {
    private weak var monitor: ReleasePageLoadMonitor?
    init(_ monitor: ReleasePageLoadMonitor) { self.monitor = monitor }
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        monitor?.userContentController(userContentController, didReceive: message)
    }
}
