# Token usage meter

A native macOS menu bar app that tracks your [Claude](https://claude.ai) usage in real time — session limit, weekly limit, and extra credits.

![macOS 13+](https://img.shields.io/badge/macOS-13%2B-blue)
![Swift 5.9](https://img.shields.io/badge/Swift-5.9-orange)

## What it does

- Shows a colour-coded arc gauge in the menu bar (green → orange → red)
- Tracks your **5-hour session limit**, **7-day weekly limit**, and **extra credits**
- Polls the claude.ai API in the background using your session token
- No Dock icon, no windows — lives entirely in the menu bar

## Requirements

- macOS 13 Ventura or later
- [Xcode Command Line Tools](https://developer.apple.com/xcode/resources/) (`xcode-select --install`)
- Swift (comes with Xcode CLT)

## Build & run from source

```bash
git clone https://github.com/rwxrw/token-usage-widget.git
cd token-usage-widget
make run
```

The app will appear in your menu bar. No Xcode GUI needed.

Other make targets:

```bash
make kill    # stop the running app
make clean   # remove build artifacts
make dist    # create UsageMeter.zip to share with a friend
```

## Setup

The app needs your claude.ai session token to fetch usage data.

1. Open **claude.ai** in Safari or Chrome and log in
2. Open DevTools (`⌥⌘I`)
3. Go to **Application** → **Cookies** → `claude.ai`
4. Copy the value of **`sessionKey`**
5. Click the menu bar icon → **⚙ Settings** → paste the token → **Save Session Key**

The app will auto-discover your organisation ID and start polling immediately.

## How it works

The app calls the unofficial `GET https://claude.ai/api/organizations/{id}/usage` endpoint directly via `URLSession`, using the session cookie for auth. No browser embedding, no JS injection.

Response fields tracked:

| Field | Meaning |
|-------|---------|
| `five_hour.utilization` | % of your 5-hour session limit used |
| `seven_day.utilization` | % of your 7-day weekly limit used |
| `extra_usage.utilization` | % of extra credits used (if enabled) |

## License

MIT
