import SwiftUI

/// A sprite's resting face at 1px scale — used for tab chrome.
public struct SpriteIconView: View {
    let sprite: Sprite
    let color: Color

    public init(sprite: Sprite, color: Color) {
        self.sprite = sprite
        self.color = color
    }

    public var body: some View {
        Canvas { ctx, _ in
            for (y, row) in sprite.frames[0].bitmap.enumerated() {
                for (x, filled) in row.enumerated() where filled {
                    ctx.fill(Path(CGRect(x: CGFloat(x), y: CGFloat(y), width: 1, height: 1)),
                             with: .color(color))
                }
            }
        }
        .frame(width: 16, height: 16)
        .accessibilityHidden(true)
    }
}
