import SwiftUI

struct StatsView: View {
    let usage: UsageData

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if usage.source == .claudeWebAPI {
                // Real API data — show session / weekly / extra credit rows
                if let pct = usage.sessionUtilization {
                    row(label: "Session", value: String(format: "%.0f%% used (5h)", pct))
                }
                if let reset = usage.sessionResetsAt {
                    resetRow(label: "↺ Session", date: reset)
                }

                if let pct = usage.weeklyUtilization {
                    row(label: "Weekly", value: String(format: "%.0f%% used (7d)", pct))
                }
                if let reset = usage.weeklyResetsAt {
                    resetRow(label: "↺ Weekly", date: reset)
                }

                if usage.extraCreditsEnabled, let pct = usage.extraCreditsUtilization {
                    row(label: "Extra", value: String(format: "%.0f%% of extra credits", pct))
                }
            } else {
                // Legacy / API mode
                row(label: "Used", value: usage.primaryLabel)

                if let remaining = usage.remainingLabel {
                    row(label: "Left", value: remaining)
                }

                if let reset = usage.resetAt ?? usage.sessionResetsAt {
                    resetRow(label: "Resets", date: reset)
                }
            }

            row(label: "Source", value: usage.source.rawValue)
        }
        .padding(.horizontal, 24)
    }

    private func row(label: String, value: String) -> some View {
        HStack(spacing: 4) {
            Text(label)
                .foregroundStyle(.secondary)
                .frame(width: 68, alignment: .leading)
            Text(value)
                .fontWeight(.medium)
            Spacer()
        }
        .font(.callout)
    }

    private func resetRow(label: String, date: Date) -> some View {
        HStack(spacing: 4) {
            Text(label)
                .foregroundStyle(.secondary)
                .frame(width: 68, alignment: .leading)
            Text(date, style: .relative)
                .fontWeight(.medium)
            Spacer()
        }
        .font(.callout)
    }
}
