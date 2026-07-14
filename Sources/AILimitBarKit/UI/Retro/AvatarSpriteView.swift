import SwiftUI

public struct AvatarSpriteView: View {
    let sprite: Sprite
    let color: Color
    let pixelScale: CGFloat

    public init(sprite: Sprite, color: Color, pixelScale: CGFloat = 2) {
        self.sprite = sprite
        self.color = color
        self.pixelScale = pixelScale
    }

    public var body: some View {
        TimelineView(.periodic(from: .now, by: 0.3)) { context in
            let tick = Int(context.date.timeIntervalSinceReferenceDate / 0.3)
            let frame = sprite.frames[tick % sprite.frames.count]
            Canvas { ctx, _ in
                for (y, row) in frame.bitmap.enumerated() {
                    for (x, filled) in row.enumerated() where filled {
                        ctx.fill(Path(CGRect(x: CGFloat(x) * pixelScale,
                                             y: CGFloat(y) * pixelScale,
                                             width: pixelScale, height: pixelScale)),
                                 with: .color(color))
                    }
                }
            }
            .frame(width: 16 * pixelScale, height: 16 * pixelScale)
        }
        .accessibilityHidden(true)
    }
}
