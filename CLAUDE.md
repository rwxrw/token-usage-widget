# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

- **Build & run (CLI):** `make run` — compiles with Swift Package Manager, assembles the `.app` bundle, ad-hoc signs it, and launches it. The app appears in the menu bar only (no Dock icon).
- **Stop the running app:** `make kill`
- **Clean:** `make clean` — removes `.build/` and `UsageMeter.app`
- **Xcode (alternative):** Open `UsageMeter.xcodeproj`, select the `UsageMeter` scheme, press ⌘R.
- There are no automated tests in this project.

## Architecture

**UsageMeter** is a native macOS menu bar app (no Dock icon, no windows) that tracks Claude usage via two modes:

### Tracking modes

1. **Web Mode** (`TrackingMode.web`): A hidden `WKWebView` loads `https://claude.ai` silently. JavaScript injected at `documentStart` into the **page world** monkey-patches `window.fetch` and `XMLHttpRequest` to intercept every response body, which is relayed to native code via `WKScriptMessageHandler("usageRelay")`. The handler scans all responses for usage-related JSON fields (`daily_limit`, `messages_remaining`, etc.), self-discovering the real endpoint at runtime. The same `WKWebView` instance is shared with `OnboardingView` so session cookies set during login persist and are immediately available to the interceptor.

2. **API Mode** (`TrackingMode.api`): Calls `GET /v1/organizations/{id}/usage_report/messages` with an Admin API key stored in the macOS Keychain.

### Data flow

```
AppDelegate (NSStatusItem + NSPopover)
    └── UsageTracker (@MainActor ObservableObject)
            ├── WebController (WKWebView + JS interception) ──→ usageDataSubject
            ├── APIClient (URLSession)
            └── KeychainService (Security framework)
                        ↓
                  currentUsage: UsageData?  (drives icon + popover)
```

### Key files

| File | Role |
|------|------|
| `App/AppDelegate.swift` | NSStatusItem owner; updates menu bar icon; owns NSPopover |
| `Services/WebController.swift` | WKWebView setup, JS injection script, response parsing |
| `Services/UsageTracker.swift` | Central coordinator; polling timer; snapshot persistence |
| `Drawing/MenuBarIcon.swift` | Draws the tiny 22×16pt arc gauge as NSImage (CoreGraphics) |
| `Views/PopoverView.swift` | Root 280×360 popover view |
| `Views/CircularGaugeView.swift` | Animated 270° arc gauge using custom `ArcShape` |

### Critical details

- `WKUserScript` must use `in: .page` world — without it, the patched `fetch` is isolated and can't intercept the site's own calls.
- `response.clone()` before reading the body is required — consuming the body stream without cloning would break the page.
- `NSImage.isTemplate = false` on the menu bar icon — template images are recoloured monochrome by macOS, destroying the colour-coded gauge.
- `WKWebView.websiteDataStore = .default()` persists session cookies to `~/Library/WebKit/` so the user only needs to log in once.
- `LSUIElement = YES` in `Info.plist` hides the app from the Dock and Cmd-Tab switcher.

### Entitlements

`com.apple.security.app-sandbox` + `com.apple.security.network.client` (outbound networking for WKWebView and URLSession).
