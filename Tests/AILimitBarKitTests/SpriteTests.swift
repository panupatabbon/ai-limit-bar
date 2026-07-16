import XCTest
import AppKit
@testable import AILimitBarKit

final class SpriteTests: XCTestCase {
    private let providers = ["claude", "gemini"]

    func testProviderSpritesAre16x16With4Frames() {
        for id in providers {
            let sprite = SpriteLibrary.sprite(forProvider: id)
            XCTAssertEqual(sprite.id, id)
            XCTAssertEqual(sprite.frames.count, 4)
            for (i, frame) in sprite.frames.enumerated() {
                XCTAssertEqual(frame.bitmap.count, 16, "\(id) frame \(i)")
                for row in frame.bitmap { XCTAssertEqual(row.count, 16, "\(id) frame \(i)") }
            }
        }
    }

    func testIdleMotionIsVisible() {
        // base vs alt must differ in at least 8 pixels — V1's subtlety bug.
        for id in providers {
            let sprite = SpriteLibrary.sprite(forProvider: id)
            let a = sprite.frames[0].bitmap.flatMap { $0 }
            let b = sprite.frames[1].bitmap.flatMap { $0 }
            let diff = zip(a, b).filter { $0 != $1 }.count
            XCTAssertGreaterThanOrEqual(diff, 8, "\(id) idle motion too subtle: \(diff) px")
        }
    }

    func testMoodFromSeverity() {
        XCTAssertEqual(SpriteMood(severity: nil), .calm)
        XCTAssertEqual(SpriteMood(severity: .ok), .calm)
        XCTAssertEqual(SpriteMood(severity: .warn), .wary)
        XCTAssertEqual(SpriteMood(severity: .critical), .agitated)
    }

    func testMoodFrames() {
        let s = SpriteLibrary.sprite(forProvider: "claude")

        // calm rests on base and blinks one tick in ten.
        XCTAssertEqual(s.frame(mood: .calm, tick: 0), s.frames[0])
        XCTAssertEqual(s.frame(mood: .calm, tick: 5), s.frames[0])
        XCTAssertEqual(s.frame(mood: .calm, tick: 9), s.frames[3])
        XCTAssertEqual(s.frame(mood: .calm, tick: 19), s.frames[3])

        // wary walks the 4-step loop at half speed.
        XCTAssertEqual(s.frame(mood: .wary, tick: 0), s.frames[0])
        XCTAssertEqual(s.frame(mood: .wary, tick: 2), s.frames[1])
        XCTAssertEqual(s.frame(mood: .wary, tick: 4), s.frames[2])
        XCTAssertEqual(s.frame(mood: .wary, tick: 6), s.frames[3])

        // agitated paces base/alt every tick — no time to blink at low HP.
        XCTAssertEqual(s.frame(mood: .agitated, tick: 0), s.frames[0])
        XCTAssertEqual(s.frame(mood: .agitated, tick: 1), s.frames[1])
        XCTAssertEqual(s.frame(mood: .agitated, tick: 2), s.frames[0])
    }

    func testUnknownProviderFallsBackToClaude() {
        XCTAssertEqual(SpriteLibrary.sprite(forProvider: "unknown").id, "claude")
    }

    func testNSImageRendering() {
        let frame = SpriteLibrary.sprite(forProvider: "claude").frames[0]
        let image = frame.nsImage(color: .systemGreen, pixelSize: 1)
        XCTAssertEqual(image.size, NSSize(width: 16, height: 16))
    }
}
