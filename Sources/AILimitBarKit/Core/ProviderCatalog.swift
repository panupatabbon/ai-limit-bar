import Foundation

public enum ProviderID: String, CaseIterable, Sendable {
    case claude, codex, gemini, cursor
}

public enum ProviderAvailability: Equatable, Sendable {
    case live, comingSoon
}

public struct ProviderDescriptor: Sendable {
    public let id: ProviderID
    public let displayName: String
    public let cliName: String
    public let availability: ProviderAvailability
}

public enum ProviderCatalog {
    public static let all: [ProviderDescriptor] = [
        .init(id: .claude, displayName: "Claude", cliName: "Claude Code", availability: .live),
        .init(id: .codex, displayName: "Codex", cliName: "Codex CLI", availability: .comingSoon),
        .init(id: .gemini, displayName: "Gemini", cliName: "Gemini CLI", availability: .comingSoon),
        .init(id: .cursor, displayName: "Cursor", cliName: "Cursor", availability: .comingSoon),
    ]

    public static func descriptor(for id: ProviderID) -> ProviderDescriptor {
        all.first { $0.id == id }!
    }

    public static var liveIDs: Set<ProviderID> {
        Set(all.filter { $0.availability == .live }.map(\.id))
    }

    /// The single flip point per adapter: when a provider goes live, return
    /// its QuotaProvider here AND set availability to .live above.
    public static func makeProvider(for id: ProviderID) -> QuotaProvider? {
        switch id {
        case .claude: return ClaudeProvider()
        case .codex, .gemini, .cursor: return nil
        }
    }
}
