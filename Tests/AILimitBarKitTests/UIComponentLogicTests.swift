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

    func testBarGeometrySpansDeclaredWidth() {
        // The popover derives its width from this: cells + gaps + padding.
        let cells = CGFloat(PixelProgressBar.totalSegments) * PixelProgressBar.segmentSize.width
        let gaps = CGFloat(PixelProgressBar.totalSegments - 1) * 2
        XCTAssertEqual(cells + gaps + 4, PixelProgressBar.totalWidth)
    }

    func testPixelTracking() {
        // Tracking is half a pixel cell (6.25%), so it stays on the 8×8 grid.
        XCTAssertEqual(PixelFont.tracking(forSize: 8), 0.5)
        XCTAssertEqual(PixelFont.tracking(forSize: 16), 1.0)
        XCTAssertEqual(PixelFont.tracking(forSize: 6), 0.375)
    }

    func testPulsedSegment() {
        // Only critical pulses, and it's always the leading filled segment.
        XCTAssertNil(PixelProgressBar.pulsedSegment(percent: 50, total: 12))
        XCTAssertNil(PixelProgressBar.pulsedSegment(percent: 80, total: 12))
        XCTAssertEqual(PixelProgressBar.pulsedSegment(percent: 90, total: 12), 10)
        XCTAssertEqual(PixelProgressBar.pulsedSegment(percent: 100, total: 12), 11)
    }

    func testKindLabels() {
        XCTAssertEqual(LimitRowView.kindLabel(.session), "SESSION")
        // "WEEKLY ALL" read like a truncated label to first-timers.
        XCTAssertEqual(LimitRowView.kindLabel(.weeklyAll), "WEEKLY TOTAL")
        XCTAssertEqual(LimitRowView.kindLabel(.weeklyModel("Fable")), "WEEKLY FABLE")
    }

    func testShowsReset() {
        // Compact mode may hide reset — except for the binding limit AND any
        // limit from warn upward: the countdown is the answer at high stakes.
        XCTAssertTrue(LimitRowView.showsReset(compact: false, isActive: false, severity: .ok))
        XCTAssertTrue(LimitRowView.showsReset(compact: false, isActive: true, severity: .ok))
        XCTAssertTrue(LimitRowView.showsReset(compact: true, isActive: true, severity: .ok))
        XCTAssertFalse(LimitRowView.showsReset(compact: true, isActive: false, severity: .ok))
        XCTAssertTrue(LimitRowView.showsReset(compact: true, isActive: false, severity: .warn))
        XCTAssertTrue(LimitRowView.showsReset(compact: true, isActive: false, severity: .critical))
    }

    func testResetIsPromotedFromWarnUpward() {
        XCTAssertFalse(LimitRowView.resetIsProminent(severity: .ok))
        XCTAssertTrue(LimitRowView.resetIsProminent(severity: .warn))
        XCTAssertTrue(LimitRowView.resetIsProminent(severity: .critical))
    }

    func testAccessibilityDescription() {
        let now = Date(timeIntervalSince1970: 1_784_000_000)

        let session = QuotaLimit(kind: .session, percentUsed: 58,
                                 resetsAt: now.addingTimeInterval(2 * 3600 + 14 * 60), isActive: true)
        XCTAssertEqual(
            LimitRowView.accessibilityDescription(for: session, now: now),
            "Session, 58 percent used, resets in 2 hours 14 minutes, you'll hit this limit first")

        // From warn upward the severity is spoken too — thresholds must not
        // be hue-only knowledge.
        let warned = QuotaLimit(kind: .session, percentUsed: 70,
                                resetsAt: now.addingTimeInterval(3600), isActive: false)
        XCTAssertEqual(
            LimitRowView.accessibilityDescription(for: warned, now: now),
            "Session, 70 percent used, warning, resets in 1 hour")

        let oneMinute = QuotaLimit(kind: .session, percentUsed: 99,
                                   resetsAt: now.addingTimeInterval(90), isActive: false)
        XCTAssertEqual(
            LimitRowView.accessibilityDescription(for: oneMinute, now: now),
            "Session, 99 percent used, critical, resets in 1 minute")

        let due = QuotaLimit(kind: .session, percentUsed: 100,
                             resetsAt: now, isActive: false)
        XCTAssertEqual(
            LimitRowView.accessibilityDescription(for: due, now: now),
            "Session, 100 percent used, critical, resets now")

        let weekly = QuotaLimit(kind: .weeklyAll, percentUsed: 90,
                                resetsAt: Date(timeIntervalSince1970: 1_784_235_600), isActive: false)
        let spoken = LimitRowView.accessibilityDescription(for: weekly, now: now)
        XCTAssertTrue(spoken.hasPrefix("Weekly Total, 90 percent used, critical, resets "),
                      "got: \(spoken)")
        // Spoken form mirrors the visible countdown so VoiceOver stays in sync.
        XCTAssertTrue(spoken.hasSuffix(", in 2 days 17 hours"),
                      "spoken weekly should append the countdown: \(spoken)")
        XCTAssertFalse(spoken.contains("RESET"), "spoken form must not reuse the pixel label")
    }

    func testSpokenWeeklyResetFollowsLocaleClock() {
        // 21:00 UTC — speech must follow the user's clock, unlike the pixel
        // label which stays 24h as part of the game look.
        let date = Date(timeIntervalSince1970: 1_784_235_600)
        let utc = TimeZone(identifier: "UTC")!
        let us = ResetFormatter.spokenWeeklyReset(date, timeZone: utc,
                                                  locale: Locale(identifier: "en_US"))
        XCTAssertTrue(us.hasPrefix("resets "), "got: \(us)")
        XCTAssertTrue(us.contains("PM"), "en_US speech should use 12-hour clock: \(us)")
        let de = ResetFormatter.spokenWeeklyReset(date, timeZone: utc,
                                                  locale: Locale(identifier: "de_DE"))
        XCTAssertFalse(de.contains("AM") || de.contains("PM"),
                       "de_DE speech should use 24-hour clock: \(de)")
    }

    func testResetLabels() {
        let now = Date(timeIntervalSince1970: 1_784_000_000)
        let session = QuotaLimit(kind: .session, percentUsed: 10,
                                 resetsAt: now.addingTimeInterval(2 * 3600 + 14 * 60), isActive: false)
        XCTAssertEqual(LimitRowView.resetLabel(for: session, now: now), "RESET 2H 14M")

        // Weekly keeps the absolute date and appends a live countdown.
        let weekly = QuotaLimit(kind: .weeklyAll, percentUsed: 58,
                                resetsAt: now.addingTimeInterval(3 * 86400 + 5 * 3600), isActive: true)
        let weeklyLabel = LimitRowView.resetLabel(for: weekly, now: now)
        XCTAssertTrue(weeklyLabel.hasPrefix("RESET "), "got: \(weeklyLabel)")
        XCTAssertTrue(weeklyLabel.hasSuffix(" · 3D 5H"),
                      "weekly label keeps the date, then ' · <countdown>': \(weeklyLabel)")
    }
}
