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
        AppEditMenu.install()
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

/// LSUIElement extras do not show a menu bar. Cmd+V still needs an Edit menu.
/// Do not also send paste from a popover key monitor — that inserts twice.
@MainActor
enum AppEditMenu {
    static func install() {
        let main = NSMenu()
        let appItem = NSMenuItem()
        appItem.submenu = NSMenu(title: "Agrypnos")
        main.addItem(appItem)
        let editItem = NSMenuItem()
        let edit = NSMenu(title: "Edit")
        edit.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: PopoverEditKeyChrome.menuCut)
        edit.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: PopoverEditKeyChrome.menuCopy)
        edit.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: PopoverEditKeyChrome.menuPaste)
        edit.addItem(NSMenuItem.separator())
        edit.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: PopoverEditKeyChrome.menuSelectAll)
        editItem.submenu = edit
        main.addItem(editItem)
        NSApp.mainMenu = main
    }
}
