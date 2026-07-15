import SwiftUI

public struct SettingsView: View {
    @Bindable var settings: AppSettings

    public init(settings: AppSettings) {
        self.settings = settings
    }

    private var palette: RetroPalette { RetroTheme.jules }

    public var body: some View {
        let palette = self.palette
        VStack(alignment: .leading, spacing: 16) {
            section("DISPLAY", palette) {
                Toggle("Show % in menu bar", isOn: $settings.showPercentInMenuBar)
                Picker("Menu bar % tracks", selection: $settings.headlinePin) {
                    Text("Auto (most used)").tag(HeadlinePin.auto)
                    Text("Session").tag(HeadlinePin.session)
                    Text("Weekly").tag(HeadlinePin.weekly)
                }
                Text("Visible limits")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(palette.textPrimary.opacity(0.6))
                Toggle("Session (5-hour)", isOn: $settings.showSession)
                Toggle("Weekly (all models)", isOn: $settings.showWeeklyAll)
                Toggle("Weekly (per model)", isOn: $settings.showWeeklyModels)
                Toggle("Compact rows", isOn: $settings.compactRows)
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
            Text(title)
                .font(PixelFont.swiftUI(size: 8))
                .foregroundStyle(palette.accentPink)
            content()
        }
    }
}
