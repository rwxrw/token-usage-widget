import WebKit
import Combine

// JavaScript injected into every page at document-start, in the PAGE world.
// It monkey-patches fetch + XHR so every response body is relayed to native code.
private let kInterceptScript = """
(function() {
    if (window.__usageMeterInstalled) return;
    window.__usageMeterInstalled = true;

    // ── Patch fetch ──────────────────────────────────────────────────────
    const _origFetch = window.fetch;
    window.fetch = async function(...args) {
        const response = await _origFetch.apply(this, args);
        try {
            const clone = response.clone();
            const text  = await clone.text();
            const url   = (typeof args[0] === 'string') ? args[0]
                        : (args[0] instanceof Request)  ? args[0].url
                        : String(args[0]);
            window.webkit.messageHandlers.usageRelay.postMessage({ url, body: text });
        } catch(_) {}
        return response;
    };

    // ── Patch XMLHttpRequest ─────────────────────────────────────────────
    const _origOpen = XMLHttpRequest.prototype.open;
    XMLHttpRequest.prototype.open = function(method, url, ...rest) {
        this._relayURL = url;
        return _origOpen.apply(this, [method, url, ...rest]);
    };
    const _origSend = XMLHttpRequest.prototype.send;
    XMLHttpRequest.prototype.send = function(body) {
        this.addEventListener('load', function() {
            try {
                window.webkit.messageHandlers.usageRelay.postMessage({
                    url: this._relayURL || '',
                    body: this.responseText
                });
            } catch(_) {}
        });
        return _origSend.apply(this, [body]);
    };

    console.log('[UsageMeter] interceptor installed');
})();
"""

// Field names we're hunting for across all intercepted response bodies.
private let kUsageFields: Set<String> = [
    "daily_limit", "messages_remaining", "messages_used",
    "message_limit", "usage_limit", "reset_at", "resets_at",
    "rate_limit", "quota", "credits_remaining", "limits"
]

final class WebController: NSObject, ObservableObject {
    private(set) lazy var webView: WKWebView = makeWebView()

    let usageDataSubject = PassthroughSubject<UsageData, Never>()

    @Published private(set) var isLoggedIn: Bool = false

    override init() { super.init() }

    func fetchLatestUsage() {
        guard let url = URL(string: "https://claude.ai") else { return }
        // Only load if not already loading the same URL to avoid interrupting login
        if webView.url?.host != "claude.ai" || webView.isLoading == false {
            webView.load(URLRequest(url: url))
        }
    }

    func markLoggedIn() {
        isLoggedIn = true
    }

    // MARK: - Private

    private func makeWebView() -> WKWebView {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()

        let controller = config.userContentController
        controller.add(self, name: "usageRelay")

        // .page world = same JS context as the site (required to intercept its fetch)
        let script = WKUserScript(
            source: kInterceptScript,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: false,
            in: .page
        )
        controller.addUserScript(script)

        let wv = WKWebView(frame: .zero, configuration: config)
        wv.navigationDelegate = self
        // Do NOT set a custom user agent — use WebKit's real Safari UA
        return wv
    }
}

// MARK: - WKScriptMessageHandler

extension WebController: WKScriptMessageHandler {
    func userContentController(
        _ userContentController: WKUserContentController,
        didReceive message: WKScriptMessage
    ) {
        guard message.name == "usageRelay",
              let dict = message.body as? [String: Any],
              let body = dict["body"] as? String,
              let url  = dict["url"]  as? String
        else { return }

        // Fast pre-filter: skip if not JSON or no usage keywords
        let trimmed = body.trimmingCharacters(in: .whitespaces)
        guard trimmed.first == "{" || trimmed.first == "[" else { return }
        guard kUsageFields.contains(where: { body.contains($0) }) else { return }

        DispatchQueue.global(qos: .utility).async { [weak self] in
            self?.parsePayload(body, fromURL: url)
        }
    }

