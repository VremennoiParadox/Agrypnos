import Foundation

public struct WatchEngine: Equatable, Sendable {
    public var preferences: UserPreferences
    public private(set) var engaged: Bool
    public private(set) var mode: WatchMode
    public private(set) var timerEnd: Date?
    public private(set) var settle: AgentSettleTracker
    public private(set) var userForcedThisSession: Bool
    public private(set) var leftoverAdopted: Bool
    public private(set) var lidClosed: Bool
    public private(set) var lidHygieneApplied: Bool
    /// Live confirm from `LidCloseConfirm`. Do not use leftover `lidClosed` after disengage.
    public var lidCloseConfirmed: Bool { lidConfirm.confirmedClosed }
    /// User-off / inbound sleepnow uses the live stable lid, including during a POST hold.
    public func userOffLidCloseConfirmed(rawClosed: Bool) -> Bool {
        lidCloseConfirmed && rawClosed
    }
    /// Raw closed, not yet stable. 4 Hz pulse only while this is true.
    public var lidClosePending: Bool { lidConfirm.isPendingClose }
    /// One outbound POST per genuine user arm. Survives disarm-failure rollback.
    public private(set) var postedThisUserArm: Bool
    /// Kernel still held during the bounded watch-end POST. Do not paint ended.
    public private(set) var holdingForIdlePost: Bool
    public private(set) var lastDisengageLidClosed: Bool
    var lastWatchEndRollback: LastWatchEnd?
    private var timerEndRollback: Date?
    var pendingLastWatchEnd: LastWatchEnd?
    private var lidConfirm: LidCloseConfirm

    public init(preferences: UserPreferences = .default) {
        self.preferences = preferences
        self.engaged = false
        self.mode = .idle
        self.timerEnd = nil
        self.settle = AgentSettleTracker(grace: preferences.agentSettleGrace)
        self.userForcedThisSession = false
        self.leftoverAdopted = false
        self.lidClosed = false
        self.lidHygieneApplied = false
        self.postedThisUserArm = false
        self.holdingForIdlePost = false
        self.lastWatchEndRollback = nil
        self.timerEndRollback = nil
        self.lastDisengageLidClosed = false
        self.pendingLastWatchEnd = nil
        self.lidConfirm = LidCloseConfirm()
    }

    public mutating func userSetEngaged(_ on: Bool, now: Date, lidClosed: Bool = false) -> [WatchCommand] {
        leftoverAdopted = false
        self.lidClosed = lidClosed
        if on {
            return engage(now: now, forcedByUser: true, resetPostedThisUserArm: true)
        }
        return disengage(.user, at: now)
    }

    /// Stop claiming a protected watch when the native reassertion fails. No sleep request.
    public mutating func endForWakeHoldFailure(now: Date) {
        _ = disengage(.wakeHoldFailed, at: now)
    }

    /// Kernel disarm failed after logical disengage. Same user arm — keep the POST latch.
    /// Do not sample `engine.lidClosed` after disengage zeroed it — use the stored lid.
    public mutating func rollbackDisarmFailure(now: Date, lidClosed: Bool = false) -> [WatchCommand] {
        _ = lidClosed
        holdingForIdlePost = false
        pendingLastWatchEnd = nil
        let restored = lastWatchEndRollback
        lastWatchEndRollback = nil
        leftoverAdopted = false
        self.lidClosed = lastDisengageLidClosed
        let deadline = timerEndRollback
        let commands = engage(now: now, forcedByUser: true, resetPostedThisUserArm: false)
        timerEnd = deadline
        preferences.lastWatchEnd = restored
        return commands
    }

    /// Kernel clear succeeded after the watch-end POST. Last-end honesty may show now.
    public mutating func completeIdlePostHold() {
        guard holdingForIdlePost else { return }
        holdingForIdlePost = false
        if let pending = pendingLastWatchEnd {
            preferences.lastWatchEnd = pending
        }
        pendingLastWatchEnd = nil
    }

    /// Kernel `SleepDisabled` was already on and could not be cleared. Adopt visibly.
    /// Lid-open adopt must not blank the panel; lid-closed adopt reapplies hygiene.
    public mutating func adoptLeftoverKernel(now: Date, lidClosed: Bool = false) -> [WatchCommand] {
        self.lidClosed = lidClosed
        leftoverAdopted = true
        if engaged {
            if lidClosed {
                lidHygieneApplied = true
                lidConfirm.markConfirmedClosed()
                return lidCloseHygieneCommands()
            }
            return []
        }
        return engage(now: now, forcedByUser: false, resetPostedThisUserArm: true)
    }

    public mutating func userSetDuration(_ option: DurationOption, now: Date) -> [WatchCommand] {
        preferences.duration = option
        settle.grace = preferences.agentSettleGrace
        guard engaged else { return [] }
        applyDuration(now: now)
        if option == .untilAgentsSettle {
            settle.reset()
        }
        return []
    }

