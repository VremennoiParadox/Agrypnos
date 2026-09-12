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

    static func setBrightness(_ value: Double) {
        for name in ["AppleHIDKeyboardEventDriverV2", "AppleHIDKeyboardEventDriver", "AppleKeyboard"] {
            let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceNameMatching(name))
            guard service != 0 else { continue }
            apply(value, to: service)
            IOObjectRelease(service)
        }
    }

    static func apply(_ value: Double, to service: io_object_t) {
        let number = NSNumber(value: value)
        for key in keys {
            IORegistryEntrySetCFProperty(service, key as CFString, number)
        }
    }
}
