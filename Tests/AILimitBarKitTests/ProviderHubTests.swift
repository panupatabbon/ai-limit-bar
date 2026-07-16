import XCTest
@testable import AILimitBarKit

private struct FakeProvider: QuotaProvider {
    let id = "fake"
    let displayName = "Fake"
    let percent: Double
    func fetchSnapshot() async throws -> QuotaSnapshot {
        QuotaSnapshot(planName: "FAKE",
                      limits: [QuotaLimit(kind: .session, percentUsed: percent,
                                          resetsAt: Date().addingTimeInterval(3600), isActive: true)],
                      fetchedAt: Date())
    }
}

@MainActor
final class ProviderHubTests: XCTestCase {
    private func makeHub(percents: [ProviderID: Double]) -> ProviderHub {
        ProviderHub { id in
            guard let percent = percents[id] else { return nil }
            return QuotaStore(provider: FakeProvider(percent: percent))
        }
    }

    func testSyncCreatesAndRemovesStores() {
        let hub = makeHub(percents: [.claude: 10, .codex: 20])
        hub.sync(enabled: [.claude, .codex, .cursor])
        // .cursor has no factory result (coming soon) — no store.
        XCTAssertEqual(hub.orderedLive, [.claude, .codex])
        XCTAssertEqual(hub.orderedEnabled, [.claude, .codex, .cursor])
        XCTAssertNotNil(hub.store(for: .claude))
        XCTAssertNil(hub.store(for: .cursor))

        hub.sync(enabled: [.claude])
        XCTAssertEqual(hub.orderedLive, [.claude])
        XCTAssertNil(hub.store(for: .codex))
    }

    func testOrderedFollowsFixedOrder() {
        let hub = makeHub(percents: [.claude: 10, .gemini: 10])
        hub.sync(enabled: [.gemini, .claude])
        XCTAssertEqual(hub.orderedEnabled, [.claude, .gemini])
    }

    func testHottestPicksHighestSeverityThenOrder() async {
        let hub = makeHub(percents: [.claude: 70, .codex: 90, .gemini: 65])
        hub.sync(enabled: [.claude, .codex, .gemini])
        for id in hub.orderedLive { await hub.store(for: id)!.refresh() }
        XCTAssertEqual(hub.hottest(pin: .auto), .codex)          // critical beats warn
    }

    func testHottestTieBreaksByOrderAndNilWhenAllOK() async {
        let warmTie = makeHub(percents: [.claude: 70, .codex: 72])
        warmTie.sync(enabled: [.claude, .codex])
        for id in warmTie.orderedLive { await warmTie.store(for: id)!.refresh() }
        XCTAssertEqual(warmTie.hottest(pin: .auto), .claude)     // both warn → first

        let calm = makeHub(percents: [.claude: 10, .codex: 20])
        calm.sync(enabled: [.claude, .codex])
        for id in calm.orderedLive { await calm.store(for: id)!.refresh() }
        XCTAssertNil(calm.hottest(pin: .auto))                   // nobody ≥ warn
    }
}
