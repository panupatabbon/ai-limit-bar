import AppKit

public final class AppDelegate: NSObject, NSApplicationDelegate {
    private var controller: StatusItemController?
    private var store: QuotaStore?

    public func applicationDidFinishLaunching(_ notification: Notification) {
        PixelFont.registerBundledFont()
        let settings = AppSettings()
        let store = QuotaStore(provider: ClaudeProvider())
        let controller = StatusItemController(store: store, settings: settings)
        self.store = store
        self.controller = controller
        controller.start()
        store.startPolling(interval: 60)
    }
}
