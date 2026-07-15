import SwiftUI

public struct QuotaPopoverView: View {
    let store: QuotaStore
    @Bindable var settings: AppSettings
    let activity: ActivityStore
    let onOpenSettings: () -> Void
    let onQuit: () -> Void

    public init(store: QuotaStore, settings: AppSettings, activity: ActivityStore,
                onOpenSettings: @escaping () -> Void, onQuit: @escaping () -> Void) {
        self.store = store
        self.settings = settings
        self.activity = activity
        self.onOpenSettings = onOpenSettings
        self.onQuit = onQuit
    }

    public static func visibleLimits(_ snapshot: QuotaSnapshot?, settings: AppSettings) -> [QuotaLimit] {
        (snapshot?.limits ?? []).filter { settings.isVisible($0.kind) }
    }

    private var palette: RetroPalette { RetroTheme.jules }

    public var body: some View {
        let palette = self.palette
        VStack(alignment: .leading, spacing: 14) {
            tabBar(palette)
            switch settings.selectedTab {
            case .claude: claudeTab(palette)
            case .gemini: geminiTab(palette)
            }
            footer(palette)
        }
        .padding(16)
        .frame(width: 300)
        .background(palette.background)
    }

    // MARK: Tabs

    @ViewBuilder
    private func tabBar(_ palette: RetroPalette) -> some View {
        HStack(spacing: 6) {
            ForEach(ProviderTab.allCases, id: \.self) { tab in
                Button {
                    settings.selectedTab = tab
                } label: {
                    Text(tab.rawValue.uppercased())
                        .font(PixelFont.swiftUI(size: 8))
                        .foregroundStyle(settings.selectedTab == tab
                                         ? palette.background : palette.textPrimary.opacity(0.7))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(settings.selectedTab == tab ? palette.accentCyan : palette.surface)
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
    }

    // MARK: Claude tab

    @ViewBuilder
    private func claudeTab(_ palette: RetroPalette) -> some View {
        header(palette)
        sectionHeader("QUOTA", palette)
        quotaContent(palette)
        sectionHeader("ACTIVITY 24H", palette)
        activitySection(palette)
    }

    @ViewBuilder
    private func header(_ palette: RetroPalette) -> some View {
        HStack {
            Text(store.currentSnapshot?.planName ?? "AI QUOTA")
                .font(PixelFont.swiftUI(size: 9))
                .foregroundStyle(palette.accentCyan)
            Spacer()
            AvatarSpriteView(sprite: SpriteLibrary.sprite(forProvider: "claude"),
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
    private func sectionHeader(_ title: String, _ palette: RetroPalette) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(PixelFont.swiftUI(size: 7))
                .foregroundStyle(palette.accentPink)
            Rectangle()
                .fill(palette.textPrimary.opacity(0.2))
                .frame(height: 1)
        }
    }

    @ViewBuilder
    private func quotaContent(_ palette: RetroPalette) -> some View {
        switch store.state {
        case .loading:
            stateScreen("LOADING", hint: "Loading quota…", palette: palette)
        case .credentialsMissing:
            stateScreen("INSERT COIN",
                        hint: "Install and sign in to Claude Code first — this app reads its quota data.",
                        palette: palette)
        case .tokenExpired:
            stateScreen("TOKEN EXPIRED",
                        hint: "Use Claude Code once to renew the token, then this app recovers automatically.",
                        palette: palette)
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
                    .font(.system(.caption, design: .monospaced))
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
                Text(RelativeTimeFormatter.string(since: last.fetchedAt, now: Date()))
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(palette.textPrimary.opacity(0.6))
            }
        }
    }

    // MARK: Activity

    @ViewBuilder
    private func activitySection(_ palette: RetroPalette) -> some View {
        if let summary = activity.summary {
            if summary.topSkills.isEmpty && summary.topAgents.isEmpty && summary.sessionCount == 0 {
                Text("NO ACTIVITY")
                    .font(PixelFont.swiftUI(size: 8))
                    .foregroundStyle(palette.textPrimary.opacity(0.5))
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    if !summary.topSkills.isEmpty {
                        activityGroup("SKILLS", items: summary.topSkills,
                                      total: summary.skillEventCount, palette: palette)
                    }
                    if !summary.topAgents.isEmpty {
                        activityGroup("AGENTS", items: summary.topAgents,
                                      total: summary.agentEventCount, palette: palette)
                    }
                    Text("SESSIONS \(summary.sessionCount)")
                        .font(PixelFont.swiftUI(size: 7))
                        .foregroundStyle(palette.textPrimary.opacity(0.8))
                }
            }
        } else {
            Text(activity.isScanning ? "SCANNING…" : "NO ACTIVITY")
                .font(PixelFont.swiftUI(size: 8))
                .foregroundStyle(palette.textPrimary.opacity(0.5))
        }
    }

    @ViewBuilder
    private func activityGroup(_ title: String, items: [ActivityCount],
                               total: Int, palette: RetroPalette) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(PixelFont.swiftUI(size: 7))
                .foregroundStyle(palette.accentCyan)
            ForEach(items, id: \.name) { item in
                HStack {
                    Text(item.name)
                        .font(.system(.caption, design: .monospaced))
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .foregroundStyle(palette.textPrimary)
                    Spacer()
                    Text("\(ActivitySummary.percentShare(item.count, of: total))%")
                        .font(PixelFont.swiftUI(size: 7))
                        .foregroundStyle(palette.textPrimary.opacity(0.7))
                }
            }
        }
    }

    // MARK: Gemini tab

    @ViewBuilder
    private func geminiTab(_ palette: RetroPalette) -> some View {
        VStack(spacing: 12) {
            AvatarSpriteView(sprite: SpriteLibrary.sprite(forProvider: "gemini"),
                             color: palette.accentCyan, pixelScale: 3)
            Text("INSERT CARTRIDGE")
                .font(PixelFont.swiftUI(size: 11))
                .foregroundStyle(palette.accentPink)
            Text("Gemini support is coming soon.")
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(palette.textPrimary.opacity(0.8))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
    }

    // MARK: Footer

    @ViewBuilder
    private func footer(_ palette: RetroPalette) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Rectangle()
                .fill(palette.textPrimary.opacity(0.2))
                .frame(height: 1)
            HStack {
                TimelineView(.periodic(from: .now, by: 30)) { context in
                    Text(updatedLabel(now: context.date))
                        .font(PixelFont.swiftUI(size: 6))
                        .foregroundStyle(palette.textPrimary.opacity(0.6))
                }
                Spacer()
                Button(action: onOpenSettings) {
                    Text("⚙ SETTINGS")
                        .font(PixelFont.swiftUI(size: 7))
                        .foregroundStyle(palette.textPrimary.opacity(0.7))
                }
                .buttonStyle(.plain)
                Button(action: onQuit) {
                    Text("⏻ QUIT")
                        .font(PixelFont.swiftUI(size: 7))
                        .foregroundStyle(palette.textPrimary.opacity(0.7))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func updatedLabel(now: Date) -> String {
        guard let fetched = store.currentSnapshot?.fetchedAt else { return "UPDATED --" }
        return "UPDATED " + RelativeTimeFormatter.string(since: fetched, now: now)
    }
}
