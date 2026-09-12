import Foundation

public struct WatchEngine: Equatable, Sendable {
    public var preferences: UserPreferences
    public private(set) var engaged: Bool
    public private(set) var mode: WatchMode
    public private(set) var timerEnd: Date?
    public private(set) var settle: AgentSettleTracker
    public private(set) var userForcedThisSession: Bool

    public init(preferences: UserPreferences = .default) {
        self.preferences = preferences
        self.engaged = false
        self.mode = .idle
        self.timerEnd = nil
        self.settle = AgentSettleTracker(grace: preferences.agentSettleGrace)
        self.userForcedThisSession = false
    }

    public mutating func userSetEngaged(_ on: Bool, now: Date) -> [WatchCommand] {
        if on {
            return engage(now: now, forcedByUser: true)
        }
        return disengage(.user)
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
        guard engaged else { return [] }
        _ = now
        return hygieneCommands()
    }

    mutating func engage(now: Date, forcedByUser: Bool) -> [WatchCommand] {
        engaged = true
        userForcedThisSession = forcedByUser
        settle = AgentSettleTracker(grace: preferences.agentSettleGrace)
        applyDuration(now: now)
        var commands: [WatchCommand] = [.engage]
        commands.append(contentsOf: hygieneCommands())
        return commands
    }

    mutating func applyDuration(now: Date) {
        switch preferences.duration {
        case .indefinite:
            mode = .indefinite
            timerEnd = nil
        case .oneHour, .threeHours:
            mode = .timed
            let minutes = preferences.duration.minutes ?? 60
            timerEnd = now.addingTimeInterval(TimeInterval(minutes * 60))
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
        settle.reset()
        return [.disengage(reason)]
    }

    func hygieneCommands() -> [WatchCommand] {
        var commands: [WatchCommand] = []
        if preferences.applyBrightnessFloor {
            commands.append(.applyBrightnessFloor)
        }
        if preferences.forceDisplaySleep {
            commands.append(.requestDisplaySleep)
        }
        if preferences.keyboardBacklightOff {
            commands.append(.requestKeyboardBacklightOff)
        }
        return commands
    }
}
