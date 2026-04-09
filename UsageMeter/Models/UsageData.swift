import Foundation

struct UsageData: Codable, Equatable {
    var messagesUsed: Int?
    var messagesLimit: Int?
    var tokensUsed: Int?
    var tokensLimit: Int?
    var resetAt: Date?
    var fetchedAt: Date
    var source: DataSource

    enum DataSource: String, Codable {
        case webInterception = "Web"
        case apiUsageReport  = "API"
        case rateLimitHeader = "Rate-limit header"
        case cached          = "Cached"
    }

    var fraction: Double {
        if let used = messagesUsed, let limit = messagesLimit, limit > 0 {
            return min(1.0, Double(used) / Double(limit))
        }
        if let used = tokensUsed, let limit = tokensLimit, limit > 0 {
            return min(1.0, Double(used) / Double(limit))
        }
        return 0
    }

    var primaryLabel: String {
        if let used = messagesUsed, let limit = messagesLimit {
            return "\(used) / \(limit) messages"
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
