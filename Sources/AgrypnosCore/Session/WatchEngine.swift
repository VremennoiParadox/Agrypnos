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
    }

    public mutating func userSetEngaged(_ on: Bool, now: Date, lidClosed: Bool = false) -> [WatchCommand] {
        leftoverAdopted = false
        self.lidClosed = lidClosed
        if on {
            return engage(now: now, forcedByUser: true)
        }
        return disengage(.user)
    }

    /// Kernel `SleepDisabled` was already on and could not be cleared. Adopt visibly.
    /// Lid-open adopt must not blank the panel; lid-closed adopt reapplies floor + keys.
    public mutating func adoptLeftoverKernel(now: Date, lidClosed: Bool = false) -> [WatchCommand] {
        self.lidClosed = lidClosed
        leftoverAdopted = true
        if engaged {
            if lidClosed {
                lidHygieneApplied = true
                return lidCloseHygieneCommands()
            }
            return []
        }
        return engage(now: now, forcedByUser: false)
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

    public mutating func tick(now: Date, safety: SafetyInputs, agents: AgentSnapshot) -> [WatchCommand] {
        guard engaged else { return [] }
        if let reason = AutoOffEvaluator.reason(
            engaged: true,
            timerEnd: timerEnd,
            safety: safety,
            batteryFloorPercent: preferences.batteryFloorPercent,
            userForcedThisSession: userForcedThisSession,
            now: now
        ) {
            return disengage(reason)
        }
        if mode == .untilAgentsSettle {
            let activity = settle.observe(busy: agents.anyBusy, now: now)
            if activity == .settled {
                return disengage(.agentsSettled)
            }
        }
        return []
    }

    public mutating func lidDidClose(now: Date) -> [WatchCommand] {
        lidClosed = true
        _ = now
        guard engaged else { return [] }
        guard !lidHygieneApplied else { return [] }
        lidHygieneApplied = true
        return lidCloseHygieneCommands()
    }

    public mutating func lidDidOpen(now: Date) -> [WatchCommand] {
        lidClosed = false
        _ = now
        guard engaged else { return [] }
        guard lidHygieneApplied else { return [] }
        lidHygieneApplied = false
        return lidOpenRestoreCommands()
    }

    mutating func engage(now: Date, forcedByUser: Bool) -> [WatchCommand] {
        engaged = true
        userForcedThisSession = forcedByUser
        settle = AgentSettleTracker(grace: preferences.agentSettleGrace)
        applyDuration(now: now)
        var commands: [WatchCommand] = [.engage]
        if lidClosed {
            commands.append(contentsOf: lidCloseHygieneCommands())
            lidHygieneApplied = true
        } else {
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

    mutating func disengage(_ reason: DisengageReason) -> [WatchCommand] {
        engaged = false
        mode = .idle
        timerEnd = nil
        userForcedThisSession = false
        leftoverAdopted = false
        lidHygieneApplied = false
        settle.reset()
        return [.disengage(reason)]
    }

    /// Lid close only: brightness floor + keyboard off. Never `displaysleepnow`.
    func lidCloseHygieneCommands() -> [WatchCommand] {
        var commands: [WatchCommand] = []
        if preferences.applyBrightnessFloor {
            commands.append(.applyBrightnessFloor)
        }
        if preferences.keyboardBacklightOff {
            commands.append(.requestKeyboardBacklightOff)
        }
        return commands
    }

    func lidOpenRestoreCommands() -> [WatchCommand] {
        var commands: [WatchCommand] = []
        if preferences.applyBrightnessFloor {
            commands.append(.rampBrightnessRestore)
        }
        if preferences.keyboardBacklightOff {
            commands.append(.restoreKeyboardBacklight)
        }
        return commands
    }
}
