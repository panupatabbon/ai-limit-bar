import XCTest
@testable import AILimitBarKit

final class ResetFormatterTests: XCTestCase {
    func testSessionCountdown() {
        let now = Date(timeIntervalSince1970: 1_784_000_000)
        XCTAssertEqual(
            ResetFormatter.sessionCountdown(until: now.addingTimeInterval(2 * 3600 + 14 * 60), from: now),
            "2H 14M")
        XCTAssertEqual(
            ResetFormatter.sessionCountdown(until: now.addingTimeInterval(14 * 60), from: now),
            "14M")
        XCTAssertEqual(
            ResetFormatter.sessionCountdown(until: now.addingTimeInterval(30), from: now),
            "<1M")
        XCTAssertEqual(
            ResetFormatter.sessionCountdown(until: now.addingTimeInterval(-5), from: now),
            "NOW")
    }

    func testWeeklyCountdown() {
        // Weekly windows can be days out, so the countdown carries a day
        // field; below a day it falls back to the session H/M shorthand.
        let now = Date(timeIntervalSince1970: 1_784_000_000)
        XCTAssertEqual(
            ResetFormatter.weeklyCountdown(until: now.addingTimeInterval(3 * 86400 + 5 * 3600), from: now),
            "3D 5H")
        XCTAssertEqual(
            ResetFormatter.weeklyCountdown(until: now.addingTimeInterval(5 * 3600 + 30 * 60), from: now),
            "5H 30M")
        XCTAssertEqual(
            ResetFormatter.weeklyCountdown(until: now.addingTimeInterval(45 * 60), from: now),
            "45M")
        XCTAssertEqual(
            ResetFormatter.weeklyCountdown(until: now.addingTimeInterval(30), from: now),
            "<1M")
        XCTAssertEqual(
            ResetFormatter.weeklyCountdown(until: now.addingTimeInterval(-5), from: now),
            "NOW")
    }

    func testWeeklyReset() {
        // 2026-07-16T21:00:00Z is a Thursday; in UTC that renders THU 21:00.
        let date = Date(timeIntervalSince1970: 1_784_235_600)
        let utc = TimeZone(identifier: "UTC")!
        XCTAssertEqual(ResetFormatter.weeklyReset(date, timeZone: utc), "THU 21:00")
    }
}
