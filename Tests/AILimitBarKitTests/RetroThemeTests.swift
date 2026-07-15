import XCTest
import SwiftUI
@testable import AILimitBarKit

final class RetroThemeTests: XCTestCase {
    func testSeverityColorMapping() {
        let p = RetroTheme.jules
        XCTAssertEqual(RetroTheme.color(for: .ok, in: p), p.ok)
        XCTAssertEqual(RetroTheme.color(for: .warn, in: p), p.warn)
        XCTAssertEqual(RetroTheme.color(for: .critical, in: p), p.critical)
    }

    func testFontRegistration() {
        PixelFont.registerBundledFont()
        // After registration the PostScript/display name must resolve.
        XCTAssertNotNil(NSFont(name: "Press Start 2P", size: 12) ?? NSFont(name: "PressStart2P-Regular", size: 12))
    }

    func testJulesPaletteValues() {
        // DESIGN.md core palette (dark-only)
        XCTAssertEqual(RetroTheme.jules.background, Color(hex: 0x09051C))
        XCTAssertEqual(RetroTheme.jules.surface, Color(hex: 0x1D0245))
        XCTAssertEqual(RetroTheme.jules.textPrimary, Color(hex: 0xFFFFFF))
        XCTAssertEqual(RetroTheme.jules.accentPink, Color(hex: 0xFF79C6))
        XCTAssertEqual(RetroTheme.jules.accentCyan, Color(hex: 0x00D9FF))
        // Functional severity colors
        XCTAssertEqual(RetroTheme.jules.ok, Color(hex: 0x00D9FF))
        XCTAssertEqual(RetroTheme.jules.warn, Color(hex: 0xFFC300))
        XCTAssertEqual(RetroTheme.jules.critical, Color(hex: 0xFF5C5C))
    }
}
