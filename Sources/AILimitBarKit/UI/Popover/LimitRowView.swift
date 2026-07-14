import SwiftUI

public struct LimitRowView: View {
    let limit: QuotaLimit
    let palette: RetroPalette
    let compact: Bool
    let now: Date

    public init(limit: QuotaLimit, palette: RetroPalette, compact: Bool, now: Date = Date()) {
        self.limit = limit
        self.palette = palette
        self.compact = compact
        self.now = now
    }

    public static func kindLabel(_ kind: LimitKind) -> String {
        switch kind {
        case .session: return "SESSION"
        case .weeklyAll: return "WEEKLY ALL"
        case .weeklyModel(let name): return "WEEKLY \(name.uppercased())"
        }
    }

    public static func resetLabel(for limit: QuotaLimit, now: Date) -> String {
        switch limit.kind {
        case .session:
            return "RESET " + ResetFormatter.sessionCountdown(until: limit.resetsAt, from: now)
        case .weeklyAll, .weeklyModel:
            return "RESET " + ResetFormatter.weeklyReset(limit.resetsAt)
        }
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(Self.kindLabel(limit.kind))
                    .font(PixelFont.swiftUI(size: 8))
                    .foregroundStyle(palette.textPrimary)
                Spacer()
                Text("\(Int(limit.percentUsed))%")
                    .font(PixelFont.swiftUI(size: 8))
                    .foregroundStyle(RetroTheme.color(for: Severity(percent: limit.percentUsed), in: palette))
                if limit.isActive {
                    Text("◀")
                        .font(.system(size: 8))
                        .foregroundStyle(palette.accentPink)
                        .help("Currently binding limit")
                }
            }
            PixelProgressBar(percent: limit.percentUsed, palette: palette)
            if !compact {
                Text(Self.resetLabel(for: limit, now: now))
                    .font(PixelFont.swiftUI(size: 6))
                    .foregroundStyle(palette.textPrimary.opacity(0.7))
            }
        }
    }
}
