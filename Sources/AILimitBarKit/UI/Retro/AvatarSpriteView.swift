import SwiftUI

public struct AvatarSpriteView: View {
    let sprite: Sprite
    let color: Color
    let pixelScale: CGFloat
    let mood: SpriteMood
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(sprite: Sprite, color: Color, pixelScale: CGFloat = 2,
                mood: SpriteMood = .calm) {
        self.sprite = sprite
        self.color = color
        self.pixelScale = pixelScale
        self.mood = mood
    }

    public var body: some View {
        Group {
            if reduceMotion {
                frameCanvas(sprite.frames[0])
            } else {
                TimelineView(.periodic(from: .now, by: 0.3)) { context in
                    let tick = Int(context.date.timeIntervalSinceReferenceDate / 0.3)
                    // Low Power Mode holds the resting frame (DESIGN.md:
                    // pause all animation), same as the menu bar variant.
                    frameCanvas(ProcessInfo.processInfo.isLowPowerModeEnabled
                                ? sprite.frames[0]
                                : sprite.frame(mood: mood, tick: tick))
                }
            }
        }
        .accessibilityHidden(true)
    }

    private func frameCanvas(_ frame: SpriteFrame) -> some View {
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
}
