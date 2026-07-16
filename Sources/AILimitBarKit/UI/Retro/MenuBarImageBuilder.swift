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

    static func textAttributes(color: NSColor) -> [NSAttributedString.Key: Any] {
        [.font: PixelFont.nsFont(size: 7),
         .kern: PixelFont.tracking(forSize: 7),
         .foregroundColor: color]
    }

    static func width(of text: String) -> CGFloat {
        ceil((text as NSString).size(withAttributes: textAttributes(color: .white)).width)
    }

    static let providerGap: CGFloat = 8

    public static func image(for spec: Spec) -> NSImage {
        image(for: [spec])
    }

    public static func layoutWidth(for specs: [Spec]) -> CGFloat {
        guard !specs.isEmpty else { return 0 }
        return specs.map { layoutWidth(for: $0) }.reduce(0, +)
            + CGFloat(specs.count - 1) * providerGap
    }

    public static func image(for specs: [Spec]) -> NSImage {
        let image = NSImage(size: NSSize(width: layoutWidth(for: specs), height: height))
        image.lockFocus()
        var x: CGFloat = 0
        for spec in specs {
            draw(spec, atX: x)
            x += layoutWidth(for: spec) + providerGap
        }
        image.unlockFocus()
        image.isTemplate = false
        return image
    }

    private static func draw(_ spec: Spec, atX x: CGFloat) {
        spec.frame.nsImage(color: spec.color, pixelSize: 1)
            .draw(in: NSRect(x: x, y: 1, width: avatarSide, height: avatarSide))

        let rightX = x + avatarSide + gap
        if let text = spec.percentText {
            (text as NSString).draw(
                at: NSPoint(x: rightX, y: 8),
                withAttributes: textAttributes(color: spec.color))
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
    }
}
