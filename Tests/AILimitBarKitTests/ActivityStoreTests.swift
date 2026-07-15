import XCTest
@testable import AILimitBarKit

@MainActor
final class ActivityStoreTests: XCTestCase {
    private func makeStore(dir: URL, now: @escaping () -> Date) -> ActivityStore {
        ActivityStore(scanner: ActivityScanner(root: dir), now: now)
    }

    private func tempDir() throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("store-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    func testRefreshPopulatesSummary() async throws {
        let dir = try tempDir()
        try #"{"name":"Skill","input":{"skill":"alpha"}}"#
            .write(to: dir.appendingPathComponent("s.jsonl"), atomically: true, encoding: .utf8)
        let store = makeStore(dir: dir, now: { Date() })
        XCTAssertNil(store.summary)
        await store.refresh()
        XCTAssertEqual(store.summary?.topSkills.first, ActivityCount(name: "alpha", count: 1))
        XCTAssertFalse(store.isScanning)
    }

    func testStaleGate() async throws {
        let dir = try tempDir()
        var currentTime = Date(timeIntervalSince1970: 1_784_000_000)
        let store = makeStore(dir: dir, now: { currentTime })
        XCTAssertTrue(store.isStale(olderThan: 300)) // no summary yet
        await store.refresh()
        XCTAssertFalse(store.isStale(olderThan: 300)) // fresh
        currentTime = currentTime.addingTimeInterval(301)
        XCTAssertTrue(store.isStale(olderThan: 300)) // aged out
    }
}
