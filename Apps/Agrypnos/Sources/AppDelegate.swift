import AppKit
import UserNotifications

#if canImport(AgrypnosCore)
import AgrypnosCore
#endif

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, WatchRuntimeDelegate, UNUserNotificationCenterDelegate {
    private let runtime = WatchRuntime()
    private var statusItem: StatusItemController!
    private var popover: PopoverController!
    private let hotkey = GlobalHotkeyCenter()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        if Bundle.main.bundleURL.pathExtension == "app" {
            UNUserNotificationCenter.current().delegate = self
        }
        UserNotify.requestPermission()
        guard runtime.start() else {
            Self.handOffToRunningCopy()
            NSApp.terminate(nil)
            return
        }
        DistributedNotificationCenter.default().addObserver(
            forName: Self.showPopover, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.statusItem.showPopover() }
        }
        AppEditMenu.install()
        PopoverCopyLayout.measureLines = PopoverTextMeasure.lines
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
    }

    static let showPopover = Notification.Name("app.agrypnos.Agrypnos.showPopover")

    /// A second launch (say, login item plus Finder) opens the running copy's popover instead.
    private static func handOffToRunningCopy() {
        let others = NSRunningApplication.runningApplications(withBundleIdentifier: Bundle.main.bundleIdentifier ?? "")
            .filter { $0 != NSRunningApplication.current }
        if others.isEmpty {
            UserNotify.post("Couldn't take ownership of the wake hold. Quit any other copy of Agrypnos, then open it again.")
        } else {
            DistributedNotificationCenter.default().postNotificationName(showPopover, object: nil, deliverImmediately: true)
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        runtime.prepareForTermination()
        hotkey.unregister()
    }

    func watchRuntimeDidChange(_ runtime: WatchRuntime) {
        statusItem.refresh()
    }

    /// Show banners even while the popover makes Agrypnos the active app.
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification,
                                            withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }
}

/// LSUIElement extras do not show a menu bar. Cmd+V still needs an Edit menu.
@MainActor
enum AppEditMenu {
    static func install() {
        let main = NSMenu()
        let appItem = NSMenuItem()
        appItem.submenu = NSMenu(title: "Agrypnos")
        appItem.submenu?.addItem(withTitle: "Close Window", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        main.addItem(appItem)
        let editItem = NSMenuItem()
        let edit = NSMenu(title: "Edit")
        edit.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        edit.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        edit.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        edit.addItem(NSMenuItem.separator())
        edit.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editItem.submenu = edit
        main.addItem(editItem)
        NSApp.mainMenu = main
    }
}
