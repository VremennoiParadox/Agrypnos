#if canImport(AgrypnosCore)
import AgrypnosCore
#endif

enum PowerHygieneCoordinator {
    static func apply(
        _ commands: [WatchCommand],
        preferences: UserPreferences,
        savedBrightness: inout Double?,
        savedKeyboard: inout Double?
    ) {
        for command in commands {
            switch command {
            case .engage, .disengage:
                break
            case .applyBrightnessFloor:
                if savedBrightness == nil {
                    savedBrightness = BrightnessFloorController.current()
                }
                savedBrightness = max(
                    savedBrightness ?? preferences.brightnessFloor,
                    preferences.brightnessFloor
                )
            case .requestDisplaySleep:
                DisplaySleepController.sleepNow()
            case .requestKeyboardBacklightOff:
                if savedKeyboard == nil {
                    savedKeyboard = KeyboardBacklightController.current()
                }
                KeyboardBacklightController.setOff()
            }
        }
    }

    static func restoreAfterDisengage(
        preferences: UserPreferences,
        savedBrightness: inout Double?,
        savedKeyboard: inout Double?
    ) {
        if preferences.applyBrightnessFloor {
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
