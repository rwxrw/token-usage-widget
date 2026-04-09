import SwiftUI
import WebKit

struct OnboardingView: View {
    @EnvironmentObject var tracker: UsageTracker
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 8) {
                Text("Sign in to Claude")
                    .font(.title2).bold()
                Text("Log in so UsageMeter can track your usage automatically. Your session is stored locally and never sent anywhere else.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }
            .padding(.vertical, 16)

            Divider()

            WebViewRepresentable(webView: tracker.webController.webView)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider()

            HStack {
                Button("Cancel") { dismiss() }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("I'm Logged In") {
                    tracker.onboardingCompleted()
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(16)
        }
        .frame(width: 500, height: 620)
        .onAppear {
            tracker.webController.webView.load(
                URLRequest(url: URL(string: "https://claude.ai/login")!)
            )
        }
    }
}

// MARK: - NSViewRepresentable bridge

struct WebViewRepresentable: NSViewRepresentable {
    let webView: WKWebView
    func makeNSView(context: Context) -> WKWebView { webView }
    func updateNSView(_ nsView: WKWebView, context: Context) {}
}
