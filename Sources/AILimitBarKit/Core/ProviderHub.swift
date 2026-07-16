import Foundation
import Observation

/// Owns one QuotaStore per enabled *live* provider. Disable = stop polling
/// and drop the store, not hide. Coming-soon providers never get a store.
@MainActor
@Observable
public final class ProviderHub {
    public private(set) var stores: [ProviderID: QuotaStore] = [:]
    private var enabled: Set<ProviderID> = []
    private let storeFactory: (ProviderID) -> QuotaStore?

    public init(storeFactory: @escaping (ProviderID) -> QuotaStore? = ProviderHub.liveStore(for:)) {
        self.storeFactory = storeFactory
    }

    public static func liveStore(for id: ProviderID) -> QuotaStore? {
        guard let provider = ProviderCatalog.makeProvider(for: id) else { return nil }
        let store = QuotaStore(provider: provider)
        store.startPolling(interval: 60)
        return store
    }

    public func sync(enabled: Set<ProviderID>) {
        guard enabled != self.enabled else { return }
        self.enabled = enabled
        for id in ProviderID.allCases {
            if enabled.contains(id), stores[id] == nil, let store = storeFactory(id) {
                stores[id] = store
            } else if !enabled.contains(id), let store = stores[id] {
                store.stopPolling()
                stores[id] = nil
            }
        }
    }

    public var orderedEnabled: [ProviderID] {
        ProviderID.allCases.filter { enabled.contains($0) }
    }

    public var orderedLive: [ProviderID] {
        ProviderID.allCases.filter { stores[$0] != nil }
    }

    public func store(for id: ProviderID) -> QuotaStore? { stores[id] }

    /// The provider that most needs attention: highest severity ≥ warn,
    /// ties broken by fixed order. Nil when everyone is ok.
    public func hottest(pin: HeadlinePin) -> ProviderID? {
        var best: (id: ProviderID, rank: Int)?
        for id in orderedLive {
            guard let headline = stores[id]?.headlineLimit(pin: pin) else { continue }
            let rank: Int
            switch Severity(percent: headline.percentUsed) {
            case .ok: continue
            case .warn: rank = 1
            case .critical: rank = 2
            }
            if rank > (best?.rank ?? 0) { best = (id, rank) }
        }
        return best?.id
    }
}
