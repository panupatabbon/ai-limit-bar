import SwiftUI

public struct PixelProgressBar: View {
    let percent: Double
    let palette: RetroPalette
    static let totalSegments = 12

    public init(percent: Double, palette: RetroPalette) {
        self.percent = percent
        self.palette = palette
    }

    public static func filledSegments(percent: Double, total: Int) -> Int {
        let clamped = min(max(percent, 0), 100)
        if clamped == 0 { return 0 }
        return max(1, Int((clamped / 100 * Double(total)).rounded()))
    }

    public var body: some View {
        let filled = Self.filledSegments(percent: percent, total: Self.totalSegments)
        let color = RetroTheme.color(for: Severity(percent: percent), in: palette)
        HStack(spacing: 2) {
            ForEach(0..<Self.totalSegments, id: \.self) { i in
                Rectangle()
                    .fill(i < filled ? color : palette.surface)
                    .frame(width: 10, height: 10)
            }
        }
        .padding(2)
        .overlay(Rectangle().stroke(palette.textPrimary.opacity(0.4), lineWidth: 1))
        .accessibilityLabel("\(Int(percent)) percent used")
    }
}
