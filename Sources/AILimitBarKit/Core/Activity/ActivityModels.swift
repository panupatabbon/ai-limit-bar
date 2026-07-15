import Foundation

public struct ActivityCount: Equatable, Sendable {
    public let name: String
    public let count: Int
    public init(name: String, count: Int) {
        self.name = name
        self.count = count
    }
}

public struct ActivitySummary: Equatable, Sendable {
    public let topSkills: [ActivityCount]
    public let topAgents: [ActivityCount]
    /// Totals across ALL names (not just the top 3) so shares can be
    /// computed against real usage.
    public let skillEventCount: Int
    public let agentEventCount: Int
    public let sessionCount: Int
    public let scannedAt: Date

    public init(topSkills: [ActivityCount], topAgents: [ActivityCount],
                skillEventCount: Int, agentEventCount: Int,
                sessionCount: Int, scannedAt: Date) {
        self.topSkills = topSkills
        self.topAgents = topAgents
        self.skillEventCount = skillEventCount
        self.agentEventCount = agentEventCount
        self.sessionCount = sessionCount
        self.scannedAt = scannedAt
    }

    /// Percent share of a count against its group total, rounded; a nonzero
    /// count never rounds down to 0%.
    public static func percentShare(_ count: Int, of total: Int) -> Int {
        guard total > 0, count > 0 else { return 0 }
        return max(1, Int((Double(count) / Double(total) * 100).rounded()))
    }
}

public enum ActivityEvent: Equatable, Sendable {
    case skill(String)
    case agent(String)
}
