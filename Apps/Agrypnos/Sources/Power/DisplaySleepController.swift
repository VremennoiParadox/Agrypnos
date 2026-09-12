import Foundation
import IOKit

enum DisplaySleepController {
    /// Real display sleep. Dim-to-zero is not this.
    static func sleepNow() {
        _ = ProcessRunner.run("/usr/bin/pmset", ["displaysleepnow"])
        requestIdleViaWrangler()
    }

    static func requestIdleViaWrangler() {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceNameMatching("IODisplayWrangler"))
        guard service != 0 else { return }
        IORegistryEntrySetCFProperty(service, "IORequestIdle" as CFString, kCFBooleanTrue)
        IOObjectRelease(service)
    }
}
