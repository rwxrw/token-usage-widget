import Foundation

actor APIClient {
    private let baseURL = URL(string: "https://api.anthropic.com")!
    private var apiKey: String?

    private lazy var session: URLSession = {
        let config = URLSessionConfiguration.default
        config.httpAdditionalHeaders = [
            "anthropic-version": "2023-06-01",
            "Content-Type": "application/json"
        ]
        return URLSession(configuration: config)
    }()

    func setKey(_ key: String) { apiKey = key }

    func fetchUsageReport(organizationID: String) async throws -> UsageData {
        guard let key = apiKey, !key.isEmpty else { throw APIError.noKey }

        let now = Date()
        let startOfDay = Calendar.current.startOfDay(for: now)
        let iso = ISO8601DateFormatter()

        var comps = URLComponents(
            url: baseURL.appendingPathComponent("v1/organizations/\(organizationID)/usage_report/messages"),
            resolvingAgainstBaseURL: false
        )!
        comps.queryItems = [
            URLQueryItem(name: "start_time", value: iso.string(from: startOfDay)),
            URLQueryItem(name: "end_time",   value: iso.string(from: now))
        ]

        var req = URLRequest(url: comps.url!)
        req.setValue(key, forHTTPHeaderField: "x-api-key")

        let (data, response) = try await session.data(for: req)
        guard let http = response as? HTTPURLResponse else { throw APIError.badResponse }

        let remaining = http.value(forHTTPHeaderField: "anthropic-ratelimit-requests-remaining").flatMap(Int.init)
        let limit      = http.value(forHTTPHeaderField: "anthropic-ratelimit-requests-limit").flatMap(Int.init)
        let resetStr   = http.value(forHTTPHeaderField: "anthropic-ratelimit-requests-reset")

        switch http.statusCode {
        case 200:
            return try parseReport(data, remaining: remaining, limit: limit, resetStr: resetStr)
        case 429:
            if let remaining, let limit {
                var u = UsageData(fetchedAt: Date(), source: .rateLimitHeader)
                u.messagesUsed  = limit - remaining
                u.messagesLimit = limit
                u.resetAt = resetStr.flatMap { iso.date(from: $0) }
                return u
            }
            throw APIError.httpError(429)
        default:
            throw APIError.httpError(http.statusCode)
        }
    }

    private func parseReport(_ data: Data, remaining: Int?, limit: Int?, resetStr: String?) throws -> UsageData {
        struct Entry: Decodable { let input_tokens: Int; let output_tokens: Int }
        struct Report: Decodable { let usage: [Entry] }

        let report = try JSONDecoder().decode(Report.self, from: data)
        let total = report.usage.reduce(0) { $0 + $1.input_tokens + $1.output_tokens }

        var u = UsageData(fetchedAt: Date(), source: .apiUsageReport)
        u.tokensUsed    = total
        u.messagesUsed  = limit.map { $0 - (remaining ?? 0) }
        u.messagesLimit = limit
        u.resetAt = resetStr.flatMap { ISO8601DateFormatter().date(from: $0) }
        return u
    }

    enum APIError: LocalizedError {
        case noKey, badResponse, httpError(Int)
        var errorDescription: String? {
            switch self {
            case .noKey:           return "No API key configured."
            case .badResponse:     return "Invalid server response."
            case .httpError(let c): return "HTTP error \(c)."
            }
        }
    }
}
