import Foundation

// Response shape from GET /api/organizations/{id}/usage
private struct UsageResponse: Decodable {
    struct Window: Decodable {
        let utilization: Double
        let resets_at: String
    }
    struct ExtraUsage: Decodable {
        let is_enabled: Bool
        let monthly_limit: Double?
        let used_credits: Double?
        let utilization: Double?
    }
    let five_hour: Window
    let seven_day: Window
    let extra_usage: ExtraUsage?
}

// Response shape from GET /api/organizations
private struct OrgsResponse: Decodable {
    struct Org: Decodable {
        let uuid: String
        let name: String?
    }
    // The endpoint returns an array directly
}

private struct OrgEntry: Decodable {
    let uuid: String
    let name: String?
}

actor ClaudeClient {
    private let session: URLSession
    private let isoFormatter: ISO8601DateFormatter

    init() {
        let config = URLSessionConfiguration.ephemeral
        config.httpShouldSetCookies = false
        config.httpAdditionalHeaders = [
            "anthropic-client-platform": "web_claude_ai",
            "anthropic-client-version": "1.0.0",
            "content-type": "application/json",
            "Accept": "application/json",
            "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15",
        ]
        session = URLSession(configuration: config)

        isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    }

    /// Fetches usage for a given org using the discovered endpoint.
    func fetchUsage(sessionKey: String, orgID: String) async throws -> UsageData {
        guard let url = URL(string: "https://claude.ai/api/organizations/\(orgID)/usage") else {
            throw ClaudeClientError.invalidURL
        }
        var request = URLRequest(url: url)
        request.setValue("sessionKey=\(sessionKey)", forHTTPHeaderField: "Cookie")

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw ClaudeClientError.unexpectedResponse
        }
        guard http.statusCode == 200 else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw ClaudeClientError.httpError(http.statusCode, body)
        }

        let decoded = try JSONDecoder().decode(UsageResponse.self, from: data)
        return makeUsageData(from: decoded)
    }

    /// Discovers the first org ID by calling /api/organizations.
    func discoverOrgID(sessionKey: String) async throws -> String {
        guard let url = URL(string: "https://claude.ai/api/organizations") else {
            throw ClaudeClientError.invalidURL
        }
        var request = URLRequest(url: url)
        request.setValue("sessionKey=\(sessionKey)", forHTTPHeaderField: "Cookie")

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw ClaudeClientError.unexpectedResponse
        }
        guard http.statusCode == 200 else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw ClaudeClientError.httpError(http.statusCode, body)
        }

        let orgs = try JSONDecoder().decode([OrgEntry].self, from: data)
        guard let first = orgs.first else {
            throw ClaudeClientError.noOrganizationFound
        }
        return first.uuid
    }

    // MARK: - Private

    private func makeUsageData(from r: UsageResponse) -> UsageData {
        var usage = UsageData(fetchedAt: Date(), source: .claudeWebAPI)
        usage.sessionUtilization = r.five_hour.utilization
        usage.sessionResetsAt    = isoFormatter.date(from: r.five_hour.resets_at)
        usage.weeklyUtilization  = r.seven_day.utilization
        usage.weeklyResetsAt     = isoFormatter.date(from: r.seven_day.resets_at)

        if let extra = r.extra_usage {
            usage.extraCreditsEnabled     = extra.is_enabled
            usage.extraCreditsLimit       = extra.monthly_limit
            usage.extraCreditsUsed        = extra.used_credits
            usage.extraCreditsUtilization = extra.utilization
        }
        return usage
    }
}

enum ClaudeClientError: LocalizedError {
    case invalidURL
    case unexpectedResponse
    case httpError(Int, String)
    case noOrganizationFound

    var errorDescription: String? {
        switch self {
        case .invalidURL:            return "Invalid URL"
        case .unexpectedResponse:    return "Unexpected server response"
        case .httpError(let c, _):   return "HTTP \(c) — check your session key"
        case .noOrganizationFound:   return "No organization found for this session key"
        }
    }
}
