import AppKit
import Foundation

#if canImport(AgrypnosCore)
import AgrypnosCore
#endif

@MainActor
protocol WatchRuntimeDelegate: AnyObject {
    func watchRuntimeDidChange(_ runtime: WatchRuntime)
}

@MainActor
final class WatchRuntime {
    private let store = PreferencesStore()
    private(set) var engine: WatchEngine
    private var pollTimer: Timer?
    private var savedBrightness: Double?
    private var savedKeyboard: Double?
    private var lastLidClosed = false
    weak var delegate: WatchRuntimeDelegate?

    var preferences: UserPreferences { engine.preferences }
    var engaged: Bool { engine.engaged }
    var hotkeyRegistered = false

    init() {
        engine = WatchEngine(preferences: store.load())
    }

    func start() {
        reconcileKernel(preferClearLeftover: true)
        pollTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.poll() }
        }
        poll()
    }

    func setDuration(_ option: DurationOption) {
        let commands = engine.userSetDuration(option, now: Date())
        store.save(engine.preferences)
        apply(commands)
        delegate?.watchRuntimeDidChange(self)
    }

    func setBatteryFloor(_ percent: Int) {
        engine.preferences.batteryFloorPercent = min(max(percent, 5), 50)
        store.save(engine.preferences)
        delegate?.watchRuntimeDidChange(self)
    }

    func setHygiene(display: Bool? = nil, keyboard: Bool? = nil, floor: Bool? = nil) {
        if let display { engine.preferences.forceDisplaySleep = display }
        if let keyboard { engine.preferences.keyboardBacklightOff = keyboard }
        if let floor { engine.preferences.applyBrightnessFloor = floor }
        store.save(engine.preferences)
        delegate?.watchRuntimeDidChange(self)
    }

    func toggle() {
        setEngaged(!engine.engaged)
    }

    func setEngaged(_ on: Bool) {
        if on {
            guard armKernel() else { return }
            apply(engine.userSetEngaged(true, now: Date()))
        } else {
            guard disarmKernel() else {
                UserNotify.post("Couldn't drop SleepDisabled. The kernel flag is still on.")
                delegate?.watchRuntimeDidChange(self)
                return
            }
            apply(engine.userSetEngaged(false, now: Date()))
            restoreHygiene()
        }
        delegate?.watchRuntimeDidChange(self)
    }

    func poll() {
        reconcileKernel(preferClearLeftover: false)

        let lidClosed = LidStateReader.isClosed()
        if engine.engaged, lidClosed, !lastLidClosed {
            apply(engine.lidDidClose(now: Date()))
        }
        lastLidClosed = lidClosed

        let battery = BatteryMonitor.reading()
        let safety = SafetyInputs(
            batteryPercent: battery.percent,
            onBatteryDischarging: battery.onBatteryDischarging,
            thermalSerious: ThermalMonitor.isSerious(),
            lowPowerMode: ProcessInfo.processInfo.isLowPowerModeEnabled
        )
        let agents = AgentProbeService.snapshot(now: Date(), freshness: engine.preferences.sessionFreshness)
        let commands = engine.tick(now: Date(), safety: safety, agents: agents)
        for command in commands {
            if case .disengage(let reason) = command {
                if !disarmKernel() {
                    _ = engine.userSetEngaged(true, now: Date())
                    UserNotify.post("Couldn't drop SleepDisabled. The watch stays up.")
                    break
                }
                restoreHygiene()
                if reason != .user {
                    UserNotify.post(reason: reason)
                }
            }
        }
        apply(commands)
        delegate?.watchRuntimeDidChange(self)
    }

    func apply(_ commands: [WatchCommand]) {
        PowerHygieneCoordinator.apply(
            commands,
            preferences: engine.preferences,
            savedBrightness: &savedBrightness,
            savedKeyboard: &savedKeyboard
        )
    }

    func restoreHygiene() {
        PowerHygieneCoordinator.restoreAfterDisengage(
            preferences: engine.preferences,
            savedBrightness: &savedBrightness,
            savedKeyboard: &savedKeyboard
        )
    }

    @discardableResult
    func armKernel() -> Bool {
        var result = SleepDisabledController.set(true)
        if result == .grantMissing {
            if GrantInstaller.installViaNativeAuth() {
                result = SleepDisabledController.set(true)
            }
        }
        guard result == .ok, SleepDisabledController.read() else {
            if case .failed(let message) = result {
                UserNotify.post("Couldn't keep the watch. \(message)")
            } else if result == .grantMissing {
                UserNotify.post(AgrypnosCopy.grantNeeded)
            } else {
                UserNotify.post("pmset ran but SleepDisabled did not read back as on.")
            }
            return false
        }
        return true
    }

    @discardableResult
    func disarmKernel() -> Bool {
        _ = SleepDisabledController.set(false)
        return !SleepDisabledController.read()
    }

    func reconcileKernel(preferClearLeftover: Bool) {
        let kernel = SleepDisabledController.read()
        if kernel, !engine.engaged {
            if preferClearLeftover {
                _ = SleepDisabledController.set(false)
            }
            if SleepDisabledController.read() {
                _ = engine.userSetEngaged(true, now: Date())
            }
        } else if !kernel, engine.engaged {
            _ = engine.userSetEngaged(false, now: Date())
            restoreHygiene()
        }
    }
}
