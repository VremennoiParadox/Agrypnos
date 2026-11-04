import Foundation

#if canImport(AgrypnosCore)
import AgrypnosCore
#endif

extension WatchRuntime {
    /// A closed-lid `sleepnow` must not light the panel first. Keep the capture and restore it on wake.
    func deferHygieneRestoreToWake() {
        stopLidPulse()
        brightnessRamp.cancel()
        wakeRestorePending = true
    }

    /// Wake with the lid open: put the captured brightness back. A dark wake or a lid that is
    /// still closed keeps it pending for the next wake.
    func restoreHygieneAfterWake() {
        guard wakeRestorePending, readLid() != true else { return }
        wakeRestorePending = false
        PowerHygieneCoordinator.restoreAfterWake(
            effects: &hygieneEffects,
            savedBrightness: &savedBrightness,
            savedKeyboard: &savedKeyboard,
            preferences: engine.preferences,
            ramp: brightnessRamp,
            devices: hygieneDevices
        )
    }
}
