import XCTest
import SwiftUI
@testable import AILimitBarKit

final class RetroThemeTests: XCTestCase {
    func testSeverityColorMapping() {
        let p = RetroTheme.dark
        XCTAssertEqual(RetroTheme.color(for: .ok, in: p), p.ok)
        XCTAssertEqual(RetroTheme.color(for: .warn, in: p), p.warn)
        XCTAssertEqual(RetroTheme.color(for: .critical, in: p), p.critical)
    }

    func testPaletteSelection() {
        XCTAssertEqual(RetroTheme.palette(.dark, systemIsDark: false).background,
                       RetroTheme.dark.background)
        XCTAssertEqual(RetroTheme.palette(.light, systemIsDark: true).background,
                       RetroTheme.light.background)
        XCTAssertEqual(RetroTheme.palette(.system, systemIsDark: true).background,
                       RetroTheme.dark.background)
        XCTAssertEqual(RetroTheme.palette(.system, systemIsDark: false).background,
                       RetroTheme.light.background)
    }

    func testFontRegistration() {
        PixelFont.registerBundledFont()
        // After registration the PostScript/display name must resolve.
        XCTAssertNotNil(NSFont(name: "Press Start 2P", size: 12) ?? NSFont(name: "PressStart2P-Regular", size: 12))
    }
}
