import AppKit
import SwiftUI

@MainActor
final class SettingsWindowController {
    private let settings: AppSettings
    private var window: NSWindow?

    init(settings: AppSettings) {
        self.settings = settings
    }

    func show() {
        if window == nil {
            let hosting = NSHostingController(rootView: SettingsView(settings: settings))
            let window = NSWindow(contentViewController: hosting)
            window.title = "AI LIMIT BAR"
            window.styleMask = [.titled, .closable]
            window.isReleasedWhenClosed = false
            // The content is dark-only by doctrine; pin the window to dark
            // appearance so native controls and the title bar match instead
            // of following a light system theme onto the purple background.
            window.appearance = NSAppearance(named: .darkAqua)
            window.titlebarAppearsTransparent = true
            window.backgroundColor = RetroTheme.nsBackground
            self.window = window
        }
        window?.center()
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
