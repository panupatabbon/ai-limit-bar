import Foundation

public struct CodexCredentials: Equatable, Sendable {
    public let accessToken: String

    public init(accessToken: String) {
        self.accessToken = accessToken
    }

    /// Parses Codex CLI's auth.json. Reads tokens.access_token only — the
    /// id_token/refresh_token/account_id fields are deliberately never touched.
    public static func parse(_ data: Data) -> CodexCredentials? {
        guard
            let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let tokens = root["tokens"] as? [String: Any],
            let token = tokens["access_token"] as? String, !token.isEmpty
        else { return nil }
        return CodexCredentials(accessToken: token)
    }
}

public protocol CodexCredentialsSource: Sendable {
    func load() -> CodexCredentials?
}

public struct CodexFileCredentialsSource: CodexCredentialsSource {
    let path: String

    public init(path: String = NSString(string: "~/.codex/auth.json").expandingTildeInPath) {
        self.path = path
    }

    public func load() -> CodexCredentials? {
        guard let data = FileManager.default.contents(atPath: path) else { return nil }
        return CodexCredentials.parse(data)
    }
}
