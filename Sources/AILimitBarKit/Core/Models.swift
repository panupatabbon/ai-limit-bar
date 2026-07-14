import Foundation

public enum LimitKind: Equatable, Sendable {
    case session
    case weeklyAll
    case weeklyModel(String) // model display name, e.g. "Fable"
}

public struct QuotaLimit: Equatable, Sendable {
    public let kind: LimitKind
    public let percentUsed: Double // 0-100 (may exceed 100)
    public let resetsAt: Date
    public let isActive: Bool

    public init(kind: LimitKind, percentUsed: Double, resetsAt: Date, isActive: Bool) {
        self.kind = kind
        self.percentUsed = percentUsed
        self.resetsAt = resetsAt
        self.isActive = isActive
    }
}

public struct QuotaSnapshot: Equatable, Sendable {
    public let planName: String // "CLAUDE MAX"
    public let limits: [QuotaLimit]
    public let fetchedAt: Date

    public init(planName: String, limits: [QuotaLimit], fetchedAt: Date) {
        self.planName = planName
        self.limits = limits
        self.fetchedAt = fetchedAt
    }
}

public enum Severity: Equatable, Sendable {
    case ok, warn, critical

    public init(percent: Double) {
        switch percent {
        case ..<60: self = .ok
        case ..<85: self = .warn
        default: self = .critical
        }
    }
}

public protocol QuotaProvider: Sendable {
    var id: String { get }
    var displayName: String { get }
    func fetchSnapshot() async throws -> QuotaSnapshot
}

public enum QuotaError: Error, Equatable {
    case credentialsMissing
    case tokenExpired
    case network(String)
    case badResponse(String)
}
