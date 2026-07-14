import Foundation

/// Caches the resolved Keychain/file credentials in memory so ClaudeProvider
/// (a value type, re-fetched every poll) doesn't re-read the Keychain every
/// 60s. Invalidated when the token turns out to be expired.
public final class CredentialsCache: @unchecked Sendable {
    private let lock = NSLock()
    private var _cached: ClaudeCredentials?

    public init() {}

    var cached: ClaudeCredentials? {
        get {
            lock.lock()
            defer { lock.unlock() }
            return _cached
        }
        set {
            lock.lock()
            defer { lock.unlock() }
            _cached = newValue
        }
    }
}

public struct ClaudeProvider: QuotaProvider {
    public let id = "claude"
    public let displayName = "CLAUDE"

    let resolver: CredentialsResolver
    let client: ClaudeUsageClient
    let now: @Sendable () -> Date
    let credentialsCache: CredentialsCache

    public init(resolver: CredentialsResolver = .standard,
                client: ClaudeUsageClient = ClaudeUsageClient(),
                now: @escaping @Sendable () -> Date = { Date() },
                credentialsCache: CredentialsCache = CredentialsCache()) {
        self.resolver = resolver
        self.client = client
        self.now = now
        self.credentialsCache = credentialsCache
    }

    public func fetchSnapshot() async throws -> QuotaSnapshot {
        let creds = try resolveCredentials()
        do {
            let response = try await client.fetchUsage(accessToken: creds.accessToken)
            return QuotaSnapshot(
                planName: Self.planName(for: creds.subscriptionType),
                limits: response.toQuotaLimits(),
                fetchedAt: now())
        } catch let error as QuotaError {
            if error == .tokenExpired {
                credentialsCache.cached = nil // force re-resolve on next poll
            }
            throw error
        }
    }

    private func resolveCredentials() throws -> ClaudeCredentials {
        if let cached = credentialsCache.cached, cached.expiresAt > now() {
            return cached
        }
        guard let creds = resolver.resolve() else {
            throw QuotaError.credentialsMissing
        }
        guard creds.expiresAt > now() else {
            throw QuotaError.tokenExpired // don't waste a doomed network call
        }
        credentialsCache.cached = creds
        return creds
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
