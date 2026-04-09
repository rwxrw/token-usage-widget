import SwiftUI

struct StatsView: View {
    let usage: UsageData

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            row(label: "Used", value: usage.primaryLabel)

            if let remaining = usage.remainingLabel {
                row(label: "Left", value: remaining)
            }

            if let reset = usage.resetAt {
                HStack(spacing: 4) {
                    Text("Resets")
                        .foregroundStyle(.secondary)
                        .frame(width: 52, alignment: .leading)
                    Text(reset, style: .relative)
                        .fontWeight(.medium)
                    Spacer()
                }
                .font(.callout)
            }

            row(label: "Source", value: usage.source.rawValue)
        }
        .padding(.horizontal, 24)
    }

    private func row(label: String, value: String) -> some View {
        HStack(spacing: 4) {
            Text(label)
                .foregroundStyle(.secondary)
                .frame(width: 52, alignment: .leading)
            Text(value)
                .fontWeight(.medium)
            Spacer()
        }
        .font(.callout)
    }
}
