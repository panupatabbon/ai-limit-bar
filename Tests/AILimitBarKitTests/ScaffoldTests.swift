import XCTest
@testable import AILimitBarKit

final class ScaffoldTests: XCTestCase {
    func testVersion() {
        XCTAssertEqual(AILimitBarKit.version, "0.1.0")
    }
}
