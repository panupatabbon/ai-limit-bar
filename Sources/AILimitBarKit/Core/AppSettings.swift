import Foundation
import Observation

@MainActor
@Observable
public final class AppSettings {
    private let defaults: UserDefaults

    public var showPercentInMenuBar: Bool { didSet { defaults.set(showPercentInMenuBar, forKey: "showPercentInMenuBar") } }
    public var headlinePin: HeadlinePin { didSet { defaults.set(headlinePin.rawValue, forKey: "headlinePin") } }
    public var showSession: Bool { didSet { defaults.set(showSession, forKey: "showSession") } }
    public var showWeeklyAll: Bool { didSet { defaults.set(showWeeklyAll, forKey: "showWeeklyAll") } }
    public var showWeeklyModels: Bool { didSet { defaults.set(showWeeklyModels, forKey: "showWeeklyModels") } }
    public var compactRows: Bool { didSet { defaults.set(compactRows, forKey: "compactRows") } }
    public var enabledProviders: Set<ProviderID> { didSet { defaults.set(enabledProviders.map(\.rawValue).sorted(), forKey: "enabledProviders") } }
    /// Deliberately not persisted while non-live tabs exist: every open
    /// must land on a live provider so the primary glance never dead-ends.
    public var selectedTab: ProviderID = .claude

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        showPercentInMenuBar = defaults.object(forKey: "showPercentInMenuBar") as? Bool ?? true
        headlinePin = HeadlinePin(rawValue: defaults.string(forKey: "headlinePin") ?? "") ?? .auto
        showSession = defaults.object(forKey: "showSession") as? Bool ?? true
        showWeeklyAll = defaults.object(forKey: "showWeeklyAll") as? Bool ?? true
        showWeeklyModels = defaults.object(forKey: "showWeeklyModels") as? Bool ?? true
        compactRows = defaults.object(forKey: "compactRows") as? Bool ?? false
        enabledProviders = Self.sanitizedProviders(defaults.stringArray(forKey: "enabledProviders"))
    }

    /// Unknown values dropped; if no *live* provider remains (empty set, or
    /// only coming-soon providers — possible when catalog availability
    /// changes across versions), .claude is added back so the menu bar can
    /// never be empty.
    public static func sanitizedProviders(_ raw: [String]?) -> Set<ProviderID> {
        var set = Set((raw ?? [ProviderID.claude.rawValue]).compactMap(ProviderID.init(rawValue:)))
        if set.isDisjoint(with: ProviderCatalog.liveIDs) { set.insert(.claude) }
        return set
    }

    public func isVisible(_ kind: LimitKind) -> Bool {
        switch kind {
        case .session: return showSession
        case .weeklyAll: return showWeeklyAll
        case .weeklyModel: return showWeeklyModels
        }
    }
}
