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
    /// Hold SleepDisabled until the idle-after-wait POST attempt finishes, then disarm.
    private var idleOutbound = NotifIdleOutboundCoordinator()
    private var idlePostTask: Task<Void, Never>?

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

    func setBrightnessFloorPercent(_ percent: Int) {
        engine.preferences.brightnessFloorPercent = UserPreferences.clampBrightnessFloor(percent)
        store.save(engine.preferences)
        delegate?.watchRuntimeDidChange(self)
    }

    func setAgentSettleGrace(_ seconds: TimeInterval) {
        engine.userSetAgentSettleGrace(seconds)
        store.save(engine.preferences)
        delegate?.watchRuntimeDidChange(self)
    }

    func setLidOpenRampSeconds(_ seconds: Int) {
        engine.preferences.lidOpenRampSeconds = UserPreferences.clampLidOpenRamp(seconds)
        store.save(engine.preferences)
        delegate?.watchRuntimeDidChange(self)
    }

    func setThermalAutoOff(_ on: Bool) {
        engine.preferences.thermalAutoOff = on
        store.save(engine.preferences)
        delegate?.watchRuntimeDidChange(self)
    }

    func setNotifEnabled(_ on: Bool) {
        engine.preferences.notifEnabled = on
        store.save(engine.preferences)
        delegate?.watchRuntimeDidChange(self)
    }

    func notifSecrets() -> NotifSecrets {
        NotifSecretsStore.load()
    }

    @discardableResult
    func setNotifDiscordWebhookURL(_ value: String?) -> Bool {
        switch NotifDiscordFieldChrome.commit(value ?? "") {
        case .persist(let url):
            return NotifSecretsStore.setDiscordWebhookURL(url)
        case .clear:
            return NotifSecretsStore.setDiscordWebhookURL(nil)
        case .reject:
            return false
        }
    }

    @discardableResult
    func setNotifTelegramBotToken(_ value: String?) -> Bool {
        switch TelegramBotTokenChrome.commit(value ?? "") {
        case .persist(let token):
            return NotifSecretsStore.setTelegramBotToken(token)
        case .clear:
            return NotifSecretsStore.setTelegramBotToken(nil)
        case .reject:
            return false
        }
    }

    @discardableResult
    func setNotifTelegramChatId(_ value: String?) -> Bool {
        switch TelegramChatIdChrome.commit(value ?? "") {
        case .persist(let id):
            return NotifSecretsStore.setTelegramChatId(id)
        case .clear:
            return NotifSecretsStore.setTelegramChatId(nil)
        case .reject:
            return false
        }
    }

    func clearNotifSecrets() {
        NotifSecretsStore.clear()
    }

    func setHotkey(_ chord: HotkeyChord) {
        lastFailedHotkey = nil
        hotkeySuspendedForRecord = false
        let previous = engine.preferences.hotkey
        let registered = chord.isBindable ? (bindHotkey?(chord) ?? false) : false
        let plan = HotkeyRemapPlan.make(
            attempted: chord,
            previous: previous,
            osRegistered: registered
        )
        if plan.persist {
            _ = engine.preferences.applyHotkeyRemap(plan.chordToRegister)
            store.save(engine.preferences)
            hotkeyRegistered = true
        } else {
            lastFailedHotkey = plan.failedAttempt
            hotkeyRegistered = bindHotkey?(plan.chordToRegister) ?? false
            if let hint = plan.hint {
                UserNotify.post(hint)
            }
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
            idlePostTask?.cancel()
            idlePostTask = nil
            idleOutbound.noteUserArm()
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
        if idleOutbound.shouldSkipPoll(engineEngaged: engine.engaged) { return }
        reconcileKernel(preferClearLeftover: false)
        pollLid()

        let battery = BatteryMonitor.reading()
        let safety = SafetyInputs(
            batteryPercent: battery.percent,
            onBatteryDischarging: battery.onBatteryDischarging,
            thermalSerious: ThermalMonitor.isSerious(),
            lowPowerMode: ProcessInfo.processInfo.isLowPowerModeEnabled
        )
        let kernel = SleepDisabledController.read()
        let agents = AgentProbeService.snapshot(now: Date(), freshness: engine.preferences.sessionFreshness)
        let commands = engine.tick(
            now: Date(),
            safety: safety,
            agents: agents,
            kernelSleepDisabled: kernel
        )
        if commands.contains(where: Self.isPostIdleAfterWait) {
            let token = idleOutbound.beginPost()
            let enabled = engine.preferences.notifEnabled
            idlePostTask?.cancel()
            idlePostTask = Task { @MainActor in
                await NotifIdlePoster.postIfNeeded(enabled: enabled)
                guard self.idleOutbound.completePost(token: token) else { return }
                self.idlePostTask = nil
                self.finishTickCommands(commands)
                self.delegate?.watchRuntimeDidChange(self)
            }
            delegate?.watchRuntimeDidChange(self)
            return
        }
        finishTickCommands(commands)
        delegate?.watchRuntimeDidChange(self)
    }

    func finishTickCommands(_ commands: [WatchCommand]) {
        var applyCommands = commands.filter { !Self.isPostIdleAfterWait($0) }
        for command in commands {
            if case .disengage(let reason) = command {
                if !disarmKernel() {
                    _ = engine.rollbackDisarmFailure(
                        now: Date(),
                        lidClosed: LidStateReader.isClosed()
                    )
                    UserNotify.post("Couldn't drop SleepDisabled. The watch stays up.")
                    applyCommands = []
                    break
                }
                restoreHygiene()
                if reason != .user {
                    UserNotify.post(reason: reason)
                }
            }
        }
        apply(applyCommands)
    }

    static func isPostIdleAfterWait(_ command: WatchCommand) -> Bool {
        if case .postIdleAfterWaitNotif = command { return true }
        return false
    }

    func apply(_ commands: [WatchCommand]) {
        for command in commands {
            if case .assertSleepDisabled = command {
                _ = armKernel()
            }
        }
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

    /// Quit must clear actual kernel-held SleepDisabled even if the engine already disengaged for POST.
    func prepareForTermination() {
        let kernelHeld = SleepDisabledController.read()
        let plan = idleOutbound.terminatePlan(
            engineEngaged: engine.engaged,
            kernelSleepDisabled: kernelHeld
        )
        idlePostTask?.cancel()
        idlePostTask = nil
        idleOutbound.cancelInFlight()
        guard plan.cleanupRequired else { return }
        if plan.clearKernel {
            _ = disarmKernel()
        }
        if engine.engaged {
            apply(engine.userSetEngaged(false, now: Date(), lidClosed: LidStateReader.isClosed()))
        }
        restoreHygiene()
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
        }
    }
}
