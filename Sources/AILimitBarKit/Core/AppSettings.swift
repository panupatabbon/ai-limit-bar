import Foundation
import Observation

public enum ProviderTab: String, CaseIterable, Sendable { case claude, gemini }

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
    /// Deliberately not persisted while Gemini is a placeholder: every open
    /// must land on Claude so the primary glance never hits a dead end.
    public var selectedTab: ProviderTab = .claude

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        showPercentInMenuBar = defaults.object(forKey: "showPercentInMenuBar") as? Bool ?? true
        headlinePin = HeadlinePin(rawValue: defaults.string(forKey: "headlinePin") ?? "") ?? .auto
        showSession = defaults.object(forKey: "showSession") as? Bool ?? true
        showWeeklyAll = defaults.object(forKey: "showWeeklyAll") as? Bool ?? true
        showWeeklyModels = defaults.object(forKey: "showWeeklyModels") as? Bool ?? true
        compactRows = defaults.object(forKey: "compactRows") as? Bool ?? false
    }

    public func isVisible(_ kind: LimitKind) -> Bool {
        switch kind {
        case .session: return showSession
        case .weeklyAll: return showWeeklyAll
        case .weeklyModel: return showWeeklyModels
        }
    }
}
