import AppKit

#if canImport(AgrypnosCore)
import AgrypnosCore
#endif

enum UserNotify {
    static func post(_ message: String) {
        let escaped = message
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        _ = ProcessRunner.run("/usr/bin/osascript", [
            "-e",
            "display notification \"\(escaped)\" with title \"Agrypnos\" sound name \"Tink\"",
        ])
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
        intro.messageText = "Let Agrypnos keep the watch"
        intro.informativeText = AgrypnosCopy.grantNeeded + " The grant is two exact pmset disablesleep commands. See SECURITY.md."
        intro.addButton(withTitle: "Enable")
        intro.addButton(withTitle: "Not now")
        NSApp.activate(ignoringOtherApps: true)
        guard intro.runModal() == .alertFirstButtonReturn else { return false }

        let result = ProcessRunner.run("/usr/bin/osascript", ["-e", osa])
        return result.exit == 0
    }
}
