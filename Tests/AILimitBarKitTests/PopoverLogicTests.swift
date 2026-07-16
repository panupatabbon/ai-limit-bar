import XCTest
@testable import AILimitBarKit

@MainActor
final class PopoverLogicTests: XCTestCase {
    func testVisibleLimitsFiltering() {
        let snapshot = QuotaSnapshot(planName: "CLAUDE MAX", limits: [
            QuotaLimit(kind: .session, percentUsed: 10, resetsAt: Date(), isActive: false),
            QuotaLimit(kind: .weeklyAll, percentUsed: 58, resetsAt: Date(), isActive: true),
            QuotaLimit(kind: .weeklyModel("Fable"), percentUsed: 38, resetsAt: Date(), isActive: false),
        ], fetchedAt: Date())

        let defaults = UserDefaults(suiteName: "PopoverLogicTests")!
        defaults.removePersistentDomain(forName: "PopoverLogicTests")
        let settings = AppSettings(defaults: defaults)

        XCTAssertEqual(QuotaPopoverView.visibleLimits(snapshot, settings: settings).count, 3)
        settings.showWeeklyModels = false
        XCTAssertEqual(QuotaPopoverView.visibleLimits(snapshot, settings: settings).count, 2)
        settings.showSession = false
        XCTAssertEqual(QuotaPopoverView.visibleLimits(snapshot, settings: settings).map(\.kind), [.weeklyAll])
        XCTAssertEqual(QuotaPopoverView.visibleLimits(nil, settings: settings), [])
    }

    func testNoDataHintNamesTheCause() {
        // Self-inflicted (every limit toggled off) must not read like a fetch failure.
        XCTAssertEqual(QuotaPopoverView.noDataHint(allHidden: true),
                       "All limits are hidden. Turn one back on in Settings.")
        XCTAssertEqual(QuotaPopoverView.noDataHint(allHidden: false),
                       "Your plan reported no limits yet. Try again after using Claude.")
    }
}
