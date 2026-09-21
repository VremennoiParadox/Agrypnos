import Foundation

public struct SafetyInputs: Equatable, Sendable {
    public var batteryPercent: Int?
    public var onBatteryDischarging: Bool
    public var thermalSerious: Bool
    public var lowPowerMode: Bool

    public init(
        batteryPercent: Int?,
        onBatteryDischarging: Bool,
        thermalSerious: Bool,
        lowPowerMode: Bool
    ) {
        self.batteryPercent = batteryPercent
        self.onBatteryDischarging = onBatteryDischarging
        self.thermalSerious = thermalSerious
        self.lowPowerMode = lowPowerMode
    }
}

public enum DisengageReason: String, Equatable, Sendable, CaseIterable, Codable {
    case user
    case timerExpired
    case batteryFloor
    case thermal
    case agentsSettled
    case lowPowerMode

    /// How long is a user setting; timer must not flip it. Agents idle turns Keep the watch off after settle.
    public var turnsWatchOff: Bool {
        switch self {
        case .batteryFloor, .thermal, .lowPowerMode, .agentsSettled:
            return true
        case .user, .timerExpired:
            return false
        }
    }
}

public struct LastWatchEnd: Equatable, Sendable, Codable {
    public var endedAt: Date
    public var reason: DisengageReason
    public init(endedAt: Date, reason: DisengageReason) {
        self.endedAt = endedAt
        self.reason = reason
    }
}

public enum AutoOffEvaluator: Sendable {
    public static func reason(
        engaged: Bool,
        timerEnd: Date?,
        safety: SafetyInputs,
        batteryFloorPercent: Int,
        userForcedThisSession: Bool,
        thermalAutoOff: Bool = true,
        now: Date = Date()
    ) -> DisengageReason? {
        _ = timerEnd
        _ = now
        guard engaged else { return nil }
        if safety.thermalSerious, thermalAutoOff { return .thermal }
        if safety.onBatteryDischarging,
           let percent = safety.batteryPercent,
           percent <= batteryFloorPercent
        {
            return .batteryFloor
        }
        if safety.lowPowerMode, safety.onBatteryDischarging, !userForcedThisSession {
            return .lowPowerMode
        }
        return nil
    }
}
