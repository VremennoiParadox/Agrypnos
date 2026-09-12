import AppKit
import Foundation
import IOKit

enum DisplaySleepController {
    /// Real display sleep. Dim-to-zero is not this. Skip when an external screen is the console.
    static func sleepNow() {
        if NSScreen.screens.count > 1 { return }
        _ = ProcessRunner.run("/usr/bin/pmset", ["displaysleepnow"])
        requestIdleViaWrangler()
    }

    static func requestIdleViaWrangler() {
        if NSScreen.screens.count > 1 { return }
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceNameMatching("IODisplayWrangler"))
        guard service != 0 else { return }
        IORegistryEntrySetCFProperty(service, "IORequestIdle" as CFString, kCFBooleanTrue)
        IOObjectRelease(service)
    }
}
