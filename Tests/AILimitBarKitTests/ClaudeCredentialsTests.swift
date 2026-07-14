import XCTest
@testable import AILimitBarKit

final class ClaudeCredentialsTests: XCTestCase {
    static let credentialsJSON = #"""
    {
      "claudeAiOauth": {
        "accessToken": "sk-test-token",
        "refreshToken": "rt-never-read",
        "expiresAt": 1784078801830,
        "refreshTokenExpiresAt": 1785604162830,
        "scopes": ["user:inference"],
        "subscriptionType": "max",
        "rateLimitTier": "default"
      },
      "mcpOAuth": {}
    }
    """#

    func testParse() throws {
        let creds = try XCTUnwrap(ClaudeCredentials.parse(Data(Self.credentialsJSON.utf8)))
        XCTAssertEqual(creds.accessToken, "sk-test-token")
        XCTAssertEqual(creds.expiresAt, Date(timeIntervalSince1970: 1784078801.830))
        XCTAssertEqual(creds.subscriptionType, "max")
    }

    func testParseRejectsMissingOauthBlock() {
        XCTAssertNil(ClaudeCredentials.parse(Data("{}".utf8)))
        XCTAssertNil(ClaudeCredentials.parse(Data("garbage".utf8)))
    }

    func testFileSourceReadsTempFile() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let file = dir.appendingPathComponent("creds.json")
        try Data(Self.credentialsJSON.utf8).write(to: file)
        let source = FileCredentialsSource(path: file.path)
        XCTAssertEqual(source.load()?.accessToken, "sk-test-token")
    }

    func testFileSourceMissingFileReturnsNil() {
        XCTAssertNil(FileCredentialsSource(path: "/nonexistent/creds.json").load())
    }

    func testResolverPicksNewestExpiry() {
        struct Stub: CredentialsSource {
            let creds: ClaudeCredentials?
            func load() -> ClaudeCredentials? { creds }
        }
        let older = ClaudeCredentials(accessToken: "old", expiresAt: Date(timeIntervalSince1970: 100), subscriptionType: nil)
        let newer = ClaudeCredentials(accessToken: "new", expiresAt: Date(timeIntervalSince1970: 200), subscriptionType: nil)
        let resolver = CredentialsResolver(sources: [Stub(creds: older), Stub(creds: newer), Stub(creds: nil)])
        XCTAssertEqual(resolver.resolve()?.accessToken, "new")
        XCTAssertNil(CredentialsResolver(sources: [Stub(creds: nil)]).resolve())
    }
}
