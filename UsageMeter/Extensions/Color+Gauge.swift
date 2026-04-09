import SwiftUI

extension Color {
    // Green (0–60%) → orange (60–85%) → red (85–100%)
    static func gauge(fraction: Double) -> Color {
        let f = max(0, min(1, fraction))
        switch f {
        case ..<0.6:
            // Pure green
            return Color(red: 0.15, green: 0.75, blue: 0.25)
        case ..<0.85:
            // Green → orange
            let t = (f - 0.6) / 0.25
            return Color(red: 0.15 + 0.85 * t, green: 0.75 - 0.20 * t, blue: 0.0)
        default:
            // Orange → red
            let t = (f - 0.85) / 0.15
            return Color(red: 1.0, green: (0.55 - 0.55 * t), blue: 0.0)
        }
    }
}
