import Foundation

#if canImport(AgrypnosCore)
import AgrypnosCore
#endif

extension WatchRuntime {
    func setAutoArmWhenBusy(_ on: Bool) {
        engine.userSetAutoArmWhenBusy(on)
        store.save(engine.preferences)
        delegate?.watchRuntimeDidChange(self)
    }

    /// One busy check while Keep awake is off. Same arm path as the popover switch,
    /// minus the grant installer: Auto-on never pops an admin prompt by itself.
    func autoArmIfDue(busy: Bool?, now: Date) {
        let safety = lastSafety ?? SafetyInputs(
            batteryPercent: lastBatteryReading?.percent,
            onBatteryDischarging: lastBatteryReading?.onBatteryDischarging ?? false,
            thermalSerious: ThermalMonitor.isSerious(),
            lowPowerMode: ProcessInfo.processInfo.isLowPowerModeEnabled
        )
        guard engine.autoArmDue(now: now, busy: busy, lidClosed: readLid(), safety: safety) else { return }
        WatchDiagnostics.event("auto-on arm")
        setEngaged(true, auto: true)
        if !engine.engaged {
            engine.autoArmDidFail()
        }
    }
}
