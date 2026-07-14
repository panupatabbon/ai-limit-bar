import XCTest
@testable import AILimitBarKit

final class UIComponentLogicTests: XCTestCase {
    func testFilledSegments() {
        XCTAssertEqual(PixelProgressBar.filledSegments(percent: 0, total: 12), 0)
        XCTAssertEqual(PixelProgressBar.filledSegments(percent: 50, total: 12), 6)
        XCTAssertEqual(PixelProgressBar.filledSegments(percent: 100, total: 12), 12)
        XCTAssertEqual(PixelProgressBar.filledSegments(percent: 120, total: 12), 12) // clamped
        XCTAssertEqual(PixelProgressBar.filledSegments(percent: -5, total: 12), 0)   // clamped
        XCTAssertEqual(PixelProgressBar.filledSegments(percent: 4, total: 12), 1)    // >0 shows at least 1
    }

    func testKindLabels() {
        XCTAssertEqual(LimitRowView.kindLabel(.session), "SESSION")
        XCTAssertEqual(LimitRowView.kindLabel(.weeklyAll), "WEEKLY ALL")
        XCTAssertEqual(LimitRowView.kindLabel(.weeklyModel("Fable")), "WEEKLY FABLE")
    }

    func testResetLabels() {
        let now = Date(timeIntervalSince1970: 1_784_000_000)
        let session = QuotaLimit(kind: .session, percentUsed: 10,
                                 resetsAt: now.addingTimeInterval(2 * 3600 + 14 * 60), isActive: false)
        XCTAssertEqual(LimitRowView.resetLabel(for: session, now: now), "RESET 2H 14M")

        let weekly = QuotaLimit(kind: .weeklyAll, percentUsed: 58,
                                resetsAt: Date(timeIntervalSince1970: 1_784_235_600), isActive: true)
        XCTAssertTrue(LimitRowView.resetLabel(for: weekly, now: now).hasPrefix("RESET "))
    }
}