    private func parsePayload(_ json: String, fromURL url: String) {
        guard let data = json.data(using: .utf8),
              let root = try? JSONSerialization.jsonObject(with: data)
        else { return }

        // Flatten the entire JSON tree into a [String: Any] with dotted keys
        var flat = [String: Any]()
        func flatten(_ obj: Any, prefix: String) {
            if let dict = obj as? [String: Any] {
                for (k, v) in dict {
                    let key = prefix.isEmpty ? k : "\(prefix).\(k)"
                    flatten(v, prefix: key)
                    flat[key] = v   // keep non-leaf entries too for direct matches
                }
            } else if let arr = obj as? [Any] {
                for (i, v) in arr.enumerated() {
                    flatten(v, prefix: prefix.isEmpty ? "\(i)" : "\(prefix).\(i)")
                }
            } else {
                flat[prefix] = obj
            }
        }
        flatten(root, prefix: "")

        var usage = UsageData(fetchedAt: Date(), source: .webInterception)

        usage.messagesUsed  = intVal(flat, keys: ["messages_used", "daily_used", "used"])
        usage.messagesLimit = intVal(flat, keys: ["daily_limit", "message_limit", "messages_limit", "quota", "usage_limit", "rate_limit"])

        // If we got "remaining" but not "used", derive used from limit - remaining
        if let remaining = intVal(flat, keys: ["messages_remaining", "remaining"]),
           let limit = usage.messagesLimit, usage.messagesUsed == nil {
            usage.messagesUsed = max(0, limit - remaining)
        }

        if let resetStr = strVal(flat, keys: ["reset_at", "resets_at", "reset_time"]) {
            usage.resetAt = ISO8601DateFormatter().date(from: resetStr)
        }

        guard usage.messagesUsed != nil || usage.messagesLimit != nil else { return }

        print("[UsageMeter] Found usage data from \(url): used=\(usage.messagesUsed as Any) limit=\(usage.messagesLimit as Any)")

        DispatchQueue.main.async { [weak self] in
            self?.usageDataSubject.send(usage)
        }
    }

    private func intVal(_ flat: [String: Any], keys: [String]) -> Int? {
        for k in keys {
            // exact key match
            if let v = flat[k] { return toInt(v) }
            // suffix match (dotted path ends with .key)
            if let pair = flat.first(where: { $0.key.hasSuffix(".\(k)") || $0.key == k }) {
                if let i = toInt(pair.value) { return i }
            }
        }
        return nil
    }

    private func strVal(_ flat: [String: Any], keys: [String]) -> String? {
        for k in keys {
            if let v = flat[k] as? String { return v }
            if let pair = flat.first(where: { $0.key.hasSuffix(".\(k)") }),
               let s = pair.value as? String { return s }
        }
        return nil
    }

    private func toInt(_ v: Any) -> Int? {
        if let i = v as? Int    { return i }
        if let d = v as? Double { return Int(d) }
        if let s = v as? String { return Int(s) }
        return nil
    }
}

// MARK: - WKNavigationDelegate

extension WebController: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        // Scan for server-side-rendered JSON blobs (Next.js __NEXT_DATA__, etc.)
        let domScan = """
        (function() {
            const selectors = [
                'script[type="application/json"]',
                'script#__NEXT_DATA__',
                'script#__NUXT_DATA__'
            ];
            selectors.forEach(sel => {
                document.querySelectorAll(sel).forEach(s => {
                    window.webkit.messageHandlers.usageRelay.postMessage({
                        url: window.location.href + '#dom',
                        body: s.textContent
                    });
                });
            });
        })();
        """
        webView.evaluateJavaScript(domScan)

        // Detect login state by checking for a user-menu element
        webView.evaluateJavaScript(
            "!!(document.querySelector('[data-testid=\"user-menu\"]') || document.querySelector('[data-userid]'))"
        ) { [weak self] result, _ in
            if let loggedIn = result as? Bool, loggedIn {
                DispatchQueue.main.async { self?.isLoggedIn = true }
            }
        }
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        // Navigation failure — UsageTracker will surface last cached data
    }
}
