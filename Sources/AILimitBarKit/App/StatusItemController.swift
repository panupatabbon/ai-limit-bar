import AppKit
import SwiftUI

@MainActor
public final class StatusItemController {
    private let hub: ProviderHub
    private let settings: AppSettings
    private let activityStore: ActivityStore
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private var tickTimer: Timer?
    private var frameIndex = 0
    private var lastSpecs: [MenuBarImageBuilder.Spec]?
    private lazy var settingsWindow = SettingsWindowController(settings: settings)

    public init(hub: ProviderHub, settings: AppSettings, activity: ActivityStore) {
        self.hub = hub
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
            rootView: QuotaPopoverView(hub: hub, settings: settings,
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
        // Animation steps tolerate ±0.2s drift; coalesced wake-ups cost less
        // energy for an all-day resident.
        tickTimer?.tolerance = 0.2
        tick()
    }

    private func tick() {
        // Pause the idle animation in Low Power Mode (still updates numbers).
        if !ProcessInfo.processInfo.isLowPowerModeEnabled {
            frameIndex += 1
        }
        hub.sync(enabled: settings.enabledProviders)
        render()
    }

    private func render() {
        guard let button = statusItem?.button else { return }
        let darkAppearance = button.effectiveAppearance
            .bestMatch(from: [.darkAqua, .aqua]) == .darkAqua

        let describedID = Self.openTab(hottest: hub.hottest(pin: settings.headlinePin),
                                       enabled: hub.orderedLive)
        if let store = hub.store(for: describedID) {
            let base = Self.statusDescription(
                headline: store.headlineLimit(pin: settings.headlinePin), state: store.state)
            let description = Self.prefixedStatusDescription(
                name: ProviderCatalog.descriptor(for: describedID).displayName,
                multi: hub.orderedEnabled.count > 1, base: base)
            button.toolTip = description
            button.setAccessibilityLabel(description)
        }

        let specs: [MenuBarImageBuilder.Spec] = hub.orderedLive.compactMap { id in
            guard let store = hub.store(for: id) else { return nil }
            let headline = store.headlineLimit(pin: settings.headlinePin)
            let sprite = SpriteLibrary.sprite(forProvider: id.rawValue)
            // The mascot's body language follows the headline severity: calm at
            // rest (occasional blink), pacing when a limit runs hot.
            let mood: SpriteMood
            switch store.state {
            case .ready, .offline:
                mood = SpriteMood(severity: headline.map { Severity(percent: $0.percentUsed) })
            default:
                mood = .calm
            }
            return Self.menuBarSpec(headline: headline, state: store.state,
                                    showPercent: settings.showPercentInMenuBar,
                                    frame: sprite.frame(mood: mood, tick: frameIndex),
                                    darkAppearance: darkAppearance)
        }
        guard specs != lastSpecs else { return }
        lastSpecs = specs
        button.image = MenuBarImageBuilder.image(for: specs)
        button.attributedTitle = NSAttributedString(string: "")
    }

    public static func openTab(hottest: ProviderID?, enabled: [ProviderID]) -> ProviderID {
        hottest ?? enabled.first ?? .claude
    }

    public static func prefixedStatusDescription(name: String, multi: Bool, base: String) -> String {
        multi ? "\(name): \(base)" : base
    }

    /// One sentence for the status item's toolTip AND accessibility label —
    /// the app's front door must not be mute (hover explains "!"/"--";
    /// VoiceOver gets the headline and reset without opening anything).
    public static func statusDescription(headline: QuotaLimit?, state: QuotaStore.State,
                                         now: Date = Date()) -> String {
        switch state {
        case .credentialsMissing:
            return "AI Limit Bar — sign in to Claude Code to see quota"
        case .tokenExpired:
            return "AI Limit Bar — token expired, use Claude Code once to renew"
        case .loading:
            return "AI Limit Bar — loading quota"
        case .ready, .offline:
            guard let headline else { return "AI Limit Bar — no quota data" }
            let reset: String
            switch headline.kind {
            case .session:
                reset = ResetFormatter.spokenSessionCountdown(until: headline.resetsAt, from: now)
            case .weeklyAll, .weeklyModel:
                reset = ResetFormatter.spokenWeeklyReset(headline.resetsAt)
            }
            var text = "\(LimitRowView.kindLabel(headline.kind).capitalized) "
                + "\(Int(headline.percentUsed))% used — \(reset)"
            if case .offline = state { text += " (offline)" }
            return text
        }
    }

    public static func menuBarTitle(headline: QuotaLimit?, state: QuotaStore.State,
                                    showPercent: Bool) -> String {
        switch state {
        case .credentialsMissing, .tokenExpired:
            // Needs the user (sign in / renew) — distinct from "no data yet".
            return "!"
        case .loading:
            return "--"
        case .ready, .offline:
            guard showPercent else { return "" }
            guard let headline else { return "--" }
            return "\(Int(headline.percentUsed))%"
        }
    }

    public static func menuBarSpec(headline: QuotaLimit?, state: QuotaStore.State,
                                   showPercent: Bool,
                                   frame: SpriteFrame,
                                   darkAppearance: Bool) -> MenuBarImageBuilder.Spec {
        let title = menuBarTitle(headline: headline, state: state, showPercent: showPercent)
        let bar: Double?
        switch state {
        case .ready, .offline:
            bar = headline.map { min(max($0.percentUsed / 100, 0), 1) }
        default:
            bar = nil
        }
        // The whole item wears the headline limit's severity color
        // (DESIGN.md §Menu Bar Item) in the system appearance's variant;
        // neutral (white on dark, black on light) until data exists, and
        // Warning Gold when the app needs the user ("!").
        let neutral: NSColor = darkAppearance ? .white : .black
        let color: NSColor
        switch state {
        case .ready, .offline:
            color = headline.map {
                RetroTheme.menuBarColor(for: Severity(percent: $0.percentUsed),
                                        darkAppearance: darkAppearance)
            } ?? neutral
        case .credentialsMissing, .tokenExpired:
            color = RetroTheme.menuBarColor(for: .warn, darkAppearance: darkAppearance)
        case .loading:
            color = neutral
        }
        return MenuBarImageBuilder.Spec(
            frame: frame,
            percentText: title.isEmpty ? nil : title,
            barFraction: bar,
            color: color)
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
            // Every open answers the glance of whichever provider needs
            // attention most; falls back to the first enabled provider.
            settings.selectedTab = Self.openTab(hottest: hub.hottest(pin: settings.headlinePin),
                                                enabled: hub.orderedEnabled)
            for id in hub.orderedLive {
                if let store = hub.store(for: id) {
                    Task { await store.refreshIfStale(olderThan: 10) }
                }
            }
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
