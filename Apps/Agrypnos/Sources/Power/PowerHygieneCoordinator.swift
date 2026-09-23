#if canImport(AgrypnosCore)
import AgrypnosCore
#endif

enum PowerHygieneCoordinator {
    static var canSetBuiltInBrightness: Bool { BrightnessFloorController.canSetBuiltIn() }

    static func apply(
        _ commands: [WatchCommand],
        preferences: UserPreferences,
        savedBrightness: inout Double?,
        savedKeyboard: inout Double?,
        ramp: BrightnessRampController
    ) {
        for command in commands {
            switch command {
            case .engage, .disengage, .assertSleepDisabled, .postIdleAfterWaitNotif:
                break
            case .requestSleep:
                _ = ProcessRunner.run("/usr/bin/pmset", ["sleepnow"])
            case .applyBrightnessFloor:
                ramp.cancel()
                if let saved = savedBrightness {
                    savedBrightness = max(saved, preferences.brightnessFloor)
                }
                if canSetBuiltInBrightness {
                    BrightnessFloorController.set(preferences.brightnessFloor)
                }
            case .requestKeyboardBacklightOff:
                KeyboardBacklightController.setOff()
            case .rampBrightnessRestore:
                guard canSetBuiltInBrightness else { break }
                guard let target = HygieneRestore.displayBrightnessToRestore(
                    captured: savedBrightness,
                    floor: preferences.brightnessFloor
                ) else { break }
                let from = BrightnessFloorController.current() ?? target
                ramp.start(
                    from: from,
                    to: target,
                    duration: HygieneRestore.lidOpenRampDuration(seconds: preferences.lidOpenRampSeconds)
                )
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
        if preferences.applyBrightnessFloor, canSetBuiltInBrightness,
           let target = HygieneRestore.displayBrightnessToRestore(
               captured: savedBrightness,
               floor: preferences.brightnessFloor
           ) {
            BrightnessFloorController.set(target)
        }
        if preferences.keyboardBacklightOff,
           let brightness = HygieneRestore.keyboardBrightnessToRestore(captured: savedKeyboard) {
            KeyboardBacklightController.setBrightness(brightness)
        }
        savedBrightness = nil
        savedKeyboard = nil
    }
}
