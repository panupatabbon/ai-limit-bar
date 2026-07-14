import XCTest
@testable import AILimitBarKit

final class AnthropicDateTests: XCTestCase {
    private var utc: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }

    func testParsesFractionalSeconds() throws {
        let date = try XCTUnwrap(AnthropicDate.parse("2026-07-14T23:00:00.212361+00:00"))
        let parts = utc.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
        XCTAssertEqual(parts.year, 2026)
        XCTAssertEqual(parts.month, 7)
        XCTAssertEqual(parts.day, 14)
        XCTAssertEqual(parts.hour, 23)
        XCTAssertEqual(parts.minute, 0)
        XCTAssertEqual(parts.second, 0)
    }

    func testParsesPlainISO8601() throws {
        let date = try XCTUnwrap(AnthropicDate.parse("2026-07-16T21:00:00+00:00"))
        let parts = utc.dateComponents([.day, .hour], from: date)
        XCTAssertEqual(parts.day, 16)
        XCTAssertEqual(parts.hour, 21)
    }

    func testRejectsGarbage() {
        XCTAssertNil(AnthropicDate.parse("not-a-date"))
        XCTAssertNil(AnthropicDate.parse(""))
    }
}
