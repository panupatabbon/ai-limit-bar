import XCTest
@testable import AILimitBarKit

final class ProviderCatalogTests: XCTestCase {
    func testFixedOrderAndCompleteness() {
        XCTAssertEqual(ProviderID.allCases, [.claude, .codex, .gemini, .cursor])
        XCTAssertEqual(ProviderCatalog.all.map(\.id), ProviderID.allCases)
    }

    func testDisplayAndCLINames() {
        XCTAssertEqual(ProviderCatalog.descriptor(for: .claude).cliName, "Claude Code")
        XCTAssertEqual(ProviderCatalog.descriptor(for: .codex).cliName, "Codex CLI")
        XCTAssertEqual(ProviderCatalog.descriptor(for: .gemini).cliName, "Gemini CLI")
        XCTAssertEqual(ProviderCatalog.descriptor(for: .cursor).displayName, "Cursor")
    }

    func testAvailabilityMatchesFactory() {
        // The catalog's availability flag and the factory must never diverge.
        for descriptor in ProviderCatalog.all {
            let hasProvider = ProviderCatalog.makeProvider(for: descriptor.id) != nil
            XCTAssertEqual(descriptor.availability == .live, hasProvider,
                           "\(descriptor.id) availability out of sync with factory")
        }
    }

    func testLiveProviders() {
        XCTAssertEqual(ProviderCatalog.liveIDs, [.claude, .codex])
    }
}
