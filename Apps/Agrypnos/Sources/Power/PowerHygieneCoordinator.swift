import AppKit

#if canImport(AgrypnosCore)
import AgrypnosCore
#endif

enum PowerHygieneCoordinator {
    /// Extra screens: do not drive `CGMainDisplayID()` — that is often the external in clamshell.
    static var canSetBuiltInBrightness: Bool { NSScreen.screens.count <= 1 }

    static func apply(
        _ commands: [WatchCommand],
        preferences: UserPreferences,
        savedBrightness: inout Double?,
        savedKeyboard: inout Double?,
        ramp: BrightnessRampController
    ) {
        for command in commands {
            switch command {
            case .engage, .disengage:
                break
            case .applyBrightnessFloor:
                ramp.cancel()
                if let saved = savedBrightness {
                    savedBrightness = max(saved, preferences.brightnessFloor)
                }
                if canSetBuiltInBrightness {
                    BrightnessFloorController.set(preferences.brightnessFloor)
                }
            case .requestDisplaySleep:
                break
            case .requestKeyboardBacklightOff:
                KeyboardBacklightController.setOff()
            case .rampBrightnessRestore:
                guard canSetBuiltInBrightness else { break }
                let target = HygieneRestore.displayBrightnessToRestore(
                    captured: savedBrightness,
                    floor: preferences.brightnessFloor
                )
                let from = BrightnessFloorController.current() ?? preferences.brightnessFloor
                ramp.start(from: from, to: target, duration: HygieneRestore.lidOpenRampDuration)
            case .restoreKeyboardBacklight:
                if let brightness = HygieneRestore.keyboardBrightnessToRestore(captured: savedKeyboard) {
                    KeyboardBacklightController.setBrightness(brightness)
                }
            }
        }
    }

    static func restoreAfterDisengage(
        preferences: UserPreferences,
        savedBrightness: inout Double?,
        savedKeyboard: inout Double?,
        ramp: BrightnessRampController
    ) {
        ramp.cancel()
        if preferences.applyBrightnessFloor, canSetBuiltInBrightness {
            BrightnessFloorController.restoreAtLeastFloor(
                saved: savedBrightness,
                floor: preferences.brightnessFloor
            )
        }
        if preferences.keyboardBacklightOff,
           let brightness = HygieneRestore.keyboardBrightnessToRestore(captured: savedKeyboard) {
            KeyboardBacklightController.setBrightness(brightness)
        }
        savedBrightness = nil
        savedKeyboard = nil
    }
}
