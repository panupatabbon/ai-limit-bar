import SwiftUI

public struct QuotaPopoverView: View {
    @Environment(\.colorScheme) private var colorScheme
    let store: QuotaStore
    let settings: AppSettings
    let onOpenSettings: () -> Void

    public init(store: QuotaStore, settings: AppSettings, onOpenSettings: @escaping () -> Void) {
        self.store = store
        self.settings = settings
        self.onOpenSettings = onOpenSettings
    }

    public static func visibleLimits(_ snapshot: QuotaSnapshot?, settings: AppSettings) -> [QuotaLimit] {
        (snapshot?.limits ?? []).filter { settings.isVisible($0.kind) }
    }

    private var palette: RetroPalette {
        RetroTheme.palette(settings.theme, systemIsDark: colorScheme == .dark)
    }

    public var body: some View {
        let palette = self.palette
        VStack(alignment: .leading, spacing: 10) {
            header(palette)
            content(palette)
            footer(palette)
        }
        .padding(14)
        .frame(width: 240)
        .background(palette.background)
    }

    @ViewBuilder
    private func header(_ palette: RetroPalette) -> some View {
        HStack {
            Text(store.currentSnapshot?.planName ?? "AI QUOTA")
                .font(PixelFont.swiftUI(size: 9))
                .foregroundStyle(palette.accentCyan)
            Spacer()
            AvatarSpriteView(
                sprite: SpriteLibrary.sprite(for: settings.avatar),
                color: headlineColor(palette), pixelScale: 2)
        }
    }

    private func headlineColor(_ palette: RetroPalette) -> Color {
        guard let headline = store.headlineLimit(pin: settings.headlinePin) else {
            return palette.textPrimary.opacity(0.5)
        }
        return RetroTheme.color(for: Severity(percent: headline.percentUsed), in: palette)
    }

    @ViewBuilder
    private func content(_ palette: RetroPalette) -> some View {
        switch store.state {
        case .loading:
            stateScreen("LOADING", hint: L10n.t(.loadingHint, settings.language), palette: palette)
        case .credentialsMissing:
            stateScreen("INSERT COIN", hint: L10n.t(.hintInstallClaude, settings.language), palette: palette)
        case .tokenExpired:
            stateScreen("TOKEN EXPIRED", hint: L10n.t(.hintTokenExpired, settings.language), palette: palette)
        case .ready, .offline:
            limitList(palette)
            if case .offline(let last) = store.state {
                offlineBadge(last, palette: palette)
            }
        }
    }

    @ViewBuilder
    private func limitList(_ palette: RetroPalette) -> some View {
        let limits = Self.visibleLimits(store.currentSnapshot, settings: settings)
        if limits.isEmpty {
            stateScreen("NO DATA", hint: "", palette: palette)
        } else {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(Array(limits.enumerated()), id: \.offset) { _, limit in
                    LimitRowView(limit: limit, palette: palette, compact: settings.compactRows)
                }
            }
        }
    }

    @ViewBuilder
    private func stateScreen(_ title: String, hint: String, palette: RetroPalette) -> some View {
        VStack(spacing: 8) {
            Text(title)
                .font(PixelFont.swiftUI(size: 12))
                .foregroundStyle(palette.accentPink)
            if !hint.isEmpty {
                Text(hint)
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(palette.textPrimary.opacity(0.8))
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
    }

    @ViewBuilder
    private func offlineBadge(_ last: QuotaSnapshot?, palette: RetroPalette) -> some View {
        HStack(spacing: 6) {
            Text("OFFLINE")
                .font(PixelFont.swiftUI(size: 7))
                .foregroundStyle(palette.warn)
            if let last {
                Text("\(L10n.t(.offlineLastUpdated, settings.language)): \(last.fetchedAt.formatted(date: .omitted, time: .shortened))")
                    .font(.system(.caption2, design: .rounded))
                    .foregroundStyle(palette.textPrimary.opacity(0.6))
            }
        }
    }

    @ViewBuilder
    private func footer(_ palette: RetroPalette) -> some View {
        Button(action: onOpenSettings) {
            Text("⚙ SETTINGS")
                .font(PixelFont.swiftUI(size: 7))
                .foregroundStyle(palette.textPrimary.opacity(0.7))
        }
        .buttonStyle(.plain)
    }
}
