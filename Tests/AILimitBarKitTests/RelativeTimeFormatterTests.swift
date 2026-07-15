import XCTest
@testable import AILimitBarKit

final class RelativeTimeFormatterTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_784_000_000)
    private func ago(_ s: TimeInterval) -> String {
        RelativeTimeFormatter.string(since: now.addingTimeInterval(-s), now: now)
    }

    func testRelativeStrings() {
        XCTAssertEqual(ago(0), "JUST NOW")
        XCTAssertEqual(ago(59), "JUST NOW")
        XCTAssertEqual(ago(60), "1M AGO")
        XCTAssertEqual(ago(59 * 60), "59M AGO")
        XCTAssertEqual(ago(60 * 60), "1H AGO")
        XCTAssertEqual(ago(65 * 60), "1H 5M AGO")
        XCTAssertEqual(ago(2 * 3600), "2H AGO")
        XCTAssertEqual(ago(-5), "JUST NOW") // clock skew guard
    }
}
