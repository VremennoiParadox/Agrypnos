import CoreGraphics
import Foundation
import IOKit

#if canImport(AgrypnosCore)
import AgrypnosCore
#endif

enum LidStateReader {
    /// One AppleClamshellState read. Floor/hygiene goes through LidCloseConfirm —
    /// a single raw value is not lid close.
    static func isClosed() -> Bool { closedState() == true }

    /// Preserve an unavailable sensor for the timer-only sleep fallback.
    static func closedState() -> Bool? {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("IOPMrootDomain"))
        guard service != 0 else { return nil }
        defer { IOObjectRelease(service) }
        guard let unmanaged = IORegistryEntryCreateCFProperty(
            service,
            "AppleClamshellState" as CFString,
            kCFAllocatorDefault,
            0
        ) else { return nil }
        let value = unmanaged.takeRetainedValue()
        if let flag = value as? Bool { return flag }
        if let number = value as? NSNumber { return number.boolValue }
        return nil
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

/// Someone may be using the Mac. Automatic sleep and Sleep panel check this before acting.
struct UserPresence {
    var secondsSinceInput: () -> TimeInterval? = {
        CGEventSource.secondsSinceLastEventType(.hidSystemState, eventType: CGEventType(rawValue: ~0)!)
    }
    var externalDisplayOnline: () -> Bool = {
        var count: UInt32 = 0
        guard CGGetOnlineDisplayList(0, nil, &count) == .success, count > 0 else { return false }
        var ids = [CGDirectDisplayID](repeating: 0, count: Int(count))
        guard CGGetOnlineDisplayList(count, &ids, &count) == .success else { return false }
        return ids.prefix(Int(count)).contains { CGDisplayIsBuiltin($0) == 0 }
    }
}
