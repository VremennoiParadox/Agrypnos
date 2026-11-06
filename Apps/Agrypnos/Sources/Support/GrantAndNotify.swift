import AppKit
import UserNotifications

#if canImport(AgrypnosCore)
import AgrypnosCore
#endif

/// Local Mac banners, shown as Agrypnos. Not the Notif path: bots stay the only Notif channel.
enum UserNotify {
    /// Asks once. A denied permission leaves banners off; the popover still shows state.
    static func requestPermission() {
        center?.requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    static func post(_ message: String) {
        guard let center else { return }
        let content = UNMutableNotificationContent()
        content.title = AgrypnosCopy.appName
        content.body = message
        content.sound = .default
        center.add(UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil))
    }

    /// The notification center needs a real app bundle. Test runners and command-line hosts have none.
    private static var center: UNUserNotificationCenter? {
        Bundle.main.bundleURL.pathExtension == "app" ? .current() : nil
    }

    static func post(reason: DisengageReason) {
        post(AgrypnosCopy.notification(for: reason))
    }
}

enum GrantInstaller {
    @discardableResult
    static func installViaNativeAuth() -> Bool {
        let grant: String
        if let bundled = Bundle.main.path(forResource: "grant", ofType: "sh") {
            grant = bundled
        } else {
            grant = FileManager.default.currentDirectoryPath + "/Scripts/grant.sh"
        }
        guard let osa = GrantLaunch.osascriptSource(username: NSUserName(), scriptPath: grant) else {
            let fail = NSAlert()
            fail.alertStyle = .warning
            fail.messageText = "Couldn't install the grant"
            fail.informativeText = "This account name isn't safe for the installer. See SECURITY.md."
            fail.addButton(withTitle: "OK")
            NSApp.activate(ignoringOtherApps: true)
            fail.runModal()
            return false
        }

        let intro = NSAlert()
        intro.alertStyle = .informational
        intro.messageText = "Let Agrypnos keep awake"
        intro.informativeText = AgrypnosCopy.grantNeeded + " The grant is two exact pmset disablesleep commands. See SECURITY.md."
        intro.addButton(withTitle: "Enable")
        intro.addButton(withTitle: "Not now")
        NSApp.activate(ignoringOtherApps: true)
        guard intro.runModal() == .alertFirstButtonReturn else { return false }

        let result = ProcessRunner.run("/usr/bin/osascript", ["-e", osa], timeout: 120)
        return result.exit == 0
    }
}
