import Foundation
import Observation

@MainActor
@Observable
public final class ActivityStore {
    public private(set) var summary: ActivitySummary?
    public private(set) var isScanning = false

    private let scanner: ActivityScanner
    private let now: () -> Date
    private var lastRefreshed: Date?

    public init(scanner: ActivityScanner = ActivityScanner(),
                now: @escaping () -> Date = { Date() }) {
        self.scanner = scanner
        self.now = now
    }

    public func isStale(olderThan seconds: TimeInterval) -> Bool {
        guard let lastRefreshed else { return true }
        return now().timeIntervalSince(lastRefreshed) >= seconds
    }

    public func refresh() async {
        guard !isScanning else { return }
        isScanning = true
        let scanner = self.scanner
        let result = await Task.detached(priority: .utility) { scanner.scan() }.value
        summary = result
        lastRefreshed = now()
        isScanning = false
    }

    public func refreshIfStale(olderThan seconds: TimeInterval = 300) {
        guard isStale(olderThan: seconds) else { return }
        Task { await refresh() }
    }
}
