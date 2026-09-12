import Foundation

public struct UserPreferences: Equatable, Sendable, Codable {
    public var batteryFloorPercent: Int
    public var duration: DurationOption
    public var forceDisplaySleep: Bool
    public var keyboardBacklightOff: Bool
    public var applyBrightnessFloor: Bool
    public var brightnessFloor: Double
    public var agentSettleGrace: TimeInterval
    public var sessionFreshness: TimeInterval
    public var hotkey: HotkeyChord

    public init(
        batteryFloorPercent: Int = 15,
        duration: DurationOption = .indefinite,
        forceDisplaySleep: Bool = false,
        keyboardBacklightOff: Bool = true,
        applyBrightnessFloor: Bool = true,
        brightnessFloor: Double = 0.15,
        agentSettleGrace: TimeInterval = 90,
        sessionFreshness: TimeInterval = 45,
        hotkey: HotkeyChord = .defaultToggle
    ) {
        self.batteryFloorPercent = min(max(batteryFloorPercent, 5), 50)
        self.duration = duration
        self.forceDisplaySleep = forceDisplaySleep
        self.keyboardBacklightOff = keyboardBacklightOff
        self.applyBrightnessFloor = applyBrightnessFloor
        self.brightnessFloor = min(max(brightnessFloor, 0.05), 0.4)
        self.agentSettleGrace = agentSettleGrace
        self.sessionFreshness = sessionFreshness
        self.hotkey = hotkey
    }

    public static let `default` = UserPreferences()
}
