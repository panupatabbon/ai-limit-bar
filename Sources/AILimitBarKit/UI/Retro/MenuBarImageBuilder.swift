import AppKit

/// Renders the whole status-item content (avatar + percent + mini bar)
/// into ONE NSImage so spacing is exact and the button keeps standard
/// menu-bar metrics (fixes the V1 popover-gap problem).
public enum MenuBarImageBuilder {
    public struct Spec: Equatable {
        public let frame: SpriteFrame
        public let percentText: String?
        public let barFraction: Double?  // 0...1
        public let color: NSColor

        public init(frame: SpriteFrame, percentText: String?,
                    barFraction: Double?, color: NSColor) {
            self.frame = frame
            self.percentText = percentText
            self.barFraction = barFraction
            self.color = color
        }
    }

    static let height: CGFloat = 18
    static let avatarSide: CGFloat = 16
    static let gap: CGFloat = 3
    static let barSize = NSSize(width: 14, height: 3)

    public static func layoutWidth(for spec: Spec) -> CGFloat {
        let right = rightBlockWidth(for: spec)
        return right > 0 ? avatarSide + gap + right : avatarSide
    }

    static func rightBlockWidth(for spec: Spec) -> CGFloat {
        let textWidth = spec.percentText.map { width(of: $0) } ?? 0
        let barWidth: CGFloat = spec.barFraction != nil ? barSize.width : 0
        return max(textWidth, barWidth)
    }

    static func width(of text: String) -> CGFloat {
        let font = PixelFont.nsFont(size: 7)
        return ceil((text as NSString).size(withAttributes: [.font: font]).width)
    }

    public static func image(for spec: Spec) -> NSImage {
        let size = NSSize(width: layoutWidth(for: spec), height: height)
        let image = NSImage(size: size)
        image.lockFocus()

        spec.frame.nsImage(color: spec.color, pixelSize: 1)
            .draw(in: NSRect(x: 0, y: 1, width: avatarSide, height: avatarSide))

        let rightX = avatarSide + gap
        if let text = spec.percentText {
            (text as NSString).draw(
                at: NSPoint(x: rightX, y: 8),
                withAttributes: [.font: PixelFont.nsFont(size: 7),
                                 .foregroundColor: spec.color])
        }
        if let fraction = spec.barFraction {
            let clamped = min(max(fraction, 0), 1)
            let track = NSRect(x: rightX, y: 3,
                               width: barSize.width, height: barSize.height)
            spec.color.withAlphaComponent(0.25).setFill()
            track.fill()
            spec.color.setFill()
            NSRect(x: rightX, y: 3,
                   width: barSize.width * clamped, height: barSize.height).fill()
        }

        image.unlockFocus()
        image.isTemplate = false
        return image
    }
}
