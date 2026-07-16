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
        // "!" = needs the user (sign in / renew); "--" = just no data yet.
        XCTAssertEqual(StatusItemController.menuBarTitle(
            headline: nil, state: .tokenExpired, showPercent: true), "!")
        XCTAssertEqual(StatusItemController.menuBarTitle(
            headline: nil, state: .credentialsMissing, showPercent: true), "!")
        XCTAssertEqual(StatusItemController.menuBarTitle(
            headline: nil, state: .loading, showPercent: true), "--")
        // Offline with stale data still shows the stale number.
        XCTAssertEqual(StatusItemController.menuBarTitle(
            headline: headline, state: .offline(last: snap), showPercent: true), "58%")
    }

    func testMenuBarSpec() {
        let frame = SpriteLibrary.sprite(forProvider: "claude").frames[0]

        let ready = StatusItemController.menuBarSpec(
            headline: headline, state: .ready(snap), showPercent: true, frame: frame,
            darkAppearance: true)
        XCTAssertEqual(ready.percentText, "58%")
        XCTAssertEqual(ready.barFraction, 0.58)
        // 58% is .ok — the whole item wears the severity color (DESIGN.md §Menu Bar Item).
        XCTAssertEqual(ready.color, RetroTheme.menuBarColor(for: .ok, darkAppearance: true))

        let critical = StatusItemController.menuBarSpec(
            headline: QuotaLimit(kind: .weeklyAll, percentUsed: 90,
                                 resetsAt: Date(), isActive: true),
            state: .ready(snap), showPercent: true, frame: frame,
            darkAppearance: true)
        XCTAssertEqual(critical.color, RetroTheme.menuBarColor(for: .critical, darkAppearance: true))

        let hidden = StatusItemController.menuBarSpec(
            headline: headline, state: .ready(snap), showPercent: false, frame: frame,
            darkAppearance: true)
        XCTAssertNil(hidden.percentText)
        XCTAssertEqual(hidden.barFraction, 0.58) // bar still shown when % hidden

        let expired = StatusItemController.menuBarSpec(
            headline: nil, state: .tokenExpired, showPercent: true, frame: frame,
            darkAppearance: true)
        XCTAssertEqual(expired.percentText, "!")
        XCTAssertNil(expired.barFraction)
        // "!" wears Warning Gold — "needs you" should read faster than neutral.
        XCTAssertEqual(expired.color, RetroTheme.menuBarColor(for: .warn, darkAppearance: true))

        let loading = StatusItemController.menuBarSpec(
            headline: nil, state: .loading, showPercent: true, frame: frame,
            darkAppearance: true)
        XCTAssertEqual(loading.color, .white) // no data yet — stays neutral
    }

    func testStatusDescription() {
        let now = Date(timeIntervalSince1970: 1_784_000_000)
        let session = QuotaLimit(kind: .session, percentUsed: 58,
                                 resetsAt: now.addingTimeInterval(2 * 3600 + 14 * 60), isActive: true)

        // The status item speaks: same string feeds toolTip and VoiceOver.
        XCTAssertEqual(
            StatusItemController.statusDescription(headline: session, state: .ready(snap), now: now),
            "Session 58% used — resets in 2 hours 14 minutes")
        XCTAssertEqual(
            StatusItemController.statusDescription(headline: session, state: .offline(last: snap), now: now),
            "Session 58% used — resets in 2 hours 14 minutes (offline)")
        XCTAssertEqual(
            StatusItemController.statusDescription(headline: nil, state: .credentialsMissing, now: now),
            "AI Limit Bar — sign in to Claude Code to see quota")
        XCTAssertEqual(
            StatusItemController.statusDescription(headline: nil, state: .tokenExpired, now: now),
            "AI Limit Bar — token expired, use Claude Code once to renew")
        XCTAssertEqual(
            StatusItemController.statusDescription(headline: nil, state: .loading, now: now),
            "AI Limit Bar — loading quota")
        XCTAssertEqual(
            StatusItemController.statusDescription(headline: nil, state: .ready(snap), now: now),
            "AI Limit Bar — no quota data")
    }

    func testMenuBarSpecAdaptsToLightAppearance() {
        let frame = SpriteLibrary.sprite(forProvider: "claude").frames[0]

        // Light menu bar gets darker same-hue severity variants, not the neons.
        let ready = StatusItemController.menuBarSpec(
            headline: headline, state: .ready(snap), showPercent: true, frame: frame,
            darkAppearance: false)
        XCTAssertEqual(ready.color, RetroTheme.menuBarColor(for: .ok, darkAppearance: false))
        XCTAssertNotEqual(ready.color, RetroTheme.menuBarColor(for: .ok, darkAppearance: true))

        // Neutral fallback flips to black so "--" never vanishes on white.
        let loading = StatusItemController.menuBarSpec(
            headline: nil, state: .loading, showPercent: true, frame: frame,
            darkAppearance: false)
        XCTAssertEqual(loading.color, .black)

        // "!" keeps its warn identity in the light variant too.
        let expired = StatusItemController.menuBarSpec(
            headline: nil, state: .tokenExpired, showPercent: true, frame: frame,
            darkAppearance: false)
        XCTAssertEqual(expired.color, RetroTheme.menuBarColor(for: .warn, darkAppearance: false))
    }

    func testMenuBarColorDarkVariantsMatchPalette() {
        // Dark menu bar wears the palette trio unchanged.
        XCTAssertEqual(RetroTheme.menuBarColor(for: .ok, darkAppearance: true),
                       NSColor(hex: 0x00D9FF))
        XCTAssertEqual(RetroTheme.menuBarColor(for: .warn, darkAppearance: true),
                       NSColor(hex: 0xFFC300))
        XCTAssertEqual(RetroTheme.menuBarColor(for: .critical, darkAppearance: true),
                       NSColor(hex: 0xFF5C5C))
    }
}
