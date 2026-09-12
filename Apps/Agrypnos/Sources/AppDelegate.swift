import AppKit

#if canImport(AgrypnosCore)
import AgrypnosCore
#endif

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, WatchRuntimeDelegate {
    private let runtime = WatchRuntime()
    private var statusItem: StatusItemController!
    private var popover: PopoverController!
    private let hotkey = GlobalHotkeyCenter()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        popover = PopoverController(runtime: runtime)
        statusItem = StatusItemController(runtime: runtime, popover: popover)
        runtime.delegate = self
        runtime.start()
        hotkey.onTrigger = { [weak self] in
            self?.runtime.toggle()
        }
        hotkey.register(runtime.preferences.hotkey)
    }

    func applicationWillTerminate(_ notification: Notification) {
        if runtime.engaged {
            runtime.setEngaged(false)
        }
        hotkey.unregister()
    }

    func watchRuntimeDidChange(_ runtime: WatchRuntime) {
        statusItem.refresh()
    }
}
