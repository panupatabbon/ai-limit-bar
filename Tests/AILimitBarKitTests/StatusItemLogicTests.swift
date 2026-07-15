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

    func testMenuBarSpec() {
        let frame = SpriteLibrary.sprite(forProvider: "claude").menuBarFrames[0]

        let ready = StatusItemController.menuBarSpec(
            headline: headline, state: .ready(snap), showPercent: true, frame: frame)
        XCTAssertEqual(ready.percentText, "58%")
        XCTAssertEqual(ready.barFraction, 0.58)
        XCTAssertEqual(ready.color, .white) // menu bar is always white

        let hidden = StatusItemController.menuBarSpec(
            headline: headline, state: .ready(snap), showPercent: false, frame: frame)
        XCTAssertNil(hidden.percentText)
        XCTAssertEqual(hidden.barFraction, 0.58) // bar still shown when % hidden

        let expired = StatusItemController.menuBarSpec(
            headline: nil, state: .tokenExpired, showPercent: true, frame: frame)
        XCTAssertEqual(expired.percentText, "--")
        XCTAssertNil(expired.barFraction)
        XCTAssertEqual(expired.color, .white)
    }
}
