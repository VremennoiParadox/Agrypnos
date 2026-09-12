public enum DurationOption: String, Codable, CaseIterable, Sendable, Equatable {
    case indefinite
    case oneHour
    case threeHours
    case untilAgentsSettle

    public var minutes: Int? {
        switch self {
        case .indefinite, .untilAgentsSettle: return nil
        case .oneHour: return 60
        case .threeHours: return 180
        }
    }

    public var segmentTitle: String {
        switch self {
        case .indefinite: return "∞"
        case .oneHour: return "1h"
        case .threeHours: return "3h"
        case .untilAgentsSettle: return "Agents"
        }
    }
}
