import Foundation

/// Wire format of GET https://api.anthropic.com/api/oauth/usage
/// (undocumented endpoint; every field optional for forward compatibility).
public struct UsageResponse: Decodable {
    public struct LimitEntry: Decodable {
        public let kind: String?
        public let percent: Double?
        public let resetsAt: String?
        public let isActive: Bool?
        public let scope: Scope?

        enum CodingKeys: String, CodingKey {
            case kind, percent, scope
            case resetsAt = "resets_at"
            case isActive = "is_active"
        }
    }

    public struct Scope: Decodable {
        public let model: Model?
        public struct Model: Decodable {
            public let displayName: String?
            enum CodingKeys: String, CodingKey { case displayName = "display_name" }
        }
    }

    public struct Window: Decodable {
        public let utilization: Double?
        public let resetsAt: String?
        enum CodingKeys: String, CodingKey {
            case utilization
            case resetsAt = "resets_at"
        }
    }

    public let limits: [LimitEntry]?
    public let fiveHour: Window?
    public let sevenDay: Window?

    enum CodingKeys: String, CodingKey {
        case limits
        case fiveHour = "five_hour"
        case sevenDay = "seven_day"
    }

    public static func decode(_ data: Data) throws -> UsageResponse {
        try JSONDecoder().decode(UsageResponse.self, from: data)
    }

    public func toQuotaLimits() -> [QuotaLimit] {
        let mapped = (limits ?? []).compactMap { entry -> QuotaLimit? in
            guard let percent = entry.percent,
                  let raw = entry.resetsAt,
                  let resetsAt = AnthropicDate.parse(raw) else { return nil }
            let kind: LimitKind
            switch entry.kind {
            case "session": kind = .session
            case "weekly_all": kind = .weeklyAll
            case "weekly_scoped":
                kind = .weeklyModel(entry.scope?.model?.displayName ?? "MODEL")
            default: return nil // unknown kinds skipped for forward compatibility
            }
            return QuotaLimit(kind: kind, percentUsed: percent,
                              resetsAt: resetsAt, isActive: entry.isActive ?? false)
        }
        if !mapped.isEmpty { return mapped.sorted(by: Self.displayOrder) }

        // Legacy fallback when limits[] is absent/empty.
        var fallback: [QuotaLimit] = []
        if let w = fiveHour, let pct = w.utilization,
           let raw = w.resetsAt, let date = AnthropicDate.parse(raw) {
            fallback.append(QuotaLimit(kind: .session, percentUsed: pct,
                                       resetsAt: date, isActive: false))
        }
        if let w = sevenDay, let pct = w.utilization,
           let raw = w.resetsAt, let date = AnthropicDate.parse(raw) {
            fallback.append(QuotaLimit(kind: .weeklyAll, percentUsed: pct,
                                       resetsAt: date, isActive: false))
        }
        return fallback
    }

    private static func displayOrder(_ a: QuotaLimit, _ b: QuotaLimit) -> Bool {
        func rank(_ kind: LimitKind) -> Int {
            switch kind {
            case .session: return 0
            case .weeklyAll: return 1
            case .weeklyModel: return 2
            }
        }
        return rank(a.kind) < rank(b.kind)
    }
}
