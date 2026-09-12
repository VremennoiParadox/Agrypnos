public struct BatteryReading: Equatable, Sendable {
    public var onBattery: Bool
    public var discharging: Bool
    public var percent: Int?

    public init(onBattery: Bool, discharging: Bool, percent: Int?) {
        self.onBattery = onBattery
        self.discharging = discharging
        self.percent = percent
    }

    public var onBatteryDischarging: Bool { onBattery && discharging }
}

public enum BatteryStatusParser: Sendable {
    public static func parse(pmsetBatt: String) -> BatteryReading {
        let onBattery = pmsetBatt.contains("Battery Power")
        let discharging = pmsetBatt.range(of: "discharging", options: .caseInsensitive) != nil
        var percent: Int?
        for token in pmsetBatt.split(whereSeparator: { " \t\n%;".contains($0) }) {
            if let value = Int(token), pmsetBatt.contains("\(value)%") {
                percent = value
                break
            }
        }
        if percent == nil {
            for raw in pmsetBatt.split(whereSeparator: { $0 == " " || $0 == "\t" || $0 == "\n" || $0 == ";" }) {
                if raw.hasSuffix("%"), let value = Int(raw.dropLast()) {
                    percent = value
                    break
                }
            }
        }
        return BatteryReading(onBattery: onBattery, discharging: discharging, percent: percent)
    }
}

public enum SleepDisabledParser: Sendable {
    public static func parse(pmsetG: String) -> Bool {
        for line in pmsetG.split(whereSeparator: \.isNewline) {
            if line.range(of: "SleepDisabled", options: .caseInsensitive) != nil {
                let tokens = line.split(whereSeparator: { $0 == " " || $0 == "\t" })
                return tokens.last.map(String.init) == "1"
            }
        }
        return false
    }
}
