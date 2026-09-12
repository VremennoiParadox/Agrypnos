public enum DurationOption: Equatable, Sendable {
    case indefinite
    case oneHour
    case threeHours
    case untilAgentsSettle
    case custom(minutes: Int)

    public static let presets: [DurationOption] = [
        .indefinite, .oneHour, .threeHours, .untilAgentsSettle,
    ]

    public static func customMinutes(_ minutes: Int) -> DurationOption {
        .custom(minutes: max(minutes, 1))
    }

    public var minutes: Int? {
        switch self {
        case .indefinite, .untilAgentsSettle: return nil
        case .oneHour: return 60
        case .threeHours: return 180
        case .custom(let value): return max(value, 1)
        }
    }

    public var segmentTitle: String {
        switch self {
        case .indefinite: return "∞"
        case .oneHour: return "1h"
        case .threeHours: return "3h"
        case .untilAgentsSettle: return "Agents"
        case .custom(let value): return "\(max(value, 1))m"
        }
    }
}

extension DurationOption: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        switch raw {
        case "indefinite": self = .indefinite
        case "oneHour": self = .oneHour
        case "threeHours": self = .threeHours
        case "untilAgentsSettle": self = .untilAgentsSettle
        default:
            let prefix = "custom:"
            guard raw.hasPrefix(prefix), let parsed = Int(raw.dropFirst(prefix.count)) else {
                throw DecodingError.dataCorruptedError(
                    in: container,
                    debugDescription: "Unknown duration \(raw)"
                )
            }
            self = .customMinutes(parsed)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .indefinite: try container.encode("indefinite")
        case .oneHour: try container.encode("oneHour")
        case .threeHours: try container.encode("threeHours")
        case .untilAgentsSettle: try container.encode("untilAgentsSettle")
        case .custom(let minutes): try container.encode("custom:\(max(minutes, 1))")
        }
    }
}
