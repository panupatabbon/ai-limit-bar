import XCTest
@testable import AILimitBarKit

final class CodexProviderTests: XCTestCase {
    // Redacted fixture from docs/superpowers/research/2026-07-17-codex-quota.md.
    // PII fields (user_id/account_id/email) are omitted here — the adapter
    // never declares them in its Decodable model, so a decode test doesn't
    // need them present to prove they're ignored.
    static let fullFixture = #"""
    {
      "plan_type": "plus",
      "rate_limit": {
        "allowed": true,
        "limit_reached": false,
        "primary_window": {
          "used_percent": 0,
          "limit_window_seconds": 604800,
          "reset_after_seconds": 547005,
          "reset_at": 1784800646
        },
        "secondary_window": null
      },
      "code_review_rate_limit": null,
      "additional_rate_limits": null,
      "credits": {"has_credits": false, "unlimited": false},
      "spend_control": {"reached": false, "individual_limit": null},
      "rate_limit_reached_type": null,
      "promo": null
    }
    """#

    // Synthetic (not captured live) — the real fixture's Plus-plan account has
    // only a weekly window, so this exercises secondary_window plus the
    // session-window (<86400s) classification path the research doc calls out.
    static let dualWindowFixture = #"""
    {
      "plan_type": "pro",
      "rate_limit": {
        "allowed": true,
        "limit_reached": false,
        "primary_window": {
          "used_percent": 42,
          "limit_window_seconds": 18000,
          "reset_after_seconds": 1000,
          "reset_at": 1700000000
        },
        "secondary_window": {
          "used_percent": 77,
          "limit_window_seconds": 604800,
          "reset_after_seconds": 500000,
          "reset_at": 1700500000
        }
      }
    }
    """#

    // MARK: Decode + mapping

    func testDecodesFullResponseAndMapsToQuotaSnapshot() throws {
        let response = try CodexUsageResponse.decode(Data(Self.fullFixture.utf8))
        XCTAssertEqual(response.planType, "plus")
        let limits = response.toQuotaLimits()
        XCTAssertEqual(limits.count, 1)
        XCTAssertEqual(limits[0].kind, .weeklyAll)
        XCTAssertEqual(limits[0].percentUsed, 0)
        XCTAssertEqual(limits[0].resetsAt, Date(timeIntervalSince1970: 1784800646))
        XCTAssertFalse(limits[0].isActive)

        XCTAssertEqual(CodexProvider.planName(for: response.planType), "CODEX PLUS")
    }

    func testDualWindowMapsSessionAndWeeklySeparately() throws {
        let response = try CodexUsageResponse.decode(Data(Self.dualWindowFixture.utf8))
        let limits = response.toQuotaLimits()
        XCTAssertEqual(limits.count, 2)
        XCTAssertEqual(limits[0].kind, .session)
        XCTAssertEqual(limits[0].percentUsed, 42)
        XCTAssertEqual(limits[0].resetsAt, Date(timeIntervalSince1970: 1700000000))
        XCTAssertEqual(limits[1].kind, .weeklyAll)
        XCTAssertEqual(limits[1].percentUsed, 77)
        XCTAssertEqual(limits[1].resetsAt, Date(timeIntervalSince1970: 1700500000))
    }

    func testThrowsOnGarbage() {
        XCTAssertThrowsError(try CodexUsageResponse.decode(Data("nope".utf8)))
    }

    // MARK: Credentials

    static let authJSON = #"""
    {
      "auth_mode": "chatgpt",
      "OPENAI_API_KEY": null,
      "tokens": {
        "id_token": "id-never-read",
        "access_token": "codex-access-token",
        "refresh_token": "rt-never-read",
        "account_id": "acct-never-read"
      },
      "last_refresh": "2026-07-16T02:19:33.175544Z"
    }
    """#

    func testCredentialsParse() throws {
        let creds = try XCTUnwrap(CodexCredentials.parse(Data(Self.authJSON.utf8)))
        XCTAssertEqual(creds.accessToken, "codex-access-token")
    }

    func testCredentialsParseRejectsMissingTokens() {
        XCTAssertNil(CodexCredentials.parse(Data("{}".utf8)))
        XCTAssertNil(CodexCredentials.parse(Data("garbage".utf8)))
    }

    func testFileSourceReadsTempFile() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let file = dir.appendingPathComponent("auth.json")
        try Data(Self.authJSON.utf8).write(to: file)
        let source = CodexFileCredentialsSource(path: file.path)
        XCTAssertEqual(source.load()?.accessToken, "codex-access-token")
    }

    func testFileSourceMissingFileReturnsNil() {
        XCTAssertNil(CodexFileCredentialsSource(path: "/nonexistent/auth.json").load())
    }

    // MARK: Client + Provider (reuses MockURLProtocol from ClaudeUsageClientTests.swift)

    private struct StubSource: CodexCredentialsSource {
        let creds: CodexCredentials?
        func load() -> CodexCredentials? { creds }
    }

    private func provider(creds: CodexCredentials?,
                          respond: @escaping (URLRequest) throws -> (HTTPURLResponse, Data)) -> CodexProvider {
        MockURLProtocol.handler = respond
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        return CodexProvider(
            source: StubSource(creds: creds),
            client: CodexUsageClient(session: URLSession(configuration: config)))
    }

    func testSendsCorrectRequest() async throws {
        nonisolated(unsafe) var captured: URLRequest?
        let p = provider(creds: CodexCredentials(accessToken: "tok-123"), respond: { request in
            captured = request
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
                    Data(Self.fullFixture.utf8))
        })
        _ = try await p.fetchSnapshot()
        XCTAssertEqual(captured?.url?.absoluteString, "https://chatgpt.com/backend-api/wham/usage")
        XCTAssertEqual(captured?.value(forHTTPHeaderField: "Authorization"), "Bearer tok-123")
    }

    func testFetchSnapshotSuccess() async throws {
        let p = provider(creds: CodexCredentials(accessToken: "tok"), respond: { request in
            (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
             Data(Self.fullFixture.utf8))
        })
        let snapshot = try await p.fetchSnapshot()
        XCTAssertEqual(snapshot.planName, "CODEX PLUS")
        XCTAssertEqual(snapshot.limits.count, 1)
    }

    func testMissingCredentialsThrows() async {
        let p = provider(creds: nil, respond: { _ in fatalError("must not be called") })
        do { _ = try await p.fetchSnapshot(); XCTFail("expected throw") }
        catch let e as QuotaError { XCTAssertEqual(e, .credentialsMissing) }
        catch { XCTFail("wrong error \(error)") }
    }

    func test401ThrowsTokenExpired() async {
        let p = provider(creds: CodexCredentials(accessToken: "tok"), respond: { request in
            (HTTPURLResponse(url: request.url!, statusCode: 401, httpVersion: nil, headerFields: nil)!, Data())
        })
        do { _ = try await p.fetchSnapshot(); XCTFail("expected throw") }
        catch let e as QuotaError { XCTAssertEqual(e, .tokenExpired) }
        catch { XCTFail("wrong error \(error)") }
    }

    func test500ThrowsBadResponse() async {
        let p = provider(creds: CodexCredentials(accessToken: "tok"), respond: { request in
            (HTTPURLResponse(url: request.url!, statusCode: 500, httpVersion: nil, headerFields: nil)!, Data("oops".utf8))
        })
        do { _ = try await p.fetchSnapshot(); XCTFail("expected throw") }
        catch let e as QuotaError { guard case .badResponse = e else { return XCTFail("wrong case \(e)") } }
        catch { XCTFail("wrong error \(error)") }
    }

    final class CountingSource: CodexCredentialsSource, @unchecked Sendable {
        private(set) var loadCount = 0
        let creds: CodexCredentials?
        init(creds: CodexCredentials?) { self.creds = creds }
        func load() -> CodexCredentials? { loadCount += 1; return creds }
    }

    func testCredentialsCachedAcrossConsecutivePolls() async throws {
        let source = CountingSource(creds: CodexCredentials(accessToken: "tok"))
        MockURLProtocol.handler = { request in
            (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
             Data(Self.fullFixture.utf8))
        }
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let p = CodexProvider(source: source, client: CodexUsageClient(session: URLSession(configuration: config)))
        _ = try await p.fetchSnapshot()
        _ = try await p.fetchSnapshot()
        XCTAssertEqual(source.loadCount, 1)
    }

    func testCredentialsReResolvedAfterServerTokenExpired() async throws {
        let source = CountingSource(creds: CodexCredentials(accessToken: "tok"))
        nonisolated(unsafe) var requestCount = 0
        MockURLProtocol.handler = { request in
            requestCount += 1
            if requestCount == 1 {
                return (HTTPURLResponse(url: request.url!, statusCode: 401, httpVersion: nil, headerFields: nil)!, Data())
            }
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
                    Data(Self.fullFixture.utf8))
        }
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let p = CodexProvider(source: source, client: CodexUsageClient(session: URLSession(configuration: config)))

        do { _ = try await p.fetchSnapshot(); XCTFail("expected throw") }
        catch let e as QuotaError { XCTAssertEqual(e, .tokenExpired) }
        XCTAssertEqual(source.loadCount, 1)

        _ = try await p.fetchSnapshot()
        XCTAssertEqual(source.loadCount, 2)
    }

    func testPlanNames() {
        XCTAssertEqual(CodexProvider.planName(for: "plus"), "CODEX PLUS")
        XCTAssertEqual(CodexProvider.planName(for: "pro"), "CODEX PRO")
        XCTAssertEqual(CodexProvider.planName(for: "business"), "CODEX BUSINESS")
        XCTAssertEqual(CodexProvider.planName(for: nil), "CODEX")
    }
}
