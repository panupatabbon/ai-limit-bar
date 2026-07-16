import SwiftUI

public struct SettingsView: View {
    @Bindable var settings: AppSettings
    @State private var launchAtLogin = LoginItem.isEnabled

    public init(settings: AppSettings) {
        self.settings = settings
    }

    private var palette: RetroPalette { RetroTheme.jules }

    public var body: some View {
        let palette = self.palette
        VStack(alignment: .leading, spacing: 16) {
            section("GENERAL", palette) {
                Toggle("Launch at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, enabled in
                        do { try LoginItem.setEnabled(enabled) } catch {
                            // Registration can fail for unsigned builds
                            // outside /Applications — reflect reality.
                            launchAtLogin = LoginItem.isEnabled
                        }
                    }
            }
            section("DISPLAY", palette) {
                Toggle("Show % in menu bar", isOn: $settings.showPercentInMenuBar)
                Picker("Menu bar % tracks", selection: $settings.headlinePin) {
                    Text("Auto (most used)").tag(HeadlinePin.auto)
                    Text("Session").tag(HeadlinePin.session)
                    Text("Weekly total").tag(HeadlinePin.weekly)
                }
                Text("Visible limits")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(palette.textPrimary.opacity(0.7))
                Toggle("Session (5-hour)", isOn: $settings.showSession)
                Toggle("Weekly total (all models)", isOn: $settings.showWeeklyAll)
                Toggle("Weekly per model", isOn: $settings.showWeeklyModels)
                Toggle("Compact rows", isOn: $settings.compactRows)
            }
        }
        .font(.system(.body, design: .monospaced))
        .padding(20)
        .frame(width: 340)
        .background(palette.background)
        .foregroundStyle(palette.textPrimary)
        .tint(palette.accentCyan)
        .preferredColorScheme(.dark)
    }

    @ViewBuilder
    private func section(_ title: String, _ palette: RetroPalette,
                         @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .pixelType(size: 8)
                    .foregroundStyle(palette.accentPink)
                Rectangle()
                    .fill(palette.textPrimary.opacity(0.2))
                    .frame(height: 1)
            }
            content()
        }
    }
}
