#if canImport(AgrypnosCore)
import AgrypnosCore
#endif

enum PowerHygieneCoordinator {
    static func apply(_ commands: [WatchCommand], preferences: UserPreferences, savedBrightness: inout Double?) {
        for command in commands {
            switch command {
            case .engage, .disengage:
                break
            case .requestDisplaySleep:
                DisplaySleepController.sleepNow()
            case .requestKeyboardBacklightOff:
                KeyboardBacklightController.setOff()
            case .applyBrightnessFloor:
                if savedBrightness == nil {
                    savedBrightness = BrightnessFloorController.current()
                }
                BrightnessFloorController.applyFloor(preferences.brightnessFloor)
            }
        }
    }

    static func restoreAfterDisengage(preferences: UserPreferences, savedBrightness: inout Double?) {
        if preferences.applyBrightnessFloor {
            BrightnessFloorController.restoreAtLeastFloor(
                saved: savedBrightness,
                floor: preferences.brightnessFloor
            )
        }
        savedBrightness = nil
    }
}
