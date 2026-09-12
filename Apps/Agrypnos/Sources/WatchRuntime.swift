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
    private let brightnessRamp = BrightnessRampController()
    private var lidTimer: Timer?
    weak var delegate: WatchRuntimeDelegate?

    var preferences: UserPreferences { engine.preferences }
    var engaged: Bool { engine.engaged }
    var hotkeyRegistered = false
    var adoptedLeftover: Bool { engine.leftoverAdopted }
    var bindHotkey: ((HotkeyChord) -> Bool)?
    var unbindHotkey: (() -> Void)?
    private(set) var lastFailedHotkey: HotkeyChord?
    private var hotkeySuspendedForRecord = false

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

    func setCustomMinutes(_ minutes: Int) {
        setDuration(.customMinutes(minutes))
    }

    func setBatteryFloor(_ percent: Int) {
        engine.preferences.batteryFloorPercent = UserPreferences.clampBatteryFloor(percent)
        store.save(engine.preferences)
        delegate?.watchRuntimeDidChange(self)
    }

    func setHotkey(_ chord: HotkeyChord) {
        lastFailedHotkey = nil
        hotkeySuspendedForRecord = false
        let previous = engine.preferences.hotkey
        guard chord.isBindable else {
            lastFailedHotkey = chord
            UserNotify.post(AgrypnosCopy.hotkeyHint(chord, registered: false))
            delegate?.watchRuntimeDidChange(self)
            return
        }
        let registered = bindHotkey?(chord) ?? false
        let resolved = HotkeyBindPolicy.resolve(attempted: chord, previous: previous, registered: registered)
        if resolved.shouldPersist {
            _ = engine.preferences.applyHotkeyRemap(resolved.chord)
            store.save(engine.preferences)
            hotkeyRegistered = true
        } else {
            lastFailedHotkey = chord
            hotkeyRegistered = bindHotkey?(previous) ?? false
            UserNotify.post(AgrypnosCopy.hotkeyHint(chord, registered: false))
        }
        delegate?.watchRuntimeDidChange(self)
    }

    func prepareHotkeyRemap() {
        lastFailedHotkey = nil
        if !hotkeySuspendedForRecord {
            unbindHotkey?()
            hotkeySuspendedForRecord = true
        }
        delegate?.watchRuntimeDidChange(self)
    }

    func restoreSuspendedHotkey() {
        guard hotkeySuspendedForRecord else { return }
        hotkeySuspendedForRecord = false
        hotkeyRegistered = bindHotkey?(engine.preferences.hotkey) ?? false
        delegate?.watchRuntimeDidChange(self)
    }

    func setHygiene(keyboard: Bool? = nil, floor: Bool? = nil) {
        if let keyboard { engine.preferences.keyboardBacklightOff = keyboard }
        if let floor { engine.preferences.applyBrightnessFloor = floor }
        store.save(engine.preferences)
        delegate?.watchRuntimeDidChange(self)
    }

    func toggle() {
        setEngaged(!engine.engaged)
    }

    func setEngaged(_ on: Bool) {
        let lidClosed = LidStateReader.isClosed()
        lastLidClosed = lidClosed
        if on {
            guard armKernel() else { return }
            apply(engine.userSetEngaged(true, now: Date(), lidClosed: lidClosed))
            if !lidClosed {
                recaptureOpenLidHygiene()
            }
            startLidPulse()
        } else {
            guard disarmKernel() else {
                UserNotify.post("Couldn't drop SleepDisabled. The kernel flag is still on.")
                delegate?.watchRuntimeDidChange(self)
                return
            }
            stopLidPulse()
            apply(engine.userSetEngaged(false, now: Date(), lidClosed: lidClosed))
            restoreHygiene()
        }
        delegate?.watchRuntimeDidChange(self)
    }

    func poll() {
        reconcileKernel(preferClearLeftover: false)
        pollLid()

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
                    _ = engine.userSetEngaged(true, now: Date(), lidClosed: LidStateReader.isClosed())
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
            savedKeyboard: &savedKeyboard,
            ramp: brightnessRamp
        )
    }

    func restoreHygiene() {
        stopLidPulse()
        PowerHygieneCoordinator.restoreAfterDisengage(
            preferences: engine.preferences,
            savedBrightness: &savedBrightness,
            savedKeyboard: &savedKeyboard,
            ramp: brightnessRamp
        )
    }

    func pollLid() {
        let lidClosed = LidStateReader.isClosed()
        var lidChanged = false
        if engine.engaged {
            if lidClosed, !lastLidClosed {
                apply(engine.lidDidClose(now: Date()))
                lidChanged = true
            } else if !lidClosed, lastLidClosed {
                apply(engine.lidDidOpen(now: Date()))
                lidChanged = true
            } else if !lidClosed, !engine.lidHygieneApplied, !brightnessRamp.isRunning {
                recaptureOpenLidHygiene()
            }
            startLidPulse()
        } else {
            stopLidPulse()
        }
        lastLidClosed = lidClosed
        if lidChanged {
            delegate?.watchRuntimeDidChange(self)
        }
    }

    func recaptureOpenLidHygiene() {
        if let current = BrightnessFloorController.current() {
            savedBrightness = current
        }
        if let current = KeyboardBacklightController.current() {
            savedKeyboard = current
        }
    }

    func startLidPulse() {
        guard engine.engaged, lidTimer == nil else { return }
        lidTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.pollLid() }
        }
    }

    func stopLidPulse() {
        lidTimer?.invalidate()
        lidTimer = nil
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
                let lidClosed = LidStateReader.isClosed()
                lastLidClosed = lidClosed
                apply(engine.adoptLeftoverKernel(now: Date(), lidClosed: lidClosed))
                if !lidClosed {
                    recaptureOpenLidHygiene()
                }
                startLidPulse()
                UserNotify.post(AgrypnosCopy.leftoverNotify)
            }
        } else if !kernel, engine.engaged {
            _ = engine.userSetEngaged(false, now: Date(), lidClosed: LidStateReader.isClosed())
            restoreHygiene()
        }
    }
}
