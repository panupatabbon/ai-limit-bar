import XCTest
@testable import AILimitBarKit

@MainActor
final class StatusItemLogicTests: XCTestCase {
    private let headline = QuotaLimit(kind: .weeklyAll, percentUsed: 58,
                                      resetsAt: Date(), isActive: true)
    private let snap = QuotaSnapshot(planName: "CLAUDE MAX", limits: [], fetchedAt: Date())

    func testTitle() {
        XCTAssertEqual(StatusItemController.menuBarTitle(
            headline: headline, state: .ready(snap), showPercent: true), "58%")
        XCTAssertEqual(StatusItemController.menuBarTitle(
            headline: headline, state: .ready(snap), showPercent: false), "")
        XCTAssertEqual(StatusItemController.menuBarTitle(
            headline: nil, state: .tokenExpired, showPercent: true), "--")
        XCTAssertEqual(StatusItemController.menuBarTitle(
            headline: nil, state: .credentialsMissing, showPercent: true), "--")
        // Offline with stale data still shows the stale number.
        XCTAssertEqual(StatusItemController.menuBarTitle(
            headline: headline, state: .offline(last: snap), showPercent: true), "58%")
    }

    func testColor() {
        let palette = RetroTheme.dark
        // NSColor(Color) equality is unreliable — compare sRGB components instead.
        let ready = StatusItemController.menuBarColor(
            headline: headline, state: .ready(snap), palette: palette)
            .usingColorSpace(.sRGB)!
        let expected = NSColor(palette.ok).usingColorSpace(.sRGB)!
        XCTAssertEqual(ready.redComponent, expected.redComponent, accuracy: 0.01)
        XCTAssertEqual(ready.greenComponent, expected.greenComponent, accuracy: 0.01)
        XCTAssertEqual(ready.blueComponent, expected.blueComponent, accuracy: 0.01)
        XCTAssertEqual(StatusItemController.menuBarColor(
            headline: nil, state: .tokenExpired, palette: palette), .systemGray)
    }

    func testMenuBarSpec() {
        let frame = SpriteLibrary.sprite(forProvider: "claude").menuBarFrames[0]
        let palette = RetroTheme.dark

        let ready = StatusItemController.menuBarSpec(
            headline: headline, state: .ready(snap), showPercent: true,
            frame: frame, palette: palette)
        XCTAssertEqual(ready.percentText, "58%")
        XCTAssertEqual(ready.barFraction, 0.58)

        let hidden = StatusItemController.menuBarSpec(
            headline: headline, state: .ready(snap), showPercent: false,
            frame: frame, palette: palette)
        XCTAssertNil(hidden.percentText)
        XCTAssertEqual(hidden.barFraction, 0.58) // bar still shown when % hidden

        let expired = StatusItemController.menuBarSpec(
            headline: nil, state: .tokenExpired, showPercent: true,
            frame: frame, palette: palette)
        XCTAssertEqual(expired.percentText, "--")
        XCTAssertNil(expired.barFraction)
    }
}
