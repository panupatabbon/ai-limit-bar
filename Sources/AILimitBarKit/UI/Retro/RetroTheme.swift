import AppKit
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
    private static let backgroundHex: UInt32 = 0x09051C
    private static let okHex: UInt32 = 0x00D9FF
    private static let warnHex: UInt32 = 0xFFC300
    private static let criticalHex: UInt32 = 0xFF5C5C

    /// AppKit mirror of the background for window chrome (title bar blend).
    public static var nsBackground: NSColor { NSColor(hex: backgroundHex) }

    public static let jules = RetroPalette(
        background: Color(hex: backgroundHex),
        surface: Color(hex: 0x1D0245),
        textPrimary: Color(hex: 0xFFFFFF),
        accentPink: Color(hex: 0xFF79C6),
        accentCyan: Color(hex: 0x00D9FF),
        ok: Color(hex: okHex),
        warn: Color(hex: warnHex),
        critical: Color(hex: criticalHex))

    public static func color(for severity: Severity, in palette: RetroPalette) -> Color {
        switch severity {
        case .ok: return palette.ok
        case .warn: return palette.warn
        case .critical: return palette.critical
        }
    }

    // The menu bar ramp is deliberately quieter than the popover's Severity
    // Trio: at rest (ok) the item is NEUTRAL — white on a dark menu bar,
    // black on a light one — so the menu bar stays calm until something needs
    // attention, then climbs orange → red. (The popover keeps cyan → gold →
    // red.) The menu bar sits on the SYSTEM's surface, not the app's dark-only
    // one, so warn/critical carry darkened light-appearance variants at
    // ≥4.5:1 against a light menu bar.
    private static let warnMenuDarkHex: UInt32 = 0xFF7A1A
    private static let warnMenuLightHex: UInt32 = 0xC2410C
    private static let criticalMenuLightHex: UInt32 = 0xDC2626

    public static func menuBarColor(for severity: Severity, darkAppearance: Bool) -> NSColor {
        switch severity {
        case .ok:
            return darkAppearance ? .white : .black
        case .warn:
            return NSColor(hex: darkAppearance ? warnMenuDarkHex : warnMenuLightHex)
        case .critical:
            return NSColor(hex: darkAppearance ? criticalHex : criticalMenuLightHex)
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

public extension NSColor {
    convenience init(hex: UInt32) {
        self.init(srgbRed: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  alpha: 1)
    }
}
