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

public enum DisengageReason: String, Equatable, Sendable {
    case user
    case timerExpired
    case batteryFloor
    case thermal
    case agentsSettled
    case lowPowerMode
}

public enum AutoOffEvaluator: Sendable {
    public static func reason(
        engaged: Bool,
        timerEnd: Date?,
        safety: SafetyInputs,
        batteryFloorPercent: Int,
        userForcedThisSession: Bool,
        now: Date = Date()
    ) -> DisengageReason? {
        guard engaged else { return nil }
        if safety.thermalSerious { return .thermal }
        if safety.onBatteryDischarging,
           let percent = safety.batteryPercent,
           percent <= batteryFloorPercent
        {
            return .batteryFloor
        }
        if let timerEnd, now >= timerEnd { return .timerExpired }
        if safety.lowPowerMode, safety.onBatteryDischarging, !userForcedThisSession {
            return .lowPowerMode
        }
        return nil
    }
}
