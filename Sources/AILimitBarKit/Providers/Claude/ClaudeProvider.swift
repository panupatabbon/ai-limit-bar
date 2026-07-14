import Foundation

public struct ClaudeProvider: QuotaProvider {
    public let id = "claude"
    public let displayName = "CLAUDE"

    let resolver: CredentialsResolver
    let client: ClaudeUsageClient
    let now: @Sendable () -> Date

    public init(resolver: CredentialsResolver = .standard,
                client: ClaudeUsageClient = ClaudeUsageClient(),
                now: @escaping @Sendable () -> Date = { Date() }) {
        self.resolver = resolver
        self.client = client
        self.now = now
    }

    public func fetchSnapshot() async throws -> QuotaSnapshot {
        guard let creds = resolver.resolve() else {
            throw QuotaError.credentialsMissing
        }
        guard creds.expiresAt > now() else {
            throw QuotaError.tokenExpired // don't waste a doomed network call
        }
        let response = try await client.fetchUsage(accessToken: creds.accessToken)
        return QuotaSnapshot(
            planName: Self.planName(for: creds.subscriptionType),
            limits: response.toQuotaLimits(),
            fetchedAt: now())
    }

    public static func planName(for subscriptionType: String?) -> String {
        switch subscriptionType {
        case "max": return "CLAUDE MAX"
        case "pro": return "CLAUDE PRO"
        case "team": return "CLAUDE TEAM"
        case "enterprise": return "CLAUDE ENTERPRISE"
        default: return "CLAUDE"
        }
    }
}
