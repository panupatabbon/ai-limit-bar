import XCTest
@testable import AILimitBarKit

final class UsageResponseTests: XCTestCase {
    static let fullFixture = #"""
    {
      "five_hour": {"utilization": 10.0, "resets_at": "2026-07-14T23:00:00.212361+00:00"},
      "seven_day": {"utilization": 58.0, "resets_at": "2026-07-16T21:00:00.212431+00:00"},
      "seven_day_opus": null,
      "extra_usage": {"is_enabled": false},
      "limits": [
        {"kind": "session", "group": "session", "percent": 10, "severity": "normal",
         "resets_at": "2026-07-14T23:00:00.212361+00:00", "scope": null, "is_active": false},
        {"kind": "weekly_all", "group": "weekly", "percent": 58, "severity": "normal",
         "resets_at": "2026-07-16T21:00:00.212431+00:00", "scope": null, "is_active": true},
        {"kind": "weekly_scoped", "group": "weekly", "percent": 38, "severity": "normal",
         "resets_at": "2026-07-16T21:00:00.212804+00:00",
         "scope": {"model": {"id": null, "display_name": "Fable"}, "surface": null},
         "is_active": false}
      ]
    }
    """#

    static let legacyFixture = #"""
    {
      "five_hour": {"utilization": 22.0, "resets_at": "2026-07-14T23:00:00+00:00"},
      "seven_day": {"utilization": 71.0, "resets_at": "2026-07-16T21:00:00+00:00"}
    }
    """#

    static let unknownKindFixture = #"""
    {
      "limits": [
        {"kind": "hourly_quantum", "percent": 5, "resets_at": "2026-07-14T23:00:00+00:00", "is_active": false},
        {"kind": "session", "percent": 12, "resets_at": "2026-07-14T23:00:00+00:00", "is_active": true}
      ]
    }
    """#

    func testDecodesFullResponse() throws {
        let response = try UsageResponse.decode(Data(Self.fullFixture.utf8))
        let limits = response.toQuotaLimits()
        XCTAssertEqual(limits.count, 3)
        XCTAssertEqual(limits[0].kind, .session)
        XCTAssertEqual(limits[0].percentUsed, 10)
        XCTAssertFalse(limits[0].isActive)
        XCTAssertEqual(limits[1].kind, .weeklyAll)
        XCTAssertEqual(limits[1].percentUsed, 58)
        XCTAssertTrue(limits[1].isActive)
        XCTAssertEqual(limits[2].kind, .weeklyModel("Fable"))
        XCTAssertEqual(limits[2].percentUsed, 38)
    }

    func testFallsBackToLegacyFields() throws {
        let response = try UsageResponse.decode(Data(Self.legacyFixture.utf8))
        let limits = response.toQuotaLimits()
        XCTAssertEqual(limits.count, 2)
        XCTAssertEqual(limits[0].kind, .session)
        XCTAssertEqual(limits[0].percentUsed, 22)
        XCTAssertEqual(limits[1].kind, .weeklyAll)
        XCTAssertEqual(limits[1].percentUsed, 71)
    }

    func testSkipsUnknownKinds() throws {
        let response = try UsageResponse.decode(Data(Self.unknownKindFixture.utf8))
        let limits = response.toQuotaLimits()
        XCTAssertEqual(limits.count, 1)
        XCTAssertEqual(limits[0].kind, .session)
    }

    func testThrowsOnGarbage() {
        XCTAssertThrowsError(try UsageResponse.decode(Data("nope".utf8)))
    }
}
