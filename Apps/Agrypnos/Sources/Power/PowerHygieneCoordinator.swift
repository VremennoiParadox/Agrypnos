#if canImport(AgrypnosCore)
import AgrypnosCore
#endif

enum PowerHygieneCoordinator {
    static var canSetBuiltInBrightness: Bool { BrightnessFloorController.canSetBuiltIn() }

    @discardableResult
    static func apply(
        _ commands: [WatchCommand],
        preferences: UserPreferences,
        savedBrightness: inout Double?,
        savedKeyboard: inout Double?,
        ramp: BrightnessRampController
    ) -> HygieneApplyResult {
        var result = HygieneApplyResult()
        for command in commands {
            switch command {
            case .engage, .disengage, .assertSleepDisabled, .postIdleAfterWaitNotif:
                break
            case .requestSleep:
                let exit = ProcessRunner.run("/usr/bin/pmset", ["sleepnow"]).exit
                result.sleepnow = PmsetCommandOutcome.from(exit: exit)
            case .requestDisplaySleep:
                // Panel only. Never `sleepnow`. Never with a floor write.
                guard preferences.panelPowerMode.sleepsDisplay else { break }
                let exit = ProcessRunner.run("/usr/bin/pmset", ["displaysleepnow"]).exit
                result.displaysleepnow = PmsetCommandOutcome.from(exit: exit)
            case .wakeDisplay:
                // Fire-and-forget user-activity pulse. Do not wait — `caffeinate -u -t 1`
                // would stall the menu extra and fight a following `sleepnow`.
                ProcessRunner.runDetached("/usr/bin/caffeinate", ["-u", "-t", "1"])
            case .applyBrightnessFloor:
                guard preferences.panelPowerMode.writesBrightnessFloor else { break }
                ramp.cancel()
                if canSetBuiltInBrightness {
                    BrightnessFloorController.set(preferences.brightnessFloor)
                }
            case .requestKeyboardBacklightOff:
                KeyboardBacklightController.setOff()
            case .rampBrightnessRestore:
                guard preferences.panelPowerMode.showsLidOpenRamp else { break }
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
        return result
    }

    static func restoreAfterDisengage(
        preferences: UserPreferences,
        savedBrightness: inout Double?,
        savedKeyboard: inout Double?,
        ramp: BrightnessRampController
    ) {
        ramp.cancel()
        if preferences.panelPowerMode.writesBrightnessFloor,
           preferences.applyBrightnessFloor, canSetBuiltInBrightness,
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
