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
        case .weeklyAll: return "WEEKLY TOTAL"
        case .weeklyModel(let name): return "WEEKLY \(name.uppercased())"
        }
    }

    /// Compact mode may drop reset captions, but never for the binding limit
    /// or any limit from warn upward — "when does it reset" is the popover's
    /// second question (PRODUCT.md), and it matters most at high stakes.
    public static func showsReset(compact: Bool, isActive: Bool, severity: Severity) -> Bool {
        !compact || isActive || severity != .ok
    }

    /// From warn upward the countdown is the answer the user actually needs,
    /// so it steps up from the 6pt/70% caption floor to 7pt full white.
    public static func resetIsProminent(severity: Severity) -> Bool {
        severity != .ok
    }

    /// One VoiceOver sentence per row; children are ignored so the bar and
    /// percent text don't announce the same number twice.
    public static func accessibilityDescription(for limit: QuotaLimit, now: Date) -> String {
        let reset: String
        switch limit.kind {
        case .session:
            reset = ResetFormatter.spokenSessionCountdown(until: limit.resetsAt, from: now)
        case .weeklyAll, .weeklyModel:
            reset = ResetFormatter.spokenWeeklyReset(limit.resetsAt)
                + ", " + ResetFormatter.spokenWeeklyCountdown(until: limit.resetsAt, from: now)
        }
        var parts = [kindLabel(limit.kind).capitalized,
                     "\(Int(limit.percentUsed)) percent used"]
        // Severity is spoken from warn upward so thresholds aren't hue-only.
        switch Severity(percent: limit.percentUsed) {
        case .ok: break
        case .warn: parts.append("warning")
        case .critical: parts.append("critical")
        }
        parts.append(reset)
        if limit.isActive { parts.append("you'll hit this limit first") }
        return parts.joined(separator: ", ")
    }

    public static func resetLabel(for limit: QuotaLimit, now: Date) -> String {
        switch limit.kind {
        case .session:
            return "RESET " + ResetFormatter.sessionCountdown(until: limit.resetsAt, from: now)
        case .weeklyAll, .weeklyModel:
            return "RESET " + ResetFormatter.weeklyReset(limit.resetsAt)
                + " · " + ResetFormatter.weeklyCountdown(until: limit.resetsAt, from: now)
        }
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                // Long model names ("WEEKLY SONNET 4.5") truncate; the percent
                // and ACTIVE marker always win the space fight. VoiceOver
                // still speaks the full name via accessibilityDescription.
                Text(Self.kindLabel(limit.kind))
                    .pixelType(size: 8)
                    .foregroundStyle(palette.textPrimary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer(minLength: 8)
                Text("\(Int(limit.percentUsed))%")
                    .pixelType(size: 8)
                    .foregroundStyle(RetroTheme.color(for: Severity(percent: limit.percentUsed), in: palette))
                    .layoutPriority(1)
                    .help("Cyan below 60% · gold from 60% · red from 85%")
                if limit.isActive {
                    // Spelled out — the lone ◀ was only explained on hover,
                    // invisible to keyboard users and first-timers.
                    HStack(spacing: 2) {
                        Text("◀")
                            .font(.system(size: 8))
                        Text("ACTIVE")
                            .pixelType(size: 7)
                    }
                    .foregroundStyle(palette.accentPink)
                    .help("You'll hit this limit first")
                    .layoutPriority(1)
                }
            }
            PixelProgressBar(percent: limit.percentUsed, palette: palette)
            let severity = Severity(percent: limit.percentUsed)
            if Self.showsReset(compact: compact, isActive: limit.isActive, severity: severity) {
                let prominent = Self.resetIsProminent(severity: severity)
                Text(Self.resetLabel(for: limit, now: now))
                    .pixelType(size: prominent ? 7 : 6)
                    .foregroundStyle(palette.textPrimary.opacity(prominent ? 1 : 0.7))
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Self.accessibilityDescription(for: limit, now: now))
    }
}
