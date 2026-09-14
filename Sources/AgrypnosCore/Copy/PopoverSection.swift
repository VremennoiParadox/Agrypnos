public enum PopoverCard: Equatable, Hashable, Sendable {
    case watch
    case duration
    case hygiene
    case battery
    case settle
    case ramp
    case login
}

public enum PopoverSection: Int, CaseIterable, Sendable {
    case watch
    case power
    case agents
    case general

    public static let `default` = PopoverSection.watch

    public var title: String {
        switch self {
        case .watch: return "Watch"
        case .power: return "Power"
        case .agents: return "Agents"
        case .general: return "General"
        }
    }

    public static var titles: [String] { allCases.map(\.title) }

    public var cards: [PopoverCard] {
        switch self {
        case .watch: return [.watch, .duration]
        case .power: return [.hygiene, .battery, .ramp]
        case .agents: return [.settle]
        case .general: return [.login]
        }
    }
}
