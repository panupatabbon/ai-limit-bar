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
    /// Jules-inspired dark cyberpunk palette (see DESIGN.md). Dark-only —
    /// the light theme and theme switching were removed by design.
    /// Severity colors are functional additions: cyan ok / yellow warn
    /// (DESIGN.md's yellow accent) / red critical (magenta stays brand-only).
    public static let jules = RetroPalette(
        background: Color(hex: 0x09051C),
        surface: Color(hex: 0x1D0245),
        textPrimary: Color(hex: 0xFFFFFF),
        accentPink: Color(hex: 0xFF79C6),
        accentCyan: Color(hex: 0x00D9FF),
        ok: Color(hex: 0x00D9FF),
        warn: Color(hex: 0xFFC300),
        critical: Color(hex: 0xFF5C5C))

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
