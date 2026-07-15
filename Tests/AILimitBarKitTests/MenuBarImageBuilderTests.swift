import XCTest
import AppKit
@testable import AILimitBarKit

final class MenuBarImageBuilderTests: XCTestCase {
    private var frame: SpriteFrame { SpriteLibrary.sprite(for: .boo).frames[0] }

    private func spec(text: String?, bar: Double?) -> MenuBarImageBuilder.Spec {
        .init(frame: frame, percentText: text, barFraction: bar, color: .systemGreen)
    }

    func testAvatarOnlyWidth() {
        XCTAssertEqual(MenuBarImageBuilder.layoutWidth(for: spec(text: nil, bar: nil)), 16)
    }

    func testBarOnlyWidth() {
        // 16 avatar + 3 gap + 14 bar
        XCTAssertEqual(MenuBarImageBuilder.layoutWidth(for: spec(text: nil, bar: 0.5)), 33)
    }

    func testTextWidthAtLeastBarWidth() {
        let w = MenuBarImageBuilder.layoutWidth(for: spec(text: "100%", bar: 1.0))
        XCTAssertGreaterThanOrEqual(w, 33)
    }

    func testImageMatchesLayout() {
        let s = spec(text: "42%", bar: 0.42)
        let image = MenuBarImageBuilder.image(for: s)
        XCTAssertEqual(image.size.height, 18)
        XCTAssertEqual(image.size.width, MenuBarImageBuilder.layoutWidth(for: s))
        XCTAssertFalse(image.isTemplate)
    }
}
