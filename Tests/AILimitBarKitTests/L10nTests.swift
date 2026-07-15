import XCTest
@testable import AILimitBarKit

final class L10nTests: XCTestCase {
    func testEveryKeyHasBothLanguages() {
        for key in L10nKey.allCases {
            XCTAssertFalse(L10n.t(key, .en).isEmpty, "missing EN for \(key)")
            XCTAssertFalse(L10n.t(key, .th).isEmpty, "missing TH for \(key)")
        }
    }

    func testSample() {
        XCTAssertEqual(L10n.t(.settingsLanguage, .en), "Language")
        XCTAssertEqual(L10n.t(.settingsLanguage, .th), "ภาษา")
        XCTAssertEqual(L10n.t(.tabComingSoonHint, .en), "Gemini support is coming soon.")
        XCTAssertEqual(L10n.t(.tabComingSoonHint, .th), "รองรับ Gemini เร็วๆ นี้")
    }
}
