import Foundation

public struct UserPreferences: Equatable, Sendable, Codable {
    public static let batteryFloorRange = 5...100
    /// Lid-close brightness floor as percent. Lowest is the default; 0% is not a sleep trick.
    public static let brightnessFloorPercentRange = 5...40
    /// Quiet seconds after last busy before Agents mode allows sleep.
    public static let agentSettleGraceRange = 15...900
    /// Lid-open brightness ramp, seconds.
    public static let lidOpenRampRange = 1...3

    public var batteryFloorPercent: Int
    public var duration: DurationOption
    public var keyboardBacklightOff: Bool
    public var applyBrightnessFloor: Bool
    public var brightnessFloorPercent: Int
    public var agentSettleGrace: TimeInterval
    public var sessionFreshness: TimeInterval
    public var hotkey: HotkeyChord
    public var lidOpenRampSeconds: Int

    /// 0...1 unit the Mac brightness adapter writes. Derived from floor %.
    public var brightnessFloor: Double {
        Double(brightnessFloorPercent) / 100.0
    }

    public init(
        batteryFloorPercent: Int = 15,
        duration: DurationOption = .indefinite,
        keyboardBacklightOff: Bool = true,
        applyBrightnessFloor: Bool = true,
        brightnessFloorPercent: Int = 5,
        agentSettleGrace: TimeInterval = 90,
        sessionFreshness: TimeInterval = 45,
        hotkey: HotkeyChord = .defaultToggle,
        lidOpenRampSeconds: Int = 2
    ) {
        self.batteryFloorPercent = Self.clampBatteryFloor(batteryFloorPercent)
        self.duration = duration
        self.keyboardBacklightOff = keyboardBacklightOff
        self.applyBrightnessFloor = applyBrightnessFloor
        self.brightnessFloorPercent = Self.clampBrightnessFloor(brightnessFloorPercent)
        self.agentSettleGrace = Self.clampAgentSettleGrace(agentSettleGrace)
        self.sessionFreshness = sessionFreshness
        self.hotkey = hotkey.isBindable ? hotkey : .defaultToggle
        self.lidOpenRampSeconds = Self.clampLidOpenRamp(lidOpenRampSeconds)
    }

    public static let `default` = UserPreferences()

    public static func clampBatteryFloor(_ percent: Int) -> Int {
        min(max(percent, batteryFloorRange.lowerBound), batteryFloorRange.upperBound)
    }

    public static func clampBrightnessFloor(_ percent: Int) -> Int {
        min(max(percent, brightnessFloorPercentRange.lowerBound), brightnessFloorPercentRange.upperBound)
    }

    public static func clampAgentSettleGrace(_ seconds: TimeInterval) -> TimeInterval {
        let clamped = min(
            max(Int(seconds.rounded()), agentSettleGraceRange.lowerBound),
            agentSettleGraceRange.upperBound
        )
        return TimeInterval(clamped)
    }

    public static func clampAgentSettleGrace(minutes: Int) -> TimeInterval {
        clampAgentSettleGrace(TimeInterval(minutes) * 60)
    }

    public static func clampLidOpenRamp(_ seconds: Int) -> Int {
        min(max(seconds, lidOpenRampRange.lowerBound), lidOpenRampRange.upperBound)
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
        case brightnessFloorPercent
        case agentSettleGrace
        case sessionFreshness
        case hotkey
        case lidOpenRampSeconds
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let brightnessPercent: Int
        if let percent = try container.decodeIfPresent(Int.self, forKey: .brightnessFloorPercent) {
            brightnessPercent = percent
        } else if let fraction = try container.decodeIfPresent(Double.self, forKey: .brightnessFloor) {
            brightnessPercent = Int((fraction * 100).rounded())
        } else {
            brightnessPercent = Self.brightnessFloorPercentRange.lowerBound
        }
        self.init(
            batteryFloorPercent: try container.decode(Int.self, forKey: .batteryFloorPercent),
            duration: try container.decode(DurationOption.self, forKey: .duration),
            keyboardBacklightOff: try container.decode(Bool.self, forKey: .keyboardBacklightOff),
            applyBrightnessFloor: try container.decode(Bool.self, forKey: .applyBrightnessFloor),
            brightnessFloorPercent: brightnessPercent,
            agentSettleGrace: try container.decodeIfPresent(TimeInterval.self, forKey: .agentSettleGrace) ?? 90,
            sessionFreshness: try container.decode(TimeInterval.self, forKey: .sessionFreshness),
            hotkey: try container.decodeIfPresent(HotkeyChord.self, forKey: .hotkey) ?? .defaultToggle,
            lidOpenRampSeconds: try container.decodeIfPresent(Int.self, forKey: .lidOpenRampSeconds) ?? 2
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(batteryFloorPercent, forKey: .batteryFloorPercent)
        try container.encode(duration, forKey: .duration)
        try container.encode(keyboardBacklightOff, forKey: .keyboardBacklightOff)
        try container.encode(applyBrightnessFloor, forKey: .applyBrightnessFloor)
        try container.encode(brightnessFloor, forKey: .brightnessFloor)
        try container.encode(brightnessFloorPercent, forKey: .brightnessFloorPercent)
        try container.encode(agentSettleGrace, forKey: .agentSettleGrace)
        try container.encode(sessionFreshness, forKey: .sessionFreshness)
        try container.encode(hotkey, forKey: .hotkey)
        try container.encode(lidOpenRampSeconds, forKey: .lidOpenRampSeconds)
    }
}

public enum BatteryFloorChrome: Sendable {
    public static var minPercent: Int { UserPreferences.batteryFloorRange.lowerBound }
    public static var maxPercent: Int { UserPreferences.batteryFloorRange.upperBound }
    public static var minLabel: String { "\(minPercent)%" }
    public static var maxLabel: String { "\(maxPercent)%" }
}

public enum BrightnessFloorPercentChrome: Sendable {
    public static var minPercent: Int { UserPreferences.brightnessFloorPercentRange.lowerBound }
    public static var maxPercent: Int { UserPreferences.brightnessFloorPercentRange.upperBound }
    public static var minLabel: String { "\(minPercent)%" }
    public static var maxLabel: String { "\(maxPercent)%" }
}

public enum AgentSettleGraceChrome: Sendable {
    public static var minSeconds: Int { UserPreferences.agentSettleGraceRange.lowerBound }
    public static var maxSeconds: Int { UserPreferences.agentSettleGraceRange.upperBound }
    public static var minLabel: String { "\(minSeconds)s" }
    public static var maxLabel: String { "\(maxSeconds / 60)m" }
}

public enum LidOpenRampChrome: Sendable {
    public static let titles = ["1s", "2s", "3s"]
    public static var options: [Int] { Array(UserPreferences.lidOpenRampRange) }

    public static func selectedSegment(seconds: Int) -> Int {
        let clamped = UserPreferences.clampLidOpenRamp(seconds)
        return options.firstIndex(of: clamped) ?? 1
    }

    public static func seconds(selectingSegment index: Int) -> Int? {
        guard options.indices.contains(index) else { return nil }
        return options[index]
    }
}
