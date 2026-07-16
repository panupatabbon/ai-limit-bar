import XCTest
@testable import AILimitBarKit

@MainActor
final class AppSettingsTests: XCTestCase {
    private var defaults: UserDefaults!
    private let suite = "AppSettingsTests"

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: suite)
        defaults.removePersistentDomain(forName: suite)
    }

    func testDefaults() {
        let s = AppSettings(defaults: defaults)
        XCTAssertTrue(s.showPercentInMenuBar)
        XCTAssertEqual(s.headlinePin, .auto)
        XCTAssertTrue(s.showSession)
        XCTAssertTrue(s.showWeeklyAll)
        XCTAssertTrue(s.showWeeklyModels)
        XCTAssertFalse(s.compactRows)
    }

    func testPersistsAcrossInstances() {
        let s1 = AppSettings(defaults: defaults)
        s1.showPercentInMenuBar = false
        s1.headlinePin = .session
        s1.showWeeklyModels = false
        s1.compactRows = true

        let s2 = AppSettings(defaults: defaults)
        XCTAssertFalse(s2.showPercentInMenuBar)
        XCTAssertEqual(s2.headlinePin, .session)
        XCTAssertFalse(s2.showWeeklyModels)
        XCTAssertTrue(s2.compactRows)
    }

    func testSelectedTabDefaultsToClaudeAndDoesNotPersist() {
        let s1 = AppSettings(defaults: defaults)
        XCTAssertEqual(s1.selectedTab, .claude)
        // While Gemini is a placeholder the tab must never survive a relaunch:
        // reopening onto the coming-soon screen breaks the primary glance.
        s1.selectedTab = .gemini
        XCTAssertEqual(AppSettings(defaults: defaults).selectedTab, .claude)
    }

    func testVisibility() {
        let s = AppSettings(defaults: defaults)
        s.showSession = false
        XCTAssertFalse(s.isVisible(.session))
        XCTAssertTrue(s.isVisible(.weeklyAll))
        s.showWeeklyModels = false
        XCTAssertFalse(s.isVisible(.weeklyModel("Fable")))
    }
}
