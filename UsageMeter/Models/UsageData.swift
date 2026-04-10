import Foundation

struct UsageData: Codable, Equatable {
    // Legacy fields (API mode / web interception fallback)
    var messagesUsed: Int?
    var messagesLimit: Int?
    var tokensUsed: Int?
    var tokensLimit: Int?
    var usedPercent: Double?      // 0–100, from percentage-based APIs

    // Fields from the real claude.ai /api/organizations/{id}/usage endpoint
    var sessionUtilization: Double?   // five_hour.utilization (0–100)
    var sessionResetsAt: Date?        // five_hour.resets_at
    var weeklyUtilization: Double?    // seven_day.utilization (0–100)
    var weeklyResetsAt: Date?         // seven_day.resets_at
    var extraCreditsEnabled: Bool     = false
    var extraCreditsLimit: Double?    // extra_usage.monthly_limit
    var extraCreditsUsed: Double?     // extra_usage.used_credits
    var extraCreditsUtilization: Double? // extra_usage.utilization (0–100)

    // Legacy reset field (web interception)
    var resetAt: Date?
    var resetAtSession: Date?

    var fetchedAt: Date
    var source: DataSource

    enum DataSource: String, Codable {
        case webInterception = "Web"
        case apiUsageReport  = "API"
        case rateLimitHeader = "Rate-limit header"
        case cached          = "Cached"
        case claudeWebAPI    = "claude.ai API"
    }

    /// Primary fraction used for the gauge (0–1).
    /// Prefers the 5-hour session window from the real API.
    var fraction: Double {
        if let pct = sessionUtilization { return min(1.0, pct / 100.0) }
        if let pct = usedPercent        { return min(1.0, pct / 100.0) }
        if let used = messagesUsed, let limit = messagesLimit, limit > 0 {
            return min(1.0, Double(used) / Double(limit))
        }
        if let used = tokensUsed, let limit = tokensLimit, limit > 0 {
            return min(1.0, Double(used) / Double(limit))
        }
        return 0
    }

    var primaryLabel: String {
        if let pct = sessionUtilization {
            return String(format: "%.0f%% of session limit used", pct)
        }
        if let used = messagesUsed, let limit = messagesLimit {
            return "\(used) / \(limit) messages"
        }
        if let pct = usedPercent {
            return String(format: "%.0f%% used", pct)
        }
        if let used = messagesUsed {
            return "\(used) messages used"
        }
        if let used = tokensUsed {
            let formatted = used >= 1_000_000
                ? String(format: "%.1fM", Double(used) / 1_000_000)
                : used >= 1_000
                    ? String(format: "%.1fK", Double(used) / 1_000)
                    : "\(used)"
            return "\(formatted) tokens used"
        }
        return "No data yet"
    }

    var remainingLabel: String? {
        if let used = messagesUsed, let limit = messagesLimit {
            return "\(limit - used) remaining"
        }
        return nil
    }
}

struct UsageSnapshot: Codable {
    var data: UsageData
    var persistedAt: Date
}

enum PlanType: String, Codable, CaseIterable, Identifiable {
    case free = "Free"
    case pro  = "Pro"
    var id: String { rawValue }
}

enum TrackingMode: String, Codable, CaseIterable, Identifiable {
    case web = "Web (claude.ai)"
    case api = "Anthropic API"
    var id: String { rawValue }
}
