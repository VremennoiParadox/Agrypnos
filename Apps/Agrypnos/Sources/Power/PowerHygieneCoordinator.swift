#if canImport(AgrypnosCore)
import AgrypnosCore
#endif

enum PowerHygieneCoordinator {
    static func apply(
        _ commands: [WatchCommand],
        preferences: UserPreferences,
        savedBrightness: inout Double?,
        savedKeyboard: inout Double?,
        ramp: BrightnessRampController
    ) {
        for command in commands {
            switch command {
            case .engage:
                if savedBrightness == nil {
                    savedBrightness = BrightnessFloorController.current()
                }
                if savedKeyboard == nil {
                    savedKeyboard = KeyboardBacklightController.current()
                }
            case .disengage:
                break
            case .applyBrightnessFloor:
                ramp.cancel()
                if savedBrightness == nil {
                    savedBrightness = BrightnessFloorController.current()
                }
                savedBrightness = max(
                    savedBrightness ?? preferences.brightnessFloor,
                    preferences.brightnessFloor
                )
                BrightnessFloorController.set(preferences.brightnessFloor)
            case .requestDisplaySleep:
                // Armed-watch V1: lid close floors brightness. Do not blank the panel.
                break
            case .requestKeyboardBacklightOff:
                if savedKeyboard == nil {
                    savedKeyboard = KeyboardBacklightController.current()
                }
                KeyboardBacklightController.setOff()
            case .rampBrightnessRestore:
                let target = HygieneRestore.displayBrightnessToRestore(
                    captured: savedBrightness,
                    floor: preferences.brightnessFloor
                )
                let from = preferences.brightnessFloor
                BrightnessFloorController.set(from)
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
