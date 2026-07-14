import AppKit
import SwiftUI

@MainActor
public final class StatusItemController {
    private let store: QuotaStore
    private let settings: AppSettings
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private var tickTimer: Timer?
    private var frameIndex = 0
    private lazy var settingsWindow = SettingsWindowController(settings: settings)

    public init(store: QuotaStore, settings: AppSettings) {
        self.store = store
        self.settings = settings
    }

    public func start() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.target = self
        item.button?.action = #selector(handleClick)
        item.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
        statusItem = item

        let popover = NSPopover()
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(
            rootView: QuotaPopoverView(store: store, settings: settings, onOpenSettings: { [weak self] in
                self?.popover?.performClose(nil)
                self?.settingsWindow.show()
            }, onQuit: {
                NSApp.terminate(nil)
            }))
        self.popover = popover

        tickTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        tick()
    }

    private func tick() {
        // Pause the idle animation in Low Power Mode (still updates numbers).
        if !ProcessInfo.processInfo.isLowPowerModeEnabled {
            frameIndex += 1
        }
        render()
    }

    private var systemIsDark: Bool {
        NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
    }

    private func render() {
        guard let button = statusItem?.button else { return }
        let palette = RetroTheme.palette(settings.theme, systemIsDark: systemIsDark)
        let headline = store.headlineLimit(pin: settings.headlinePin)
        let color = Self.menuBarColor(headline: headline, state: store.state, palette: palette)
        let sprite = SpriteLibrary.sprite(for: settings.avatar)
        let frames = sprite.menuBarFrames
        button.image = frames[frameIndex % frames.count].nsImage(color: color, pixelSize: 1.1)
        button.image?.isTemplate = false

        let title = Self.menuBarTitle(headline: headline, state: store.state,
                                      showPercent: settings.showPercentInMenuBar)
        button.attributedTitle = NSAttributedString(
            string: title.isEmpty ? "" : " " + title,
            attributes: [
                .font: PixelFont.nsFont(size: 9),
                .foregroundColor: color,
                .baselineOffset: 1,
            ])
    }

    public static func menuBarTitle(headline: QuotaLimit?, state: QuotaStore.State,
                                    showPercent: Bool) -> String {
        switch state {
        case .credentialsMissing, .tokenExpired, .loading:
            return "--"
        case .ready, .offline:
            guard showPercent else { return "" }
            guard let headline else { return "--" }
            return "\(Int(headline.percentUsed))%"
        }
    }

    public static func menuBarColor(headline: QuotaLimit?, state: QuotaStore.State,
                                    palette: RetroPalette) -> NSColor {
        switch state {
        case .credentialsMissing, .tokenExpired, .loading:
            return .systemGray
        case .ready, .offline:
            guard let headline else { return .systemGray }
            return NSColor(RetroTheme.color(for: Severity(percent: headline.percentUsed),
                                            in: palette))
        }
    }

    @objc private func handleClick() {
        guard let button = statusItem?.button else { return }
        if NSApp.currentEvent?.type == .rightMouseUp {
            showRightClickMenu(for: button)
            return
        }
        guard let popover else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            Task { await store.refreshIfStale(olderThan: 10) }
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    private func showRightClickMenu(for button: NSStatusBarButton) {
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Quit AI Limit Bar",
                                 action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.height), in: button)
    }
}
