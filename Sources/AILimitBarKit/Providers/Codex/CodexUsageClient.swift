import Foundation

/// Wire format of GET https://chatgpt.com/backend-api/wham/usage
/// (undocumented endpoint; PII fields such as user_id/account_id/email are
/// present in the live response but deliberately never declared here).
public struct CodexUsageResponse: Decodable {
    public struct Window: Decodable {
        public let usedPercent: Double?
        public let limitWindowSeconds: Int?
        public let resetAt: Double?

        enum CodingKeys: String, CodingKey {
            case usedPercent = "used_percent"
            case limitWindowSeconds = "limit_window_seconds"
            case resetAt = "reset_at"
        }
    }

    public struct RateLimit: Decodable {
        public let primaryWindow: Window?
        public let secondaryWindow: Window?

        enum CodingKeys: String, CodingKey {
            case primaryWindow = "primary_window"
            case secondaryWindow = "secondary_window"
        }
    }

    public let planType: String?
    public let rateLimit: RateLimit?

    enum CodingKeys: String, CodingKey {
        case planType = "plan_type"
        case rateLimit = "rate_limit"
    }

    public static func decode(_ data: Data) throws -> CodexUsageResponse {
        try JSONDecoder().decode(CodexUsageResponse.self, from: data)
    }

    /// No explicit kind label like Claude's `kind: "session" | "weekly_all"` —
    /// classified from limit_window_seconds per the research doc (< 1 day = session).
    public func toQuotaLimits() -> [QuotaLimit] {
        [rateLimit?.primaryWindow, rateLimit?.secondaryWindow]
            .compactMap(Self.makeLimit)
    }

    private static func makeLimit(_ window: Window?) -> QuotaLimit? {
        guard let window,
              let percent = window.usedPercent,
              let windowSeconds = window.limitWindowSeconds,
              let resetAt = window.resetAt else { return nil }
        let kind: LimitKind = windowSeconds < 86_400 ? .session : .weeklyAll
        return QuotaLimit(kind: kind, percentUsed: percent,
                          resetsAt: Date(timeIntervalSince1970: resetAt), isActive: false)
    }
}

public struct CodexUsageClient: Sendable {
    public static let endpoint = URL(string: "https://chatgpt.com/backend-api/wham/usage")!
    let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func fetchUsage(accessToken: String) async throws -> CodexUsageResponse {
        var request = URLRequest(url: Self.endpoint)
        request.httpMethod = "GET"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw QuotaError.network(error.localizedDescription)
        }
        guard let http = response as? HTTPURLResponse else {
            throw QuotaError.badResponse("non-HTTP response")
        }
        switch http.statusCode {
        case 200:
            do { return try CodexUsageResponse.decode(data) }
            catch { throw QuotaError.badResponse("decode failed: \(error)") }
        case 401, 403:
            throw QuotaError.tokenExpired
        default:
            throw QuotaError.badResponse("HTTP \(http.statusCode)")
        }
    }
}
