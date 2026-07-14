import XCTest
import AppKit
@testable import AILimitBarKit

final class SpriteTests: XCTestCase {
    func testAllSpritesAre16x16With4Frames() {
        for id in AvatarID.allCases {
            let sprite = SpriteLibrary.sprite(for: id)
            XCTAssertEqual(sprite.id, id)
            XCTAssertEqual(sprite.frames.count, 4, "\(id) needs 4 popover frames")
            XCTAssertEqual(sprite.menuBarFrames.count, 2)
            for (i, frame) in sprite.frames.enumerated() {
                XCTAssertEqual(frame.bitmap.count, 16, "\(id) frame \(i) rows")
                for row in frame.bitmap { XCTAssertEqual(row.count, 16, "\(id) frame \(i) cols") }
            }
        }
    }

    func testFramesAreNotAllIdentical() {
        for id in AvatarID.allCases {
            let sprite = SpriteLibrary.sprite(for: id)
            XCTAssertNotEqual(sprite.frames[0].bitmap, sprite.frames[1].bitmap,
                              "\(id) idle animation needs 2 distinct frames")
        }
    }

    func testNSImageRendering() {
        let frame = SpriteLibrary.sprite(for: .boo).frames[0]
        let image = frame.nsImage(color: .systemGreen, pixelSize: 1)
        XCTAssertEqual(image.size, NSSize(width: 16, height: 16))
    }
}
