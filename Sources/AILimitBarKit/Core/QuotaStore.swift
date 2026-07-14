import Foundation
import Observation

public enum HeadlinePin: String, CaseIterable, Sendable {
    case auto, session, weekly
}

@MainActor
@Observable
public final class QuotaStore {
    public enum State: Equatable {
        case loading
        case ready(QuotaSnapshot)
        case credentialsMissing
        case tokenExpired
        case offline(last: QuotaSnapshot?)
    }

    public private(set) var state: State = .loading

    private let provider: QuotaProvider
    private var lastGood: QuotaSnapshot?
    private var failureCount = 0
    private var pollTimer: Timer?
    private var retryTimer: Timer?

    public init(provider: QuotaProvider) {
        self.provider = provider
    }

    public var currentSnapshot: QuotaSnapshot? {
        switch state {
        case .ready(let snap): return snap
        case .offline(let last): return last
        default: return nil
        }
    }

    public func refresh() async {
        do {
            let snapshot = try await provider.fetchSnapshot()
            lastGood = snapshot
            failureCount = 0
            retryTimer?.invalidate()
            state = .ready(snapshot)
        } catch let error as QuotaError {
            switch error {
            case .credentialsMissing:
                state = .credentialsMissing
            case .tokenExpired:
                state = .tokenExpired
            case .network, .badResponse:
                failureCount += 1
                state = .offline(last: lastGood)
                scheduleRetry()
            }
        } catch {
            failureCount += 1
            state = .offline(last: lastGood)
            scheduleRetry()
        }
    }

    public func refreshIfStale(olderThan seconds: TimeInterval = 10) async {
        if let snap = currentSnapshot,
           Date().timeIntervalSince(snap.fetchedAt) < seconds,
           case .ready = state {
            return
        }
        await refresh()
    }

    public func startPolling(interval: TimeInterval = 60) {
        stopPolling()
        pollTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in await self?.refresh() }
        }
        Task { await refresh() }
    }

    public func stopPolling() {
        pollTimer?.invalidate()
        pollTimer = nil
        retryTimer?.invalidate()
        retryTimer = nil
    }

    private func scheduleRetry() {
        retryTimer?.invalidate()
        let delay = Self.retryDelay(failureCount: failureCount)
        retryTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            Task { @MainActor in await self?.refresh() }
        }
    }

    public func headlineLimit(pin: HeadlinePin) -> QuotaLimit? {
        guard let limits = currentSnapshot?.limits, !limits.isEmpty else { return nil }
        switch pin {
        case .auto:
            return limits.max { $0.percentUsed < $1.percentUsed }
        case .session:
            return limits.first { $0.kind == .session } ?? limits.first
        case .weekly:
            return limits.first { $0.kind == .weeklyAll } ?? limits.first
        }
    }

    public static func retryDelay(failureCount: Int) -> TimeInterval {
        min(5 * pow(2, Double(max(failureCount, 1) - 1)), 300)
    }
}
