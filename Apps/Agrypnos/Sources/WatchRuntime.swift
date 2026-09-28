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
    let store: PreferencesStore
    let readLid: () -> Bool
    let readKernel: () -> Bool
    let setKernel: (Bool) -> ToggleResult
    let runCommand: (String, [String]) -> (exit: Int32, out: String, err: String)
    let postIdle: (Bool) async -> Void
    let notify: (String) -> Void
    var engine: WatchEngine
    var pollTimer: Timer?
    var savedBrightness: Double?
    var savedKeyboard: Double?
    let brightnessRamp = BrightnessRampController()
    var lidTimer: Timer?
    weak var delegate: WatchRuntimeDelegate?

    var preferences: UserPreferences { engine.preferences }
    var engaged: Bool { engine.engaged || engine.holdingForIdlePost }
    var statusItemState: StatusItemState { engine.statusItemState }
    var statusItemTitle: String { AgrypnosCopy.statusItemTitle(engine.statusItemState) }
    var hotkeyRegistered = false
    var adoptedLeftover: Bool { engine.leftoverAdopted }
    var bindHotkey: ((HotkeyChord) -> Bool)?
    var unbindHotkey: (() -> Void)?
    private(set) var lastFailedHotkey: HotkeyChord?
    var hotkeySuspendedForRecord = false
    var idleOutbound = NotifIdleOutboundCoordinator()
    var idlePostTask: Task<Void, Never>?
    let inboundPoller = TelegramInboundPoller()
    let discordGateway = DiscordInboundGatewayClient()
    var discordApplicationId: String?
    var workspaceObservers: [NSObjectProtocol] = []
    var lastBatteryReading: BatteryReading?
    var lastSafety: SafetyInputs?
    var agentSnapshotCache = AgentSnapshotCache()
    var probeGeneration: UInt64 = 0
    var probeInFlight = false
    var idleProbeTicks: Int = 0
    var diagnostics = WatchDiagnostics()

    init(
        store: PreferencesStore = PreferencesStore(),
        readLid: @escaping () -> Bool = LidStateReader.isClosed,
        readKernel: @escaping () -> Bool = SleepDisabledController.read,
        setKernel: @escaping (Bool) -> ToggleResult = SleepDisabledController.set,
        runCommand: @escaping (String, [String]) -> (exit: Int32, out: String, err: String) = {
            ProcessRunner.run($0, $1)
        },
        postIdle: @escaping (Bool) async -> Void = { await NotifIdlePoster.postIfNeeded(enabled: $0) },
        notify: @escaping (String) -> Void = UserNotify.post
    ) {
        self.store = store
        self.readLid = readLid
        self.readKernel = readKernel
        self.setKernel = setKernel
        self.runCommand = runCommand
        self.postIdle = postIdle
        self.notify = notify
        engine = WatchEngine(preferences: store.load())
    }

    func start() {
        inboundPoller.runtime = self
        discordGateway.runtime = self
        observeMacSleepWake()
        SleepDisabledCrashGuard.start()
        reconcileKernel(preferClearLeftover: true)
        pollTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.poll() }
        }
        poll()
        inboundPoller.sync()
        discordGateway.sync()
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

    func setPanelPowerMode(_ mode: PanelPowerMode) {
        let commands = engine.userSetPanelPowerMode(mode)
        store.save(engine.preferences)
        apply(commands)
        delegate?.watchRuntimeDidChange(self)
    }

    func setCountTerminalSessionsAsBusy(_ on: Bool) {
        engine.userSetCountTerminalSessionsAsBusy(on)
        store.save(engine.preferences)
        invalidateAgentProbe()
        delegate?.watchRuntimeDidChange(self)
    }

    func setThermalAutoOff(_ on: Bool) {
        engine.preferences.thermalAutoOff = on
        store.save(engine.preferences)
        delegate?.watchRuntimeDidChange(self)
    }

    func setIncludedAgentKinds(_ kinds: Set<AgentKind>) {
        guard engine.preferences.applyIncludedAgentKinds(kinds) else { return }
        store.save(engine.preferences)
        invalidateAgentProbe()
        delegate?.watchRuntimeDidChange(self)
    }

    func setNotifEnabled(_ on: Bool) {
        engine.preferences.notifEnabled = on
        store.save(engine.preferences)
        delegate?.watchRuntimeDidChange(self)
    }

    func setTelegramInboundEnabled(_ on: Bool) {
        engine.userSetTelegramInboundEnabled(on)
        store.save(engine.preferences)
        inboundPoller.sync()
        pollLid()
        delegate?.watchRuntimeDidChange(self)
    }

    func setDiscordInboundEnabled(_ on: Bool) {
        engine.userSetDiscordInboundEnabled(on)
        store.save(engine.preferences)
        discordGateway.sync()
        pollLid()
        delegate?.watchRuntimeDidChange(self)
    }

    func notifSecrets() -> NotifSecrets {
        NotifSecretsStore.load()
    }

    @discardableResult
    func setNotifDiscordWebhookURL(_ value: String?) -> Bool {
        NotifSecretsStore.setDiscordWebhookURL(value)
    }

    @discardableResult
    func setNotifTelegramBotToken(_ value: String?) -> Bool {
        store.resetTelegramInboundCursor()
        inboundPoller.invalidate()
        let saved = NotifSecretsStore.setTelegramBotToken(value)
        inboundPoller.sync()
        return saved
    }

    @discardableResult
    func setNotifTelegramChatId(_ value: String?) -> Bool {
        let saved = NotifSecretsStore.setTelegramChatId(value)
        inboundPoller.sync()
        return saved
    }

    @discardableResult
    func setNotifDiscordBotToken(_ value: String?) -> Bool {
        store.resetDiscordInboundCursor()
        discordGateway.invalidate()
        let saved = NotifSecretsStore.setDiscordBotToken(value)
        discordGateway.sync()
        return saved
    }

    @discardableResult
    func setNotifDiscordChannelId(_ value: String?) -> Bool {
        let saved = NotifSecretsStore.setDiscordChannelId(value)
        discordGateway.sync()
        return saved
    }

    func clearNotifSecrets() {
        store.resetTelegramInboundCursor()
        store.resetDiscordInboundCursor()
        inboundPoller.invalidate()
        discordGateway.invalidate()
        NotifSecretsStore.clear()
        inboundPoller.sync()
        discordGateway.sync()
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
                notify(hint)
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
        setEngaged(!engaged)
    }

    @discardableResult
    func setEngaged(_ on: Bool) -> HygieneApplyResult {
        if on {
            guard armKernel() else { return HygieneApplyResult() }
            invalidateAgentProbe()
            idlePostTask?.cancel()
            idlePostTask = nil
            idleOutbound.noteUserArm()
            let rawClosed = readLid()
            if LidCloseConfirm.shouldCaptureBeforeClosedHygiene(rawClosed: rawClosed) {
                recaptureOpenLidHygiene()
            }
            apply(engine.userSetEngaged(true, now: Date(), lidClosed: false))
            apply(engine.observeLid(closed: rawClosed, now: Date()))
            if LidCloseConfirm.shouldRecaptureOpenBrightness(
                rawClosed: rawClosed,
                confirmedClosed: engine.lidClosed
            ) {
                recaptureOpenLidHygiene()
            }
            startLidPulse()
            delegate?.watchRuntimeDidChange(self)
            return HygieneApplyResult()
        }
        guard disarmKernel() else {
            notify("Couldn't drop SleepDisabled. The kernel flag is still on.")
            delegate?.watchRuntimeDidChange(self)
            return HygieneApplyResult()
        }
        idlePostTask?.cancel()
        idlePostTask = nil
        idleOutbound.cancelInFlight()
        let sleepResult = applyUserOff()
        store.save(engine.preferences)
        syncLidPulse()
        delegate?.watchRuntimeDidChange(self)
        return sleepResult
    }

    @discardableResult
    func apply(_ commands: [WatchCommand]) -> HygieneApplyResult {
        for command in commands {
            if case .assertSleepDisabled = command {
                _ = armKernel()
            }
        }
        let result = PowerHygieneCoordinator.apply(
            commands,
            preferences: engine.preferences,
            savedBrightness: &savedBrightness,
            savedKeyboard: &savedKeyboard,
            ramp: brightnessRamp,
            runCommand: runCommand
        )
        if let outcome = result.sleepnow {
            WatchDiagnostics.event("sleepnow outcome=\(outcome)")
        }
        if let outcome = result.displaysleepnow {
            WatchDiagnostics.event("displaysleepnow outcome=\(outcome)")
        }
        for line in result.notifications {
            notify(line)
        }
        return result
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

    func dropSavedHygieneWithoutWrite() {
        stopLidPulse()
        brightnessRamp.cancel()
        savedBrightness = nil
        savedKeyboard = nil
    }

    func recaptureOpenLidHygiene() {
        if let current = BrightnessFloorController.current() {
            savedBrightness = current
        }
        if let current = KeyboardBacklightController.current() {
            savedKeyboard = current
        }
    }

    func inboundDisarmReply(_ base: String, sleepResult: HygieneApplyResult? = nil) -> String {
        let extra = (sleepResult?.notifications ?? []).joined(separator: "\n")
        if extra.isEmpty { return base }
        return base + "\n" + extra
    }

    /// `/status` reuses a fresh probe. Do not walk session trees on the main actor.
    func cachedAgentsBusy(now: Date) -> Bool? {
        let included = engine.preferences.includedAgentKinds
        if let snap = agentSnapshotCache.reusable(
            at: now,
            included: included,
            countTerminalSessionsAsBusy: engine.preferences.countTerminalSessionsAsBusy
        ) {
            return snap.anyBusy(included: included)
        }
        return nil
    }

    /// Live battery for `/status`. Do not reprint a poll snapshot after the watch is off.
    func liveStatusSafety() -> SafetyInputs {
        let battery = BatteryMonitor.reading()
        lastBatteryReading = battery
        let safety = SafetyInputs(
            batteryPercent: battery.percent,
            onBatteryDischarging: battery.onBatteryDischarging,
            thermalSerious: ThermalMonitor.isSerious(),
            lowPowerMode: ProcessInfo.processInfo.isLowPowerModeEnabled
        )
        lastSafety = safety
        return safety
    }

    func invalidateAgentProbe() {
        engine.interruptAgentObservations()
        diagnostics.interrupt()
        agentSnapshotCache.invalidate()
        probeGeneration &+= 1
        probeInFlight = false
    }
}