    public mutating func interruptAgentObservations() {
        settle.interruptObservations()
    }

    public mutating func userSetAgentSettleGrace(_ seconds: TimeInterval) {
        preferences.agentSettleGrace = UserPreferences.clampAgentSettleGrace(seconds)
        settle.grace = preferences.agentSettleGrace
    }

    public mutating func userSetTelegramInboundEnabled(_ on: Bool) {
        preferences.telegramInboundEnabled = on
    }

    public mutating func userSetDiscordInboundEnabled(_ on: Bool) {
        preferences.discordInboundEnabled = on
    }

    public mutating func userSetCountTerminalSessionsAsBusy(_ on: Bool) {
        preferences.countTerminalSessionsAsBusy = on
    }

    public mutating func userSetPanelPowerMode(_ mode: PanelPowerMode) -> [WatchCommand] {
        let from = preferences.panelPowerMode
        preferences.panelPowerMode = mode
        guard from != mode else { return [] }
        guard engaged, lidCloseConfirmed else { return [] }
        var commands: [WatchCommand] = []
        if from == .displaySleep, mode == .floor {
            commands.append(.wakeDisplay)
        }
        commands.append(contentsOf: lidCloseHygieneCommands())
        return commands
    }

    /// Shared Telegram + Discord arm/disarm/status/help. One stack — no second disarm path.
    /// Arm always `lidClosed: false` — one raw clamshell sample is not hygiene.
    /// Disarm sleeps only when lid-close is already confirmed.
    public mutating func applyInbound(
        _ intent: TelegramInboundIntent,
        now: Date,
        lidCloseConfirmed: Bool = false
    ) -> [WatchCommand] {
        switch intent {
        case .arm:
            switch intent.shouldSetEngaged(currentlyEngaged: engaged) {
            case .some(true):
                return userSetEngaged(true, now: now, lidClosed: false)
            case .some(false), .none:
                return []
            }
        case .disarm:
            if intent.shouldSetEngaged(currentlyEngaged: engaged) == false {
                // userSetEngaged(.user) uses the same lid-gated sleepnow as inbound.
                return userSetEngaged(false, now: now, lidClosed: lidCloseConfirmed)
            }
            // Already off: still clear hold + sleepnow when lid-close is confirmed.
            if TelegramInboundDisarm.shouldRequestSleep(lidCloseConfirmed: lidCloseConfirmed) {
                return [.requestSleep]
            }
            return []
        case .status, .help, .ignore:
            return []
        }
    }

    public mutating func applyTelegramInbound(
        _ intent: TelegramInboundIntent,
        now: Date,
        lidCloseConfirmed: Bool = false
    ) -> [WatchCommand] {
        applyInbound(intent, now: now, lidCloseConfirmed: lidCloseConfirmed)
    }

    public mutating func tick(
        now: Date,
        safety: SafetyInputs,
        agents: AgentSnapshot,
        kernelSleepDisabled: Bool = true,
        observeAgents: Bool = true,
        questionWait: QuestionWaitDecision = .normal
    ) -> [WatchCommand] {
        guard engaged else { return [] }
        if let reason = AutoOffEvaluator.reason(
            engaged: true,
            timerEnd: timerEnd,
            safety: safety,
            batteryFloorPercent: preferences.batteryFloorPercent,
            userForcedThisSession: userForcedThisSession,
            thermalAutoOff: preferences.thermalAutoOff,
            now: now
        ), reason.turnsWatchOff {
            return disengage(reason, at: now)
        }
        if questionWait.action == .endUnanswered {
            return disengage(.questionUnanswered, at: now)
        }
        if questionWait.action == .hold || questionWait.action == .deferTimeout {
            if observeAgents, agents.anyBusy(included: preferences.includedAgentKinds) {
                _ = settle.observe(busy: true, now: now)
            } else {
                settle.interruptObservations()
            }
        } else if observeAgents, mode == .untilAgentsSettle {
            let activity = settle.observe(
                busy: agents.anyBusy(included: preferences.includedAgentKinds),
                now: now
            )
            if activity == .settled {
                return disengage(.agentsSettled, at: now)
            }
        }
        if !kernelSleepDisabled {
            return [.assertSleepDisabled]
        }
        return []
    }

    public mutating func lidDidClose(now: Date) -> [WatchCommand] {
        lidClosed = true
        lidConfirm.markConfirmedClosed()
        _ = now
        guard engaged else { return [] }
        guard !lidHygieneApplied else { return [] }
        lidHygieneApplied = true
        return [.assertSleepDisabled] + lidCloseHygieneCommands()
    }

    public mutating func lidDidOpen(now: Date) -> [WatchCommand] {
        lidClosed = false
        lidConfirm.reset()
        _ = now
        guard engaged else { return [] }
        guard lidHygieneApplied else { return [] }
        lidHygieneApplied = false
        return lidOpenRestoreCommands()
    }

