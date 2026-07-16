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
    public let frames: [SpriteFrame] // 4-frame loop: base, alt, base, blink

    public init(id: String, base: SpriteFrame, alt: SpriteFrame, blink: SpriteFrame) {
        self.id = id
        self.frames = [base, alt, base, blink]
    }
}

/// How the mascot carries the headline limit's state — a party member's
/// body language, not decoration (severity is the signal).
public enum SpriteMood: Equatable, Sendable {
    case calm, wary, agitated

    public init(severity: Severity?) {
        switch severity {
        case .critical: self = .agitated
        case .warn: self = .wary
        case .ok, nil: self = .calm
        }
    }
}

public extension Sprite {
    /// Mood-driven idle. One tick = one animation step (0.3s in the popover,
    /// 1s in the menu bar).
    func frame(mood: SpriteMood, tick: Int) -> SpriteFrame {
        switch mood {
        case .calm:
            // At rest: hold base, blink one tick in ten.
            return tick % 10 == 9 ? frames[3] : frames[0]
        case .wary:
            // Walk the standard 4-step loop at half speed.
            return frames[(tick / 2) % frames.count]
        case .agitated:
            // Low HP: pace every tick — no time to blink.
            return tick % 2 == 0 ? frames[0] : frames[1]
        }
    }
}
