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
        hotkey.onTrigger = { [weak self] in
            self?.runtime.toggle()
        }
        runtime.bindHotkey = { [weak self] chord in
            self?.hotkey.register(chord) ?? false
        }
        runtime.unbindHotkey = { [weak self] in
            self?.hotkey.unregister()
        }
        let registered = hotkey.register(runtime.preferences.hotkey)
        runtime.hotkeyRegistered = registered
        if !registered {
            UserNotify.post(AgrypnosCopy.hotkeyHint(runtime.preferences.hotkey, registered: false))
        }
        popover = PopoverController(runtime: runtime)
        statusItem = StatusItemController(runtime: runtime, popover: popover)
        runtime.delegate = self
        runtime.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        runtime.prepareForTermination()
        hotkey.unregister()
    }

    func watchRuntimeDidChange(_ runtime: WatchRuntime) {
        statusItem.refresh()
    }
}
