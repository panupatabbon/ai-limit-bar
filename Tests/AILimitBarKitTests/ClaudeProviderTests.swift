import XCTest
@testable import AILimitBarKit

final class ClaudeProviderTests: XCTestCase {
    struct StubSource: CredentialsSource {
        let creds: ClaudeCredentials?
        func load() -> ClaudeCredentials? { creds }
    }

    final class CountingSource: CredentialsSource, @unchecked Sendable {
        private(set) var loadCount = 0
        let creds: ClaudeCredentials?
        init(creds: ClaudeCredentials?) { self.creds = creds }
        func load() -> ClaudeCredentials? {
            loadCount += 1
            return creds
        }
    }

    private func provider(creds: ClaudeCredentials?,
                          respond: @escaping (URLRequest) throws -> (HTTPURLResponse, Data),
                          now: Date = Date(timeIntervalSince1970: 1_784_055_124)) -> ClaudeProvider {
        MockURLProtocol.handler = respond
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        return ClaudeProvider(
            resolver: CredentialsResolver(sources: [StubSource(creds: creds)]),
            client: ClaudeUsageClient(session: URLSession(configuration: config)),
            now: { now })
    }

    private let validCreds = ClaudeCredentials(
        accessToken: "tok",
        expiresAt: Date(timeIntervalSince1970: 1_784_078_801), // future vs injected now
        subscriptionType: "max")

    func testFetchSnapshotSuccess() async throws {
        let p = provider(creds: validCreds, respond: { request in
            (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
             Data(UsageResponseTests.fullFixture.utf8))
        })
        let snapshot = try await p.fetchSnapshot()
        XCTAssertEqual(snapshot.planName, "CLAUDE MAX")
        XCTAssertEqual(snapshot.limits.count, 3)
    }

    func testMissingCredentialsThrows() async {
        let p = provider(creds: nil, respond: { _ in fatalError("must not be called") })
        do { _ = try await p.fetchSnapshot(); XCTFail("expected throw") }
        catch let e as QuotaError { XCTAssertEqual(e, .credentialsMissing) }
        catch { XCTFail("wrong error \(error)") }
    }

    func testLocallyExpiredTokenThrowsWithoutNetworkCall() async {
        let expired = ClaudeCredentials(
            accessToken: "tok",
            expiresAt: Date(timeIntervalSince1970: 1_784_000_000), // past vs injected now
            subscriptionType: "max")
        let p = provider(creds: expired, respond: { _ in fatalError("must not be called") })
        do { _ = try await p.fetchSnapshot(); XCTFail("expected throw") }
        catch let e as QuotaError { XCTAssertEqual(e, .tokenExpired) }
        catch { XCTFail("wrong error \(error)") }
    }

    func testCredentialsCachedAcrossConsecutivePolls() async throws {
        let source = CountingSource(creds: validCreds)
        MockURLProtocol.handler = { request in
            (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
             Data(UsageResponseTests.fullFixture.utf8))
        }
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let p = ClaudeProvider(
            resolver: CredentialsResolver(sources: [source]),
            client: ClaudeUsageClient(session: URLSession(configuration: config)),
            now: { Date(timeIntervalSince1970: 1_784_055_124) })

        _ = try await p.fetchSnapshot()
        _ = try await p.fetchSnapshot()
        XCTAssertEqual(source.loadCount, 1)
    }

    func testCredentialsReResolvedAfterServerTokenExpired() async throws {
        let source = CountingSource(creds: validCreds)
        var requestCount = 0
        MockURLProtocol.handler = { request in
            requestCount += 1
            if requestCount == 1 {
                return (HTTPURLResponse(url: request.url!, statusCode: 401, httpVersion: nil, headerFields: nil)!,
                        Data())
            }
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
                    Data(UsageResponseTests.fullFixture.utf8))
        }
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let p = ClaudeProvider(
            resolver: CredentialsResolver(sources: [source]),
            client: ClaudeUsageClient(session: URLSession(configuration: config)),
            now: { Date(timeIntervalSince1970: 1_784_055_124) })

        do { _ = try await p.fetchSnapshot(); XCTFail("expected throw") }
        catch let e as QuotaError { XCTAssertEqual(e, .tokenExpired) }
        XCTAssertEqual(source.loadCount, 1)

        _ = try await p.fetchSnapshot()
        XCTAssertEqual(source.loadCount, 2)
    }

    func testPlanNames() {
        XCTAssertEqual(ClaudeProvider.planName(for: "max"), "CLAUDE MAX")
        XCTAssertEqual(ClaudeProvider.planName(for: "pro"), "CLAUDE PRO")
        XCTAssertEqual(ClaudeProvider.planName(for: "team"), "CLAUDE TEAM")
        XCTAssertEqual(ClaudeProvider.planName(for: "enterprise"), "CLAUDE ENTERPRISE")
        XCTAssertEqual(ClaudeProvider.planName(for: nil), "CLAUDE")
        XCTAssertEqual(ClaudeProvider.planName(for: "weird"), "CLAUDE")
    }
}
