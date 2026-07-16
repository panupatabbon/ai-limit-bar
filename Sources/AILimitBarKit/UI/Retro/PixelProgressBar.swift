import SwiftUI

public struct PixelProgressBar: View {
    let percent: Double
    let palette: RetroPalette
    static let totalSegments = 12
    // 2:1 chunks so the 12-segment bar spans the popover's full measure:
    // 12×20 + 11×2 (gaps) + 2×2 (padding) = 266pt.
    static let segmentSize = CGSize(width: 20, height: 10)
    static let totalWidth: CGFloat = 266
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(percent: Double, palette: RetroPalette) {
        self.percent = percent
        self.palette = palette
    }

    public static func filledSegments(percent: Double, total: Int) -> Int {
        let clamped = min(max(percent, 0), 100)
        if clamped == 0 { return 0 }
        return max(1, Int((clamped / 100 * Double(total)).rounded()))
    }

    /// The classic low-HP flash: at critical severity the leading filled
    /// segment pulses. Nil for every other state.
    public static func pulsedSegment(percent: Double, total: Int) -> Int? {
        guard Severity(percent: percent) == .critical else { return nil }
        return filledSegments(percent: percent, total: total) - 1
    }

    public var body: some View {
        let pulsed = Self.pulsedSegment(percent: percent, total: Self.totalSegments)
        if let pulsed, !reduceMotion {
            TimelineView(.periodic(from: .now, by: 0.4)) { context in
                let tick = Int(context.date.timeIntervalSinceReferenceDate / 0.4)
                let pulsing = tick % 2 == 1
                    && !ProcessInfo.processInfo.isLowPowerModeEnabled
                segments(pulsedIndex: pulsing ? pulsed : nil)
            }
        } else {
            segments(pulsedIndex: nil)
        }
    }

    private func segments(pulsedIndex: Int?) -> some View {
        let filled = Self.filledSegments(percent: percent, total: Self.totalSegments)
        let color = RetroTheme.color(for: Severity(percent: percent), in: palette)
        return HStack(spacing: 2) {
            ForEach(0..<Self.totalSegments, id: \.self) { i in
                Rectangle()
                    .fill(i < filled
                          ? (i == pulsedIndex ? color.opacity(0.35) : color)
                          : palette.surface)
                    .frame(width: Self.segmentSize.width,
                           height: Self.segmentSize.height)
            }
        }
        .padding(2)
        .overlay(Rectangle().stroke(palette.textPrimary.opacity(0.4), lineWidth: 1))
        .accessibilityLabel("\(Int(percent)) percent used")
    }
}
