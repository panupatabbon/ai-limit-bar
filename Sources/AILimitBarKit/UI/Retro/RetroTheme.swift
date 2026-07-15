import SwiftUI

public struct RetroPalette: Equatable, Sendable {
    public let background: Color
    public let surface: Color
    public let textPrimary: Color
    public let accentPink: Color
    public let accentCyan: Color
    public let ok: Color
    public let warn: Color
    public let critical: Color
}

public enum RetroTheme {
    public static let dark = RetroPalette(
        background: Color(hex: 0x14141B),
        surface: Color(hex: 0x1E1E28),
        textPrimary: Color(hex: 0xD8D8E4),
        accentPink: Color(hex: 0xE85D9E),
        accentCyan: Color(hex: 0x5BC8E8),
        ok: Color(hex: 0x4ADE80),
        warn: Color(hex: 0xE8C547),
        critical: Color(hex: 0xF07171))

    public static let light = RetroPalette(
        background: Color(hex: 0xF5EFDF),
        surface: Color(hex: 0xEAE2CC),
        textPrimary: Color(hex: 0x3A3A42),
        accentPink: Color(hex: 0xA8487E),
        accentCyan: Color(hex: 0x2E7D96),
        ok: Color(hex: 0x3B8C5A),
        warn: Color(hex: 0xB0821F),
        critical: Color(hex: 0xC25454))

    public static func palette(_ pref: ThemePreference, systemIsDark: Bool) -> RetroPalette {
        switch pref {
        case .dark: return dark
        case .light: return light
        case .system: return systemIsDark ? dark : light
        }
    }

    public static func color(for severity: Severity, in palette: RetroPalette) -> Color {
        switch severity {
        case .ok: return palette.ok
        case .warn: return palette.warn
        case .critical: return palette.critical
        }
    }
}

public extension Color {
    init(hex: UInt32) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: 1)
    }
}
