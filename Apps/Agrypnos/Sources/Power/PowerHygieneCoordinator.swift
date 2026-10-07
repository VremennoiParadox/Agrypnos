#if canImport(AgrypnosCore)
import AgrypnosCore
#endif

struct HygieneDevices {
    var canSetBrightness: () -> Bool = BrightnessFloorController.canSetBuiltIn
    var brightness: () -> Double? = BrightnessFloorController.current
    var setBrightness: (Double) -> Void = BrightnessFloorController.set
    var keyboard: () -> Double? = KeyboardBacklightController.current
    var setKeyboard: (Double) -> Void = KeyboardBacklightController.setBrightness
    var wakeDisplay: () -> Void = { ProcessRunner.runDetached("/usr/bin/caffeinate", ["-u", "-t", "1"]) }
}

struct HygieneEffects {
    var floor = false
    var keyboard = false
}

enum PowerHygieneCoordinator {
    static var canSetBuiltInBrightness: Bool { BrightnessFloorController.canSetBuiltIn() }

    @discardableResult
    static func apply(
        _ commands: [WatchCommand],
        preferences: UserPreferences,
        armed: Bool,
        lidCloseConfirmed: Bool,
        timerExpired: Bool = false,
        effects: inout HygieneEffects,
        savedBrightness: inout Double?,
        savedKeyboard: inout Double?,
        ramp: BrightnessRampController,
        devices: HygieneDevices = HygieneDevices(),
        readLid: () -> Bool?,
        runCommand: (String, [String]) -> (exit: Int32, out: String, err: String) = { ProcessRunner.run($0, $1) }
    ) -> HygieneApplyResult {
        var result = HygieneApplyResult()
        for command in commands {
            switch command {
            case .engage, .disengage, .assertSleepDisabled, .postIdleAfterWaitNotif, .postTimerExpiredNotif:
                break
            case .requestSleep:
                guard timerExpired ? readLid() != false : readLid() == true else { break }
                let exit = runCommand("/usr/bin/pmset", ["sleepnow"]).exit
                result.sleepnow = PmsetCommandOutcome.from(exit: exit)
            case .requestDisplaySleep:
                // Panel only. Never `sleepnow`. Never with a floor write.
                guard PanelPowerMode.shouldSleepDisplay(armed: armed, lidCloseConfirmed: lidCloseConfirmed,
                                                         mode: preferences.panelPowerMode), readLid() == true else { break }
                let exit = runCommand("/usr/bin/pmset", ["displaysleepnow"]).exit
                result.displaysleepnow = PmsetCommandOutcome.from(exit: exit)
            case .wakeDisplay:
                // Fire-and-forget user-activity pulse. Do not wait — `caffeinate -u -t 1`
                // would stall the menu extra and fight a following `sleepnow`.
                devices.wakeDisplay()
            case .applyBrightnessFloor:
                guard preferences.applyBrightnessFloor,
                      PanelPowerMode.shouldWriteFloor(armed: armed, lidCloseConfirmed: lidCloseConfirmed,
                                                       mode: preferences.panelPowerMode), readLid() == true else { break }
                ramp.cancel()
                if devices.canSetBrightness() {
                    devices.setBrightness(preferences.brightnessFloor)
                    effects.floor = true
                }
            case .requestKeyboardBacklightOff:
                guard armed, lidCloseConfirmed, preferences.keyboardBacklightOff, readLid() == true else { break }
                devices.setKeyboard(0)
                effects.keyboard = true
            case .rampBrightnessRestore:
                guard effects.floor, preferences.panelPowerMode.showsLidOpenRamp else { break }
                guard devices.canSetBrightness() else { break }
                guard let target = HygieneRestore.displayBrightnessToRestore(
                    captured: savedBrightness,
                    floor: preferences.brightnessFloor
                ) else { break }
                let from = devices.brightness() ?? target
                ramp.start(
                    from: from,
                    to: target,
                    duration: HygieneRestore.lidOpenRampDuration(seconds: preferences.lidOpenRampSeconds),
                    setBrightness: devices.setBrightness
                )
            case .restoreKeyboardBacklight:
                restoreKeyboard(effects: &effects, captured: savedKeyboard, devices: devices)
            }
        }
        return result
    }

    static func restoreBrightness(
        effects: inout HygieneEffects, captured: Double?,
        ramp: BrightnessRampController, devices: HygieneDevices
    ) {
        ramp.cancel()
        if effects.floor, devices.canSetBrightness(), let captured {
            devices.setBrightness(captured)
        }
        effects.floor = false
    }

    static func restoreKeyboard(effects: inout HygieneEffects, captured: Double?, devices: HygieneDevices) {
        if effects.keyboard, let captured { devices.setKeyboard(captured) }
        effects.keyboard = false
    }

    static func restoreAfterDisengage(
        effects: inout HygieneEffects,
        savedBrightness: inout Double?,
        savedKeyboard: inout Double?,
        ramp: BrightnessRampController,
        devices: HygieneDevices = HygieneDevices()
    ) {
        restoreBrightness(effects: &effects, captured: savedBrightness, ramp: ramp, devices: devices)
        restoreKeyboard(effects: &effects, captured: savedKeyboard, devices: devices)
        savedBrightness = nil
        savedKeyboard = nil
    }
}
