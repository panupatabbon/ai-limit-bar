import XCTest
@testable import AILimitBarKit

final class MockURLProtocol: URLProtocol {
    nonisolated(unsafe) static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        guard let handler = Self.handler else { fatalError("no handler") }
        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }
    override func stopLoading() {}
}

final class ClaudeUsageClientTests: XCTestCase {
    private func makeClient() -> ClaudeUsageClient {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        return ClaudeUsageClient(session: URLSession(configuration: config))
    }

    private func respond(status: Int, body: String) -> (URLRequest) throws -> (HTTPURLResponse, Data) {
        { request in
            (HTTPURLResponse(url: request.url!, statusCode: status,
                             httpVersion: nil, headerFields: nil)!,
             Data(body.utf8))
        }
    }

    func testSendsCorrectRequest() async throws {
        nonisolated(unsafe) var captured: URLRequest?
        MockURLProtocol.handler = { request in
            captured = request
            return (HTTPURLResponse(url: request.url!, statusCode: 200,
                                    httpVersion: nil, headerFields: nil)!,
                    Data(UsageResponseTests.fullFixture.utf8))
        }
        _ = try await makeClient().fetchUsage(accessToken: "tok-123")
        XCTAssertEqual(captured?.url?.absoluteString, "https://api.anthropic.com/api/oauth/usage")
        XCTAssertEqual(captured?.value(forHTTPHeaderField: "Authorization"), "Bearer tok-123")
        XCTAssertEqual(captured?.value(forHTTPHeaderField: "anthropic-beta"), "oauth-2025-04-20")
    }

    func testDecodes200() async throws {
        MockURLProtocol.handler = respond(status: 200, body: UsageResponseTests.fullFixture)
        let response = try await makeClient().fetchUsage(accessToken: "tok")
        XCTAssertEqual(response.toQuotaLimits().count, 3)
    }

    func test401ThrowsTokenExpired() async {
        MockURLProtocol.handler = respond(status: 401, body: #"{"type":"error"}"#)
        do {
            _ = try await makeClient().fetchUsage(accessToken: "tok")
            XCTFail("expected throw")
        } catch let error as QuotaError {
            XCTAssertEqual(error, .tokenExpired)
        } catch { XCTFail("wrong error \(error)") }
    }

    func test500ThrowsBadResponse() async {
        MockURLProtocol.handler = respond(status: 500, body: "oops")
        do {
            _ = try await makeClient().fetchUsage(accessToken: "tok")
            XCTFail("expected throw")
        } catch let error as QuotaError {
            guard case .badResponse = error else { return XCTFail("wrong case \(error)") }
        } catch { XCTFail("wrong error \(error)") }
    }
}
