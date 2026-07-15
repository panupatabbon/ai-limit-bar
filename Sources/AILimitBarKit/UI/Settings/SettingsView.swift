import SwiftUI

public struct SettingsView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Bindable var settings: AppSettings

    public init(settings: AppSettings) {
        self.settings = settings
    }

    private var palette: RetroPalette {
        RetroTheme.palette(settings.theme, systemIsDark: colorScheme == .dark)
    }

    private func t(_ key: L10nKey) -> String { L10n.t(key, settings.language) }

    public var body: some View {
        let palette = self.palette
        VStack(alignment: .leading, spacing: 16) {
            section(t(.settingsGeneral), palette) {
                Picker(t(.settingsLanguage), selection: $settings.language) {
                    Text("English").tag(AppLanguage.en)
                    Text("ไทย").tag(AppLanguage.th)
                }
                Picker(t(.settingsTheme), selection: $settings.theme) {
                    Text(t(.themeSystem)).tag(ThemePreference.system)
                    Text(t(.themeDark)).tag(ThemePreference.dark)
                    Text(t(.themeLight)).tag(ThemePreference.light)
                }
            }
            section(t(.settingsDisplay), palette) {
                Toggle(t(.showPercent), isOn: $settings.showPercentInMenuBar)
                Picker(t(.headlinePinLabel), selection: $settings.headlinePin) {
                    Text(t(.pinAuto)).tag(HeadlinePin.auto)
                    Text(t(.pinSession)).tag(HeadlinePin.session)
                    Text(t(.pinWeekly)).tag(HeadlinePin.weekly)
                }
                Text(t(.visibleLimits))
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(palette.textPrimary.opacity(0.6))
                Toggle(t(.limitSession), isOn: $settings.showSession)
                Toggle(t(.limitWeeklyAll), isOn: $settings.showWeeklyAll)
                Toggle(t(.limitWeeklyModels), isOn: $settings.showWeeklyModels)
                Toggle(t(.compactRows), isOn: $settings.compactRows)
            }
        }
        .padding(20)
        .frame(width: 340)
        .background(palette.background)
        .foregroundStyle(palette.textPrimary)
        .tint(palette.accentCyan)
    }

    @ViewBuilder
    private func section(_ title: String, _ palette: RetroPalette,
                         @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(PixelFont.swiftUI(size: 8))
                .foregroundStyle(palette.accentPink)
            content()
        }
    }
}
