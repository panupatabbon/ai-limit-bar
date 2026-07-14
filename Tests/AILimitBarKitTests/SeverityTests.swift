import XCTest
@testable import AILimitBarKit

final class SeverityTests: XCTestCase {
    func testThresholds() {
        XCTAssertEqual(Severity(percent: 0), .ok)
        XCTAssertEqual(Severity(percent: 59.9), .ok)
        XCTAssertEqual(Severity(percent: 60), .warn)
        XCTAssertEqual(Severity(percent: 84.9), .warn)
        XCTAssertEqual(Severity(percent: 85), .critical)
        XCTAssertEqual(Severity(percent: 100), .critical)
        XCTAssertEqual(Severity(percent: 120), .critical) // extra usage overshoot
    }

    func testAuthSourceCases() {
        XCTAssertEqual(AuthSource.allCases, [.claudeCodeCredentials])
    }
}