    /// Raw clamshell samples. Floor only after a stable closed confirm while armed.
    public mutating func observeLid(closed: Bool, now: Date) -> [WatchCommand] {
        if !closed {
            lidClosed = false
        }
        switch lidConfirm.sample(closed, now: now) {
        case .closed:
            return lidDidClose(now: now)
        case .opened:
            return lidDidOpen(now: now)
        case nil:
            return []
        }
    }

    mutating func engage(
        now: Date,
        forcedByUser: Bool,
        resetPostedThisUserArm: Bool
    ) -> [WatchCommand] {
        engaged = true
        userForcedThisSession = forcedByUser
        holdingForIdlePost = false
        pendingLastWatchEnd = nil
        if resetPostedThisUserArm {
            postedThisUserArm = false
        }
        settle = AgentSettleTracker(grace: preferences.agentSettleGrace)
        applyDuration(now: now)
        var commands: [WatchCommand] = [.engage]
        if lidClosed {
            lidConfirm.markConfirmedClosed()
            commands.append(.assertSleepDisabled)
            commands.append(contentsOf: lidCloseHygieneCommands())
            lidHygieneApplied = true
        } else {
            lidConfirm.reset()
            lidHygieneApplied = false
        }
        return commands
    }

    mutating func applyDuration(now: Date) {
        switch preferences.duration {
        case .indefinite:
            mode = .indefinite
            timerEnd = nil
        case .oneHour, .threeHours, .custom:
            mode = .timed
            let minutes = preferences.duration.minutes ?? 60
            timerEnd = now.addingTimeInterval(TimeInterval(minutes) * 60)
        case .untilAgentsSettle:
            mode = .untilAgentsSettle
            timerEnd = nil
        }
    }

    mutating func disengage(_ reason: DisengageReason, at now: Date) -> [WatchCommand] {
        let wasEngaged = engaged
        // Capture before reset: settled already requires sawBusy; keep that honesty.
        let postWatchEnd = wasEngaged && !postedThisUserArm && (
            NotifIdlePostPolicy.shouldPost(enabled: preferences.notifEnabled, reason: reason, sawBusy: settle.sawBusy)
            || (preferences.notifEnabled && reason == .timerExpired)
        )
        let wasHygieneApplied = lidHygieneApplied
        let wasLidClosed = lidClosed
        lastDisengageLidClosed = wasLidClosed
        if wasEngaged {
            lastWatchEndRollback = preferences.lastWatchEnd
            timerEndRollback = timerEnd
            let end = LastWatchEnd(endedAt: now, reason: reason)
            if postWatchEnd {
                pendingLastWatchEnd = end
            } else {
                preferences.lastWatchEnd = end
            }
        }
        engaged = false
        mode = .idle
        timerEnd = nil
        userForcedThisSession = false
        leftoverAdopted = false
        lidHygieneApplied = false
        if !postWatchEnd {
            lidConfirm.reset()
            lidClosed = false
        }
        settle.reset()
        var commands: [WatchCommand] = [.disengage(reason)]
        if postWatchEnd {
            postedThisUserArm = true
            holdingForIdlePost = true
            commands.append(reason == .timerExpired ? .postTimerExpiredNotif : .postIdleAfterWaitNotif)
        } else {
            holdingForIdlePost = false
            pendingLastWatchEnd = nil
        }
        if wasHygieneApplied,
           let wake = PanelPowerMode.disengageDisplayCommand(
            mode: preferences.panelPowerMode,
            lidCloseConfirmed: wasLidClosed
           )
        {
            commands.append(wake)
        }
        // One sleep story: inbound `/disarm` and popover/hotkey user-off share this gate.
        // Timer expiry always offers sleep; the adapter skips a known-open lid.
        if reason == .timerExpired || TelegramInboundDisarm.shouldRequestSleep(lidCloseConfirmed: wasLidClosed) {
            commands.append(.requestSleep)
        }
        return commands
    }

    /// Confirmed lid close: Power A floor or Power B display sleep. Never both. Never Mac sleep.
    func lidCloseHygieneCommands() -> [WatchCommand] {
        PanelPowerMode.lidCloseCommands(
            armed: engaged,
            lidCloseConfirmed: lidCloseConfirmed,
            mode: preferences.panelPowerMode,
            applyBrightnessFloor: preferences.applyBrightnessFloor,
            keyboardBacklightOff: preferences.keyboardBacklightOff
        )
    }

    func lidOpenRestoreCommands() -> [WatchCommand] {
        PanelPowerMode.lidOpenCommands(
            mode: preferences.panelPowerMode,
            applyBrightnessFloor: preferences.applyBrightnessFloor,
            keyboardBacklightOff: preferences.keyboardBacklightOff
        )
    }
}
