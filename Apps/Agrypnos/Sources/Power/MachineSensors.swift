import Foundation
import IOKit

#if canImport(AgrypnosCore)
import AgrypnosCore
#endif

enum LidStateReader {
    static func isClosed() -> Bool {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("IOPMrootDomain"))
        guard service != 0 else { return false }
        defer { IOObjectRelease(service) }
        guard let unmanaged = IORegistryEntryCreateCFProperty(
            service,
            "AppleClamshellState" as CFString,
            kCFAllocatorDefault,
            0
        ) else { return false }
        let value = unmanaged.takeRetainedValue()
        if let flag = value as? Bool { return flag }
        if let number = value as? NSNumber { return number.boolValue }
        return false
    }
}

enum BatteryMonitor {
    static func reading() -> BatteryReading {
        BatteryStatusParser.parse(pmsetBatt: ProcessRunner.run("/usr/bin/pmset", ["-g", "batt"]).out)
    }
}

enum ThermalMonitor {
    static func isSerious() -> Bool {
        let state = ProcessInfo.processInfo.thermalState
        return state == .serious || state == .critical
    }
}
