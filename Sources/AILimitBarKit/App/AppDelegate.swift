import AppKit

public final class AppDelegate: NSObject, NSApplicationDelegate {
    private var controller: StatusItemController?
    private var hub: ProviderHub?

    public func applicationDidFinishLaunching(_ notification: Notification) {
        PixelFont.registerBundledFont()
        let settings = AppSettings()
        let hub = ProviderHub()
        hub.sync(enabled: settings.enabledProviders)
        let activity = ActivityStore()
        let controller = StatusItemController(hub: hub, settings: settings, activity: activity)
        self.hub = hub
        self.controller = controller
        controller.start()
    }
}
