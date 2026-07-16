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

    /// "NO DATA" must name its cause — an all-hidden filter is the user's own
    /// doing and shouldn't read like a fetch failure.
    public static func noDataHint(allHidden: Bool) -> String {
        allHidden
            ? "All limits are hidden. Turn one back on in Settings."
            : "Your plan reported no limits yet. Try again after using Claude."
    }

    private var palette: RetroPalette { RetroTheme.jules }

    public var body: some View {
        let palette = self.palette
        // Rhythm: 16pt between zones (tabs / header / sections / footer),
        // 8pt binds a section header to its own content (see claudeTab).
        VStack(alignment: .leading, spacing: 16) {
            tabBar(palette)
            switch settings.selectedTab {
            case .claude: claudeTab(palette)
            case .gemini: geminiTab(palette)
            }
            footer(palette)
        }
        .padding(16)
        // Width derives from the HP bar's pixel grid: 266pt bar + 32pt
        // padding, so every right edge lands on the same 266pt measure.
        .frame(width: PixelProgressBar.totalWidth + 32)
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
                        .pixelType(size: 8)
                        .foregroundStyle(settings.selectedTab == tab
                                         ? palette.background : palette.textPrimary.opacity(0.7))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(settings.selectedTab == tab ? palette.accentCyan : palette.surface)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(tab.rawValue.capitalized) tab")
                .accessibilityAddTraits(settings.selectedTab == tab ? [.isSelected] : [])
                .pixelFocusRing()
            }
            Spacer()
        }
    }

    // MARK: Claude tab

    @ViewBuilder
    private func claudeTab(_ palette: RetroPalette) -> some View {
        header(palette)
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("QUOTA", palette)
            quotaContent(palette)
        }
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("ACTIVITY 24H", palette)
            activitySection(palette)
        }
    }

    @ViewBuilder
    private func header(_ palette: RetroPalette) -> some View {
        HStack {
            Text(store.currentSnapshot?.planName ?? "AI QUOTA")
                .pixelType(size: 9)
                .foregroundStyle(palette.accentCyan)
            Spacer()
            AvatarSpriteView(sprite: SpriteLibrary.sprite(forProvider: "claude"),
                             color: headlineColor(palette), pixelScale: 2,
                             mood: SpriteMood(severity: headlineSeverity))
        }
    }

    private var headlineSeverity: Severity? {
        store.headlineLimit(pin: settings.headlinePin)
            .map { Severity(percent: $0.percentUsed) }
    }

    private func headlineColor(_ palette: RetroPalette) -> Color {
        guard let severity = headlineSeverity else {
            return palette.textPrimary.opacity(0.5)
        }
        return RetroTheme.color(for: severity, in: palette)
    }

    @ViewBuilder
    private func sectionHeader(_ title: String, _ palette: RetroPalette) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .pixelType(size: 7)
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
            stateScreen("LOADING", hint: "Reading usage from your Claude Code account…",
                        palette: palette)
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
            let allHidden = !(store.currentSnapshot?.limits ?? []).isEmpty
            stateScreen("NO DATA", hint: Self.noDataHint(allHidden: allHidden), palette: palette)
        } else {
            VStack(alignment: .leading, spacing: 12) {
                // Identity by kind (unique per snapshot), not position — rows
                // keep their identity if the API ever reorders limits.
                ForEach(limits, id: \.kind) { limit in
                    LimitRowView(limit: limit, palette: palette, compact: settings.compactRows)
                }
            }
        }
    }

    @ViewBuilder
    private func stateScreen(_ title: String, hint: String, palette: RetroPalette) -> some View {
        VStack(spacing: 8) {
            Text(title)
                .pixelType(size: 12)
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
                .pixelType(size: 7)
                .foregroundStyle(palette.warn)
            if let last {
                Text(RelativeTimeFormatter.string(since: last.fetchedAt, now: Date()))
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(palette.textPrimary.opacity(0.6))
            }
            Spacer()
            // Auto-retry keeps running underneath (backoff up to 5 min);
            // this makes the recovery path visible and immediate.
            Button {
                Task { await store.refresh() }
            } label: {
                HStack(spacing: 2) {
                    Text("RETRY")
                        .pixelType(size: 7)
                    Text("▶")
                        .font(.system(size: 8))
                }
                .foregroundStyle(palette.accentCyan)
                .contentShape(Rectangle().inset(by: -6))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Retry now")
            .pixelFocusRing()
        }
    }

    // MARK: Activity

    @ViewBuilder
    private func activitySection(_ palette: RetroPalette) -> some View {
        if let summary = activity.summary {
            if summary.topSkills.isEmpty && summary.topAgents.isEmpty && summary.sessionCount == 0 {
                Text("NO ACTIVITY")
                    .pixelType(size: 8)
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
                        .help("Claude Code sessions in the last 24 hours")
                        .accessibilityLabel("\(summary.sessionCount) Claude Code sessions in the last 24 hours")
                        .pixelType(size: 7)
                        .foregroundStyle(palette.textPrimary.opacity(0.8))
                }
            }
        } else {
            Text(activity.isScanning ? "SCANNING…" : "NO ACTIVITY")
                .pixelType(size: 8)
                .foregroundStyle(palette.textPrimary.opacity(0.5))
        }
    }

    @ViewBuilder
    private func activityGroup(_ title: String, items: [ActivityCount],
                               total: Int, palette: RetroPalette) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .pixelType(size: 7)
                    .foregroundStyle(palette.accentCyan)
                Spacer()
                // Labels the % column: these are event shares, not quota.
                Text("% OF EVENTS")
                    .pixelType(size: 6)
                    .foregroundStyle(palette.textPrimary.opacity(0.5))
            }
            ForEach(items, id: \.name) { item in
                HStack {
                    Text(item.name)
                        .font(.system(.caption, design: .monospaced))
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .foregroundStyle(palette.textPrimary)
                    Spacer()
                    Text("\(ActivitySummary.percentShare(item.count, of: total))%")
                        .pixelType(size: 7)
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
                .pixelType(size: 12)
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
                        .pixelType(size: 6)
                        .foregroundStyle(palette.textPrimary.opacity(0.6))
                }
                Spacer()
                Button(action: onOpenSettings) {
                    // Symbol glyphs don't exist in Press Start 2P — render
                    // them via the system face, same treatment as ◀ and ▶.
                    HStack(spacing: 2) {
                        Text("⚙").font(.system(size: 8))
                        Text("SETTINGS").pixelType(size: 7)
                    }
                    .foregroundStyle(palette.textPrimary.opacity(0.7))
                    .contentShape(Rectangle().inset(by: -6))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Settings")
                .pixelFocusRing()
                Button(action: onQuit) {
                    HStack(spacing: 2) {
                        Text("⏻").font(.system(size: 8))
                        Text("QUIT").pixelType(size: 7)
                    }
                    .foregroundStyle(palette.textPrimary.opacity(0.7))
                    .contentShape(Rectangle().inset(by: -6))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Quit")
                .pixelFocusRing()
            }
        }
    }

    private func updatedLabel(now: Date) -> String {
        guard let fetched = store.currentSnapshot?.fetchedAt else { return "UPDATED --" }
        return "UPDATED " + RelativeTimeFormatter.string(since: fetched, now: now)
    }
}
