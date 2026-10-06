public enum PopoverCard: Equatable, Hashable, Sendable {
    case watch
    case duration
    case lastWatchEnd
    case panelPower
    case hygiene
    case battery
    case agentInclude
    case settle
    case terminalBusy
    case ramp
    case thermal
    case login
    case notifEnable
    case notifDiscord
    case notifDiscordInbound
    case notifTelegram
    case notifTelegramInbound
    case questionRelay
    case pluginConnection
    case claudeHook
    case openCodeQuestions
    case questionForwardingBack
    case questionNotifications
    case codexAlert
    case cursorQuestionNote
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

    public var cards: [PopoverCard] { cards() }

    public func cards(showQuestionNotifications: Bool = false) -> [PopoverCard] {
        switch self {
        case .watch: return [.watch, .duration, .lastWatchEnd]
        case .power: return [.panelPower, .hygiene, .battery, .ramp, .thermal]
        case .agents:
            return [.agentInclude, .settle, .terminalBusy]
        case .notif:
            var cards: [PopoverCard] = [
                .notifSetup,
                .notifEnable, .notifDiscord, .notifDiscordInbound, .notifTelegram, .notifTelegramInbound,
                .questionNotifications,
            ]
            if showQuestionNotifications {
                cards += [.questionRelay, .pluginConnection, .claudeHook, .codexAlert, .cursorQuestionNote]
            }
            cards.append(.notifClear)
            return cards
        case .general: return [.login]
        }
    }
}
