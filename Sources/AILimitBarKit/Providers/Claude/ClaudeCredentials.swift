import Foundation
import Security

public struct ClaudeCredentials: Equatable, Sendable {
    public let accessToken: String
    public let expiresAt: Date
    public let subscriptionType: String?

    public init(accessToken: String, expiresAt: Date, subscriptionType: String?) {
        self.accessToken = accessToken
        self.expiresAt = expiresAt
        self.subscriptionType = subscriptionType
    }

    /// Parses Claude Code's credentials JSON. Reads accessToken/expiresAt/
    /// subscriptionType only — the refresh token is deliberately never touched.
    public static func parse(_ data: Data) -> ClaudeCredentials? {
        guard
            let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let oauth = root["claudeAiOauth"] as? [String: Any],
            let token = oauth["accessToken"] as? String, !token.isEmpty,
            let expiresMs = oauth["expiresAt"] as? Double
        else { return nil }
        return ClaudeCredentials(
            accessToken: token,
            expiresAt: Date(timeIntervalSince1970: expiresMs / 1000),
            subscriptionType: oauth["subscriptionType"] as? String)
    }
}

public protocol CredentialsSource: Sendable {
    func load() -> ClaudeCredentials?
}

public struct FileCredentialsSource: CredentialsSource {
    let path: String

    public init(path: String = NSString(string: "~/.claude/.credentials.json").expandingTildeInPath) {
        self.path = path
    }

    public func load() -> ClaudeCredentials? {
        guard let data = FileManager.default.contents(atPath: path) else { return nil }
        return ClaudeCredentials.parse(data)
    }
}

/// Read-only lookup of Claude Code's Keychain item. First access triggers
/// macOS's standard "allow access" dialog — documented in the README.
public struct KeychainCredentialsSource: CredentialsSource {
    public init() {}

    public func load() -> ClaudeCredentials? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "Claude Code-credentials",
            kSecAttrAccount as String: NSUserName(),
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return ClaudeCredentials.parse(data)
    }
}

public struct CredentialsResolver: Sendable {
    let sources: [CredentialsSource]

    public init(sources: [CredentialsSource]) {
        self.sources = sources
    }

    public static var standard: CredentialsResolver {
        CredentialsResolver(sources: [KeychainCredentialsSource(), FileCredentialsSource()])
    }

    public func resolve() -> ClaudeCredentials? {
        sources.compactMap { $0.load() }.max { $0.expiresAt < $1.expiresAt }
    }
}
