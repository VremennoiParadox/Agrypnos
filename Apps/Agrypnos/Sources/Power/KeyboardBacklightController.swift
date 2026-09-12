import Foundation
import IOKit

enum KeyboardBacklightController {
    private static let keys = [
        "KeyboardBacklightBrightness",
        "KeyboardBacklightUserBrightness",
        "KeyboardBacklight",
    ]

    static func setOff() {
        setBrightness(0)
    }

    static func current() -> Double? {
        for name in serviceNames {
            let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceNameMatching(name))
            guard service != 0 else { continue }
            defer { IOObjectRelease(service) }
            if let value = read(from: service) { return value }
        }
        return nil
    }

    static func setBrightness(_ value: Double) {
        for name in serviceNames {
            let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceNameMatching(name))
            guard service != 0 else { continue }
            write(value, to: service)
            IOObjectRelease(service)
        }
    }

    private static let serviceNames = [
        "AppleHIDKeyboardEventDriverV2",
        "AppleHIDKeyboardEventDriver",
        "AppleKeyboard",
    ]

    static func read(from service: io_object_t) -> Double? {
        for key in keys {
            guard let unmanaged = IORegistryEntryCreateCFProperty(
                service,
                key as CFString,
                kCFAllocatorDefault,
                0
            ) else { continue }
            let value = unmanaged.takeRetainedValue()
            if let number = value as? NSNumber { return number.doubleValue }
        }
        return nil
    }

    static func write(_ value: Double, to service: io_object_t) {
        let number = NSNumber(value: value)
        for key in keys {
            IORegistryEntrySetCFProperty(service, key as CFString, number)
        }
    }
}
