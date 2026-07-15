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
    public let sessionCount: Int
    public let scannedAt: Date
    public init(topSkills: [ActivityCount], topAgents: [ActivityCount],
                sessionCount: Int, scannedAt: Date) {
        self.topSkills = topSkills
        self.topAgents = topAgents
        self.sessionCount = sessionCount
        self.scannedAt = scannedAt
    }
}

public enum ActivityEvent: Equatable, Sendable {
    case skill(String)
    case agent(String)
}
