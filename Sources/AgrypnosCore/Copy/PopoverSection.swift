public enum PopoverCard: Equatable, Hashable, Sendable {
    case watch
    case duration
    case lastWatchEnd
    case hygiene
    case battery
    case agentInclude
    case settle
    case ramp
    case thermal
    case login
    case notifEnable
    case notifDiscord
    case notifTelegram
    case notifSetup
    case notifClear
}

public enum PopoverSection: Int, CaseIterable, Sendable {
    case watch
    case power
    case agents
    case notif
    case general

    public static let `default` = PopoverSection.watch

    public var title: String {
        switch self {
        case .watch: return "Watch"
        case .power: return "Power"
        case .agents: return "Agents"
        case .notif: return "Notif"
        case .general: return "General"
        }
    }

    public static var titles: [String] { allCases.map(\.title) }

    public var cards: [PopoverCard] {
        switch self {
        case .watch: return [.watch, .duration, .lastWatchEnd]
        case .power: return [.hygiene, .battery, .ramp, .thermal]
        case .agents: return [.agentInclude, .settle]
        case .notif: return [.notifEnable, .notifDiscord, .notifTelegram, .notifSetup, .notifClear]
        case .general: return [.login]
        }
    }
}
