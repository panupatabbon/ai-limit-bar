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
        background: Color(hex: 0x0A0A12),
        surface: Color(hex: 0x16161F),
        textPrimary: Color(hex: 0xE8E8F0),
        accentPink: Color(hex: 0xFF2E88),
        accentCyan: Color(hex: 0x00CCFF),
        ok: Color(hex: 0x00FF66),
        warn: Color(hex: 0xFFD500),
        critical: Color(hex: 0xFF3344))

    public static let light = RetroPalette(
        background: Color(hex: 0xF2EAD3),
        surface: Color(hex: 0xE6DCC0),
        textPrimary: Color(hex: 0x2B2B33),
        accentPink: Color(hex: 0xB0246A),
        accentCyan: Color(hex: 0x00708C),
        ok: Color(hex: 0x1D7A3E),
        warn: Color(hex: 0x9A6B00),
        critical: Color(hex: 0xB3232E))

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
