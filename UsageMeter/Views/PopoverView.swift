import SwiftUI

struct PopoverView: View {
    @EnvironmentObject var tracker: UsageTracker
    @EnvironmentObject var settings: AppSettings
    @State private var showSettings = false
    @State private var showOnboarding = false

    var body: some View {
        VStack(spacing: 0) {
            // ── Header ────────────────────────────────────────────────
            HStack {
                Text("UsageMeter")
                    .font(.headline)
                    .foregroundStyle(.primary)
                Spacer()
                Button {
                    showSettings = true
                } label: {
                    Image(systemName: "gearshape")
                        .imageScale(.medium)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider()

            // ── Body ──────────────────────────────────────────────────
            Group {
                if tracker.needsOnboarding {
                    onboardingPrompt
                } else if let usage = tracker.currentUsage {
                    usageBody(usage: usage)
                } else {
                    emptyState
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // ── Error ─────────────────────────────────────────────────
            if let err = tracker.lastError {
                Divider()
                Text(err)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Divider()

            // ── Footer ────────────────────────────────────────────────
            HStack {
                if let fetched = tracker.currentUsage?.fetchedAt {
                    Text("Updated \(fetched, style: .relative) ago")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    tracker.refresh()
                } label: {
                    if tracker.isRefreshing {
                        ProgressView()
                            .scaleEffect(0.65)
                            .frame(width: 16, height: 16)
                    } else {
                        Image(systemName: "arrow.clockwise")
                            .imageScale(.small)
                    }
                }
                .buttonStyle(.plain)
                .disabled(tracker.isRefreshing)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .frame(width: 280, height: 360)
        .sheet(isPresented: $showSettings) {
            SettingsView()
                .environmentObject(tracker)
                .environmentObject(settings)
        }
        .sheet(isPresented: $showOnboarding) {
            OnboardingView()
                .environmentObject(tracker)
        }
    }

    // MARK: - Sub-views

    private func usageBody(usage: UsageData) -> some View {
        VStack(spacing: 14) {
            CircularGaugeView(fraction: usage.fraction, diameter: 120)
                .padding(.top, 12)

            StatsView(usage: usage)

            Spacer()
        }
    }

    private var onboardingPrompt: some View {
        VStack(spacing: 12) {
            Image(systemName: "person.crop.circle.badge.questionmark")
                .font(.system(size: 36))
                .foregroundStyle(.secondary)
            Text("Sign in to get started")
                .font(.headline)
            Text("UsageMeter needs you to log in to claude.ai once so it can track your usage.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
            Button("Sign In…") { showOnboarding = true }
                .buttonStyle(.borderedProminent)
        }
        .padding()
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            if tracker.isRefreshing {
                ProgressView("Fetching usage…")
            } else {
                Image(systemName: "gauge.medium")
                    .font(.system(size: 32))
                    .foregroundStyle(.secondary)
                Text("No data yet")
                    .foregroundStyle(.secondary)
                Button("Refresh") { tracker.refresh() }
                    .buttonStyle(.bordered)
            }
        }
        .padding()
    }
}
