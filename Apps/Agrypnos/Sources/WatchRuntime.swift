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
    private var lastLidClosed = false
    weak var delegate: WatchRuntimeDelegate?

    var preferences: UserPreferences { engine.preferences }
    var engaged: Bool { engine.engaged }
    var kernelAwake: Bool { SleepDisabledController.read() }

    init() {
        engine = WatchEngine(preferences: store.load())
    }

    func start() {
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
            var result = SleepDisabledController.set(true)
            if result == .grantMissing {
                if GrantInstaller.installViaNativeAuth() {
                    result = SleepDisabledController.set(true)
                }
            }
            guard result == .ok else {
                if case .failed(let message) = result {
                    UserNotify.post("Couldn't keep the watch. \(message)")
                } else {
                    UserNotify.post(AgrypnosCopy.grantNeeded)
                }
                return
            }
            let commands = engine.userSetEngaged(true, now: Date())
            apply(commands)
        } else {
            _ = SleepDisabledController.set(false)
            let commands = engine.userSetEngaged(false, now: Date())
            apply(commands)
            PowerHygieneCoordinator.restoreAfterDisengage(
                preferences: engine.preferences,
                savedBrightness: &savedBrightness
            )
        }
        delegate?.watchRuntimeDidChange(self)
    }

    func poll() {
        let kernel = SleepDisabledController.read()
        if engine.engaged, !kernel {
            _ = engine.userSetEngaged(false, now: Date())
            PowerHygieneCoordinator.restoreAfterDisengage(
                preferences: engine.preferences,
                savedBrightness: &savedBrightness
            )
        }

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
                _ = SleepDisabledController.set(false)
                PowerHygieneCoordinator.restoreAfterDisengage(
                    preferences: engine.preferences,
                    savedBrightness: &savedBrightness
                )
                if reason != .user {
                    UserNotify.post(reason: reason)
                }
            }
        }
        apply(commands)
        delegate?.watchRuntimeDidChange(self)
    }

    func apply(_ commands: [WatchCommand]) {
        PowerHygieneCoordinator.apply(commands, preferences: engine.preferences, savedBrightness: &savedBrightness)
    }
}
