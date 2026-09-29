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

public enum SleepDisabledState: Equatable, Sendable {
    case held, clear, unknown
}

public enum SleepDisabledParser: Sendable {
    public static func state(pmsetG: String, exit: Int32) -> SleepDisabledState {
        guard exit == 0 else { return .unknown }
        var result: SleepDisabledState = .unknown
        for line in pmsetG.split(whereSeparator: \.isNewline) {
            let tokens = line.split(whereSeparator: { $0 == " " || $0 == "\t" })
            guard tokens.first?.lowercased() == "sleepdisabled" else { continue }
            guard tokens.count == 2, result == .unknown else { return .unknown }
            switch tokens[1] {
            case "0": result = .clear
            case "1": result = .held
            default: return .unknown
            }
        }
        return result
    }

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
