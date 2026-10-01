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
    let readKernel: () -> SleepDisabledState
    let setKernel: (Bool) -> ToggleResult
    let runCommand: (String, [String]) -> (exit: Int32, out: String, err: String)
    let postIdle: (Bool) async -> Void
    let notify: (String) -> Void
    let postQuestionNotice: @MainActor (String) async -> Void
    let readNotifSecrets: () -> NotifSecrets
    let questionTransport: QuestionRelayCoordinator.Transport
    let openCodeQuestionExchange: OpenCodeQuestionSource.Exchange?
    let openCodeQuestionStreamSession: URLSession?
    var openCodeQuestionSource: OpenCodeQuestionSource?
    var openCodeSourceSettings: OpenCodeQuestionSettings?
    var openCodeRelaySettings: QuestionRelaySettings?
    var openCodeQuestionState: OpenCodeQuestionConnectionState = .stopped
    var questionSourcesSuspended = false
    var questionSourcesTerminated = false
    var questionUptime: () -> TimeInterval = { ProcessInfo.processInfo.systemUptime }
    var questionWaitPolicy = QuestionWaitPolicy()
    var questionDeadlines: [QuestionKey: TimeInterval] = [:]
    var questionNewlyExpired: Set<QuestionKey> = []
    var questionUnansweredKeys: Set<QuestionKey> = []
    var questionCleared: Set<QuestionKey> = []
    var questionSleepTask: Task<Void, Never>?
    var questionSleepGeneration: UInt64 = 0
    var questionReleaseFailureReported = false
    var evaluatingQuestionTick = false
    var engine: WatchEngine
    var pollTimer: Timer?
    var savedBrightness: Double?
    var savedKeyboard: Double?
    var hygieneDevices = HygieneDevices()
    var hygieneEffects = HygieneEffects()
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
    lazy var questionRelay = makeQuestionRelay()
    var discordApplicationId: String?
    var workspaceObservers: [NSObjectProtocol] = []
    var lastBatteryReading: BatteryReading?
    var lastSafety: SafetyInputs?
    var agentSnapshotCache = AgentSnapshotCache()
    var probeGeneration: UInt64 = 0
    var probeInFlight = false
    var idleProbeTicks: Int = 0
    var diagnostics = WatchDiagnostics()
    private(set) var ownsWakeHold = false

    init(
        store: PreferencesStore = PreferencesStore(),
        readLid: @escaping () -> Bool = LidStateReader.isClosed,
        readKernel: @escaping () -> SleepDisabledState = SleepDisabledController.read,
        setKernel: @escaping (Bool) -> ToggleResult = SleepDisabledController.set,
        runCommand: @escaping (String, [String]) -> (exit: Int32, out: String, err: String) = {
            ProcessRunner.run($0, $1)
        },
        postIdle: @escaping (Bool) async -> Void = { await NotifIdlePoster.postIfNeeded(enabled: $0) },
        notify: @escaping (String) -> Void = UserNotify.post,
        postQuestionNotice: @escaping @MainActor (String) async -> Void = { await QuestionNoticeSender.send($0) },
        readNotifSecrets: @escaping () -> NotifSecrets = NotifSecretsStore.load,
        questionTransport: @escaping QuestionRelayCoordinator.Transport = { await TelegramInboundHTTP.exchangeQuestion($0) },
        openCodeQuestionExchange: OpenCodeQuestionSource.Exchange? = nil,
        openCodeQuestionStreamSession: URLSession? = nil
    ) {
        self.store = store
        self.readLid = readLid
        self.readKernel = readKernel
        self.setKernel = setKernel
        self.runCommand = runCommand
        self.postIdle = postIdle
        self.notify = notify
        self.postQuestionNotice = postQuestionNotice
        self.readNotifSecrets = readNotifSecrets
        self.questionTransport = questionTransport
        self.openCodeQuestionExchange = openCodeQuestionExchange
        self.openCodeQuestionStreamSession = openCodeQuestionStreamSession
        engine = WatchEngine(preferences: store.load())
    }

    func start() -> Bool {
        guard SleepDisabledCrashGuard.start() else {
            notify("Couldn't take ownership of the wake hold. Agrypnos may already be running.")
            return false
        }
        ownsWakeHold = true
        inboundPoller.runtime = self
        discordGateway.runtime = self
        observeMacSleepWake()
        reconcileKernel(preferClearLeftover: true)
        pollTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.poll() }
        }
        poll()
        inboundPoller.sync()
        discordGateway.sync()
        syncQuestionSources()
        return true
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
        if preferences.panelPowerMode == .floor, mode == .displaySleep {
            PowerHygieneCoordinator.restoreBrightness(effects: &hygieneEffects, captured: savedBrightness,
                                                      ramp: brightnessRamp, devices: hygieneDevices)
        }
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
        clearQuestionWatch()
        delegate?.watchRuntimeDidChange(self)
    }

    func setNotifEnabled(_ on: Bool) {
        engine.preferences.notifEnabled = on
        store.save(engine.preferences)
        delegate?.watchRuntimeDidChange(self)
    }

    func setTelegramInboundEnabled(_ on: Bool) {
        guard preferences.telegramInboundEnabled != on else { return }
        engine.userSetTelegramInboundEnabled(on)
        store.save(engine.preferences)
        inboundPoller.sync()
        clearQuestionWatch()
        pollLid()
        delegate?.watchRuntimeDidChange(self)
    }

    func setDiscordInboundEnabled(_ on: Bool) {
        guard preferences.discordInboundEnabled != on else { return }
        engine.userSetDiscordInboundEnabled(on)
        store.save(engine.preferences)
        discordGateway.sync()
        clearQuestionWatch()
        pollLid()
        delegate?.watchRuntimeDidChange(self)
    }

    func notifSecrets() -> NotifSecrets {
        readNotifSecrets()
    }

    @discardableResult
    func setNotifDiscordWebhookURL(_ value: String?) -> Bool {
        NotifSecretsStore.setDiscordWebhookURL(value)
    }

    @discardableResult
    func setNotifTelegramBotToken(_ value: String?) -> Bool {
        guard NotifSecretsPayload.present(value) != readNotifSecrets().telegramBotToken else { return true }
        questionRelay.invalidateAll()
        store.resetTelegramInboundCursor()
        inboundPoller.invalidate()
        let saved = NotifSecretsStore.setTelegramBotToken(value)
        inboundPoller.sync()
        clearQuestionWatch()
        return saved
    }

    @discardableResult
    func setNotifTelegramChatId(_ value: String?) -> Bool {
        guard NotifSecretsPayload.present(value) != readNotifSecrets().telegramChatId else { return true }
        questionRelay.invalidateAll()
        let saved = NotifSecretsStore.setTelegramChatId(value)
        inboundPoller.sync()
        clearQuestionWatch()
        return saved
    }

    @discardableResult
    func setNotifDiscordBotToken(_ value: String?) -> Bool {
        guard NotifSecretsPayload.present(value) != readNotifSecrets().discordBotToken else { return true }
        questionRelay.invalidateAll()
        store.resetDiscordInboundCursor()
        discordGateway.invalidate()
        let saved = NotifSecretsStore.setDiscordBotToken(value)
        discordGateway.sync()
        clearQuestionWatch()
        return saved
    }

    @discardableResult
    func setNotifDiscordChannelId(_ value: String?) -> Bool {
        guard NotifSecretsPayload.present(value) != readNotifSecrets().discordChannelId else { return true }
        questionRelay.invalidateAll()
        let saved = NotifSecretsStore.setDiscordChannelId(value)
        discordGateway.sync()
        clearQuestionWatch()
        return saved
    }

    func clearNotifSecrets() {
        questionRelay.invalidateAll()
        store.resetTelegramInboundCursor()
        store.resetDiscordInboundCursor()
        inboundPoller.invalidate()
        discordGateway.invalidate()
        NotifSecretsStore.clear()
        clearQuestionWatch()
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
        if keyboard == false {
            PowerHygieneCoordinator.restoreKeyboard(effects: &hygieneEffects, captured: savedKeyboard,
                                                     devices: hygieneDevices)
        }
        if floor == false {
            PowerHygieneCoordinator.restoreBrightness(effects: &hygieneEffects, captured: savedBrightness,
                                                      ramp: brightnessRamp, devices: hygieneDevices)
        }
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
            resetQuestionWatchForNewArm()
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
        return disarmWatch() ?? HygieneApplyResult()
    }

    /// Every user/inbound off must verify the same kernel release before sleep or success copy.
    func disarmWatch() -> HygieneApplyResult? {
        guard disarmKernel() else {
            notify("Couldn't verify SleepDisabled was cleared. The watch state is unchanged.")
            delegate?.watchRuntimeDidChange(self)
            return nil
        }
        cancelQuestionSleep()
        idlePostTask?.cancel()
        idlePostTask = nil
        idleOutbound.cancelInFlight()
        let sleepResult = applyUserOff()
        clearQuestionWatch()
        store.save(engine.preferences)
        syncLidPulse()
        delegate?.watchRuntimeDidChange(self)
        return sleepResult
    }

    @discardableResult
    func apply(_ commands: [WatchCommand]) -> HygieneApplyResult {
        for command in commands {
            if case .assertSleepDisabled = command {
                guard armKernel(allowInstall: false) else {
                    engine.endForWakeHoldFailure(now: Date())
                    idlePostTask?.cancel()
                    idlePostTask = nil
                    idleOutbound.cancelInFlight()
                    invalidateAgentProbe()
                    restoreHygiene()
                    store.save(engine.preferences)
                    delegate?.watchRuntimeDidChange(self)
                    return HygieneApplyResult()
                }
            }
        }
        let result = PowerHygieneCoordinator.apply(
            commands,
            preferences: engine.preferences,
            armed: engine.engaged,
            lidCloseConfirmed: engine.lidCloseConfirmed && readLid(),
            effects: &hygieneEffects,
            savedBrightness: &savedBrightness,
            savedKeyboard: &savedKeyboard,
            ramp: brightnessRamp,
            devices: hygieneDevices,
            readLid: readLid,
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
            effects: &hygieneEffects,
            savedBrightness: &savedBrightness,
            savedKeyboard: &savedKeyboard,
            ramp: brightnessRamp,
            devices: hygieneDevices
        )
    }

    func dropSavedHygieneWithoutWrite() {
        stopLidPulse()
        brightnessRamp.cancel()
        savedBrightness = nil
        savedKeyboard = nil
        hygieneEffects = HygieneEffects()
    }

    func recaptureOpenLidHygiene() {
        savedBrightness = hygieneDevices.brightness()
        savedKeyboard = hygieneDevices.keyboard()
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
