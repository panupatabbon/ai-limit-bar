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
        XCTAssertEqual(s.language, .en)
        XCTAssertEqual(s.theme, .system)
        XCTAssertTrue(s.showPercentInMenuBar)
        XCTAssertEqual(s.headlinePin, .auto)
        XCTAssertTrue(s.showSession)
        XCTAssertTrue(s.showWeeklyAll)
        XCTAssertTrue(s.showWeeklyModels)
        XCTAssertFalse(s.compactRows)
        XCTAssertEqual(s.avatar, .boo)
    }

    func testPersistsAcrossInstances() {
        let s1 = AppSettings(defaults: defaults)
        s1.language = .th
        s1.theme = .dark
        s1.showPercentInMenuBar = false
        s1.headlinePin = .session
        s1.showWeeklyModels = false
        s1.compactRows = true
        s1.avatar = .bot

        let s2 = AppSettings(defaults: defaults)
        XCTAssertEqual(s2.language, .th)
        XCTAssertEqual(s2.theme, .dark)
        XCTAssertFalse(s2.showPercentInMenuBar)
        XCTAssertEqual(s2.headlinePin, .session)
        XCTAssertFalse(s2.showWeeklyModels)
        XCTAssertTrue(s2.compactRows)
        XCTAssertEqual(s2.avatar, .bot)
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
