import Foundation

public struct UserPreferences: Equatable, Sendable, Codable {
    public static let batteryFloorRange = 5...100

    public var batteryFloorPercent: Int
    public var duration: DurationOption
    public var keyboardBacklightOff: Bool
    public var applyBrightnessFloor: Bool
    public var brightnessFloor: Double
    public var agentSettleGrace: TimeInterval
    public var sessionFreshness: TimeInterval
    public var hotkey: HotkeyChord

    public init(
        batteryFloorPercent: Int = 15,
        duration: DurationOption = .indefinite,
        keyboardBacklightOff: Bool = true,
        applyBrightnessFloor: Bool = true,
        brightnessFloor: Double = 0.15,
        agentSettleGrace: TimeInterval = 90,
        sessionFreshness: TimeInterval = 45,
        hotkey: HotkeyChord = .defaultToggle
    ) {
        self.batteryFloorPercent = Self.clampBatteryFloor(batteryFloorPercent)
        self.duration = duration
        self.keyboardBacklightOff = keyboardBacklightOff
        self.applyBrightnessFloor = applyBrightnessFloor
        self.brightnessFloor = min(max(brightnessFloor, 0.05), 0.4)
        self.agentSettleGrace = agentSettleGrace
        self.sessionFreshness = sessionFreshness
        self.hotkey = hotkey
    }

    public static let `default` = UserPreferences()

    public static func clampBatteryFloor(_ percent: Int) -> Int {
        min(max(percent, batteryFloorRange.lowerBound), batteryFloorRange.upperBound)
    }

    /// Persist a remap only when the chord is safe to bind. Registration success is a Mac concern.
    @discardableResult
    public mutating func applyHotkeyRemap(_ chord: HotkeyChord) -> Bool {
        guard chord.isBindable else { return false }
        hotkey = chord
        return true
    }

    enum CodingKeys: String, CodingKey {
        case batteryFloorPercent
        case duration
        case keyboardBacklightOff
        case applyBrightnessFloor
        case brightnessFloor
        case agentSettleGrace
        case sessionFreshness
        case hotkey
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            batteryFloorPercent: try container.decode(Int.self, forKey: .batteryFloorPercent),
            duration: try container.decode(DurationOption.self, forKey: .duration),
            keyboardBacklightOff: try container.decode(Bool.self, forKey: .keyboardBacklightOff),
            applyBrightnessFloor: try container.decode(Bool.self, forKey: .applyBrightnessFloor),
            brightnessFloor: try container.decode(Double.self, forKey: .brightnessFloor),
            agentSettleGrace: try container.decode(TimeInterval.self, forKey: .agentSettleGrace),
            sessionFreshness: try container.decode(TimeInterval.self, forKey: .sessionFreshness),
            hotkey: try container.decodeIfPresent(HotkeyChord.self, forKey: .hotkey) ?? .defaultToggle
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(batteryFloorPercent, forKey: .batteryFloorPercent)
        try container.encode(duration, forKey: .duration)
        try container.encode(keyboardBacklightOff, forKey: .keyboardBacklightOff)
        try container.encode(applyBrightnessFloor, forKey: .applyBrightnessFloor)
        try container.encode(brightnessFloor, forKey: .brightnessFloor)
        try container.encode(agentSettleGrace, forKey: .agentSettleGrace)
        try container.encode(sessionFreshness, forKey: .sessionFreshness)
        try container.encode(hotkey, forKey: .hotkey)
    }
}
