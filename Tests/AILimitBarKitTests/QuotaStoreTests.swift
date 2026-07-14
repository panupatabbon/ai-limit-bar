import XCTest
@testable import AILimitBarKit

@MainActor
final class QuotaStoreTests: XCTestCase {
    final class ScriptedProvider: QuotaProvider, @unchecked Sendable {
        let id = "mock"
        let displayName = "MOCK"
        var script: [Result<QuotaSnapshot, QuotaError>] = []
        func fetchSnapshot() async throws -> QuotaSnapshot {
            switch script.removeFirst() {
            case .success(let snap): return snap
            case .failure(let error): throw error
            }
        }
    }

    private func snapshot(session: Double = 10, weekly: Double = 58,
                          fetchedAt: Date = Date()) -> QuotaSnapshot {
        QuotaSnapshot(planName: "CLAUDE MAX", limits: [
            QuotaLimit(kind: .session, percentUsed: session,
                       resetsAt: Date().addingTimeInterval(3600), isActive: false),
            QuotaLimit(kind: .weeklyAll, percentUsed: weekly,
                       resetsAt: Date().addingTimeInterval(86_400), isActive: true),
            QuotaLimit(kind: .weeklyModel("Fable"), percentUsed: 38,
                       resetsAt: Date().addingTimeInterval(86_400), isActive: false),
        ], fetchedAt: fetchedAt)
    }

    func testLoadingToReady() async {
        let provider = ScriptedProvider()
        provider.script = [.success(snapshot())]
        let store = QuotaStore(provider: provider)
        XCTAssertEqual(store.state, .loading)
        await store.refresh()
        XCTAssertEqual(store.state, .ready(store.currentSnapshot!))
        XCTAssertEqual(store.currentSnapshot?.limits.count, 3)
    }

    func testTokenExpiredAndRecovery() async {
        let provider = ScriptedProvider()
        provider.script = [.failure(.tokenExpired), .success(snapshot())]
        let store = QuotaStore(provider: provider)
        await store.refresh()
        XCTAssertEqual(store.state, .tokenExpired)
        await store.refresh()
        guard case .ready = store.state else { return XCTFail("should recover") }
    }

    func testCredentialsMissing() async {
        let provider = ScriptedProvider()
        provider.script = [.failure(.credentialsMissing)]
        let store = QuotaStore(provider: provider)
        await store.refresh()
        XCTAssertEqual(store.state, .credentialsMissing)
    }

    func testNetworkErrorKeepsLastSnapshot() async {
        let provider = ScriptedProvider()
        let snap = snapshot()
        provider.script = [.success(snap), .failure(.network("down"))]
        let store = QuotaStore(provider: provider)
        await store.refresh()
        await store.refresh()
        XCTAssertEqual(store.state, .offline(last: snap))
        XCTAssertEqual(store.currentSnapshot, snap)
    }

    func testHeadlineSelection() async {
        let provider = ScriptedProvider()
        provider.script = [.success(snapshot(session: 10, weekly: 58))]
        let store = QuotaStore(provider: provider)
        await store.refresh()
        XCTAssertEqual(store.headlineLimit(pin: .auto)?.percentUsed, 58)   // max wins
        XCTAssertEqual(store.headlineLimit(pin: .session)?.kind, .session)
        XCTAssertEqual(store.headlineLimit(pin: .weekly)?.kind, .weeklyAll)
    }

    func testRefreshIfStaleSkipsFreshData() async {
        let provider = ScriptedProvider()
        provider.script = [.success(snapshot(fetchedAt: Date()))] // only ONE scripted result
        let store = QuotaStore(provider: provider)
        await store.refresh()
        await store.refreshIfStale(olderThan: 10) // fresh -> must NOT fetch again
        guard case .ready = store.state else { return XCTFail() }
    }

    func testRetryDelayBackoff() {
        XCTAssertEqual(QuotaStore.retryDelay(failureCount: 1), 5)
        XCTAssertEqual(QuotaStore.retryDelay(failureCount: 2), 10)
        XCTAssertEqual(QuotaStore.retryDelay(failureCount: 4), 40)
        XCTAssertEqual(QuotaStore.retryDelay(failureCount: 10), 300) // capped
    }
}
