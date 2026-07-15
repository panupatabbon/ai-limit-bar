import AppKit
import SwiftUI

@MainActor
public final class StatusItemController {
    private let store: QuotaStore
    private let settings: AppSettings
    private let activityStore: ActivityStore
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private var tickTimer: Timer?
    private var frameIndex = 0
    private var lastSpec: MenuBarImageBuilder.Spec?
    private lazy var settingsWindow = SettingsWindowController(settings: settings)

    public init(store: QuotaStore, settings: AppSettings, activity: ActivityStore) {
        self.store = store
        self.settings = settings
        self.activityStore = activity
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
            rootView: QuotaPopoverView(store: store, settings: settings,
                                       activity: activityStore) { [weak self] in
                self?.popover?.performClose(nil)
                self?.settingsWindow.show()
            } onQuit: {
                NSApp.terminate(nil)
            })
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

    private func render() {
        guard let button = statusItem?.button else { return }
        let headline = store.headlineLimit(pin: settings.headlinePin)
        let frames = SpriteLibrary.sprite(forProvider: "claude").menuBarFrames
        let spec = Self.menuBarSpec(
            headline: headline, state: store.state,
            showPercent: settings.showPercentInMenuBar,
            frame: frames[frameIndex % frames.count])
        guard spec != lastSpec else { return }
        lastSpec = spec
        button.image = MenuBarImageBuilder.image(for: spec)
        button.attributedTitle = NSAttributedString(string: "")
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

    public static func menuBarSpec(headline: QuotaLimit?, state: QuotaStore.State,
                                   showPercent: Bool,
                                   frame: SpriteFrame) -> MenuBarImageBuilder.Spec {
        let title = menuBarTitle(headline: headline, state: state, showPercent: showPercent)
        let bar: Double?
        switch state {
        case .ready, .offline:
            bar = headline.map { min(max($0.percentUsed / 100, 0), 1) }
        default:
            bar = nil
        }
        // Menu bar renders white always (user preference); quota severity
        // colors remain in the popover.
        return MenuBarImageBuilder.Spec(
            frame: frame,
            percentText: title.isEmpty ? nil : title,
            barFraction: bar,
            color: .white)
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
            activityStore.refreshIfStale()
            // NSStatusBarButton is a flipped view: .maxY is the visual bottom,
            // so the popover hangs below the menu bar instead of hugging its top.
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .maxY)
            // NSPopover still anchors slightly into the menu bar; pin the
            // popover window's top edge just below the status bar's bottom.
            if let popoverWindow = popover.contentViewController?.view.window,
               let statusWindow = button.window {
                var frame = popoverWindow.frame
                frame.origin.y = (statusWindow.frame.minY - 2) - frame.height
                popoverWindow.setFrame(frame, display: true)
            }
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
