import AppKit

public struct SpriteFrame: Equatable, Sendable {
    public let bitmap: [[Bool]] // 16 rows x 16 cols

    public init(rows: [String]) {
        precondition(rows.count == 16, "sprite must have 16 rows")
        bitmap = rows.map { row -> [Bool] in
            precondition(row.count == 16, "sprite row must have 16 chars")
            return row.map { $0 == "#" }
        }
    }

    public func nsImage(color: NSColor, pixelSize: CGFloat) -> NSImage {
        let side = 16 * pixelSize
        let image = NSImage(size: NSSize(width: side, height: side))
        image.lockFocus()
        color.setFill()
        for (y, row) in bitmap.enumerated() {
            for (x, filled) in row.enumerated() where filled {
                // NSImage origin is bottom-left; sprite rows are top-down.
                NSRect(x: CGFloat(x) * pixelSize,
                       y: side - CGFloat(y + 1) * pixelSize,
                       width: pixelSize, height: pixelSize).fill()
            }
        }
        image.unlockFocus()
        return image
    }
}

public struct Sprite: Sendable {
    public let id: String
    public let frames: [SpriteFrame] // 4-frame popover loop

    public var menuBarFrames: [SpriteFrame] { Array(frames.prefix(2)) }

    public init(id: String, base: SpriteFrame, alt: SpriteFrame, blink: SpriteFrame) {
        self.id = id
        self.frames = [base, alt, base, blink]
    }
}
