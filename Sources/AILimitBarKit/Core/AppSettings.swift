import Foundation
import Observation

public enum AppLanguage: String, CaseIterable, Sendable { case en, th }
public enum ThemePreference: String, CaseIterable, Sendable { case system, dark, light }
public enum AvatarID: String, CaseIterable, Sendable { case boo, bug, bot }

@MainActor
@Observable
public final class AppSettings {
    private let defaults: UserDefaults

    public var language: AppLanguage { didSet { defaults.set(language.rawValue, forKey: "language") } }
    public var theme: ThemePreference { didSet { defaults.set(theme.rawValue, forKey: "theme") } }
    public var showPercentInMenuBar: Bool { didSet { defaults.set(showPercentInMenuBar, forKey: "showPercentInMenuBar") } }
    public var headlinePin: HeadlinePin { didSet { defaults.set(headlinePin.rawValue, forKey: "headlinePin") } }
    public var showSession: Bool { didSet { defaults.set(showSession, forKey: "showSession") } }
    public var showWeeklyAll: Bool { didSet { defaults.set(showWeeklyAll, forKey: "showWeeklyAll") } }
    public var showWeeklyModels: Bool { didSet { defaults.set(showWeeklyModels, forKey: "showWeeklyModels") } }
    public var compactRows: Bool { didSet { defaults.set(compactRows, forKey: "compactRows") } }
    public var avatar: AvatarID { didSet { defaults.set(avatar.rawValue, forKey: "avatar") } }

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        language = AppLanguage(rawValue: defaults.string(forKey: "language") ?? "") ?? .en
        theme = ThemePreference(rawValue: defaults.string(forKey: "theme") ?? "") ?? .system
        showPercentInMenuBar = defaults.object(forKey: "showPercentInMenuBar") as? Bool ?? true
        headlinePin = HeadlinePin(rawValue: defaults.string(forKey: "headlinePin") ?? "") ?? .auto
        showSession = defaults.object(forKey: "showSession") as? Bool ?? true
        showWeeklyAll = defaults.object(forKey: "showWeeklyAll") as? Bool ?? true
        showWeeklyModels = defaults.object(forKey: "showWeeklyModels") as? Bool ?? true
        compactRows = defaults.object(forKey: "compactRows") as? Bool ?? false
        avatar = AvatarID(rawValue: defaults.string(forKey: "avatar") ?? "") ?? .boo
    }

    public func isVisible(_ kind: LimitKind) -> Bool {
        switch kind {
        case .session: return showSession
        case .weeklyAll: return showWeeklyAll
        case .weeklyModel: return showWeeklyModels
        }
    }
}
