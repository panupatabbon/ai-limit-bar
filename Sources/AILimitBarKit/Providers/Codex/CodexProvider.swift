import Foundation

/// Caches the resolved auth.json credentials in memory so CodexProvider
/// (a value type, re-fetched every poll) doesn't re-read the file every
/// 60s. Invalidated when the token turns out to be expired.
public final class CodexCredentialsCache: @unchecked Sendable {
    private let lock = NSLock()
    private var _cached: CodexCredentials?

    public init() {}

    var cached: CodexCredentials? {
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

public struct CodexProvider: QuotaProvider {
    public let id = "codex"
    public let displayName = "Codex"

    let source: CodexCredentialsSource
    let client: CodexUsageClient
    let now: @Sendable () -> Date
    let credentialsCache: CodexCredentialsCache

    public init(source: CodexCredentialsSource = CodexFileCredentialsSource(),
                client: CodexUsageClient = CodexUsageClient(),
                now: @escaping @Sendable () -> Date = { Date() },
                credentialsCache: CodexCredentialsCache = CodexCredentialsCache()) {
        self.source = source
        self.client = client
        self.now = now
        self.credentialsCache = credentialsCache
    }

    public func fetchSnapshot() async throws -> QuotaSnapshot {
        let creds = try resolveCredentials()
        do {
            let response = try await client.fetchUsage(accessToken: creds.accessToken)
            return QuotaSnapshot(
                planName: Self.planName(for: response.planType),
                limits: response.toQuotaLimits(),
                fetchedAt: now())
        } catch let error as QuotaError {
            if error == .tokenExpired {
                credentialsCache.cached = nil // force re-resolve on next poll
            }
            throw error
        }
    }

    // auth.json carries no expiry field (unlike Claude's expiresAt) — the
    // JWT's own exp claim isn't decoded; a 401 from the endpoint is the
    // only signal, same fallback the research doc calls out.
    private func resolveCredentials() throws -> CodexCredentials {
        if let cached = credentialsCache.cached { return cached }
        guard let creds = source.load() else {
            throw QuotaError.credentialsMissing
        }
        credentialsCache.cached = creds
        return creds
    }

    public static func planName(for planType: String?) -> String {
        guard let planType, !planType.isEmpty else { return "CODEX" }
        return "CODEX \(planType.uppercased())"
    }
}
