import WebKit

/// Minimal WebController — retains a WKWebView only to keep the shared
/// cookie store alive (used by OnboardingView). All actual data fetching
/// is now done by ClaudeClient via URLSession.
final class WebController: NSObject, ObservableObject {
    private(set) lazy var webView: WKWebView = makeWebView()

    @Published private(set) var isLoggedIn: Bool = false

    override init() { super.init() }

    func markLoggedIn() {
        isLoggedIn = true
    }

    /// Injects the sessionKey cookie into WKWebView's persistent store.
    func setSessionCookie(_ value: String) {
        guard !value.isEmpty,
              let cookie = HTTPCookie(properties: [
                .name:           "sessionKey",
                .value:          value,
                .domain:         ".claude.ai",
                .path:           "/",
                .secure:         "TRUE",
                .sameSitePolicy: "None",
              ]) else { return }

        webView.configuration.websiteDataStore.httpCookieStore.setCookie(cookie) {
            print("[UsageMeter] sessionKey cookie injected into WKWebView store")
        }
        isLoggedIn = true
    }

    // MARK: - Private

    private func makeWebView() -> WKWebView {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()
        let wv = WKWebView(frame: .zero, configuration: config)
        wv.navigationDelegate = self
        return wv
    }
}

// MARK: - WKNavigationDelegate

extension WebController: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        print("[UsageMeter] Navigation failed: \(error.localizedDescription)")
    }
}
