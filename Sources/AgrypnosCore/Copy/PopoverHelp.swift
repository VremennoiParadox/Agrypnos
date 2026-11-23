/// Collapsible help (human decision 2026-11-07). Collapsed, a card shows one short plain line that
/// says what the control does; its chevron swaps in the full help. VoiceOver always reads the full help.
public enum PopoverHelp {
    public static let cards: Set<PopoverCard> = [
        .duration, .autoArm, .settle, .terminalBusy, .notifEnable, .notifDiscord, .notifTelegram,
    ]
    /// Room for the chevron at the end of the help text.
    public static let chevronWidthPoints = 20
    public static var textWidthPoints: Int { PopoverCopyLayout.innerWidthPoints - chevronWidthPoints }

    public static func lines(_ text: String) -> Int { PopoverCopyLayout.lines(text, width: textWidthPoints) }

    public static func durationShort(_ option: DurationOption) -> String {
        switch option {
        case .indefinite: return "Stays on until you turn it off."
        case .untilAgentsSettle: return "Turns off when the wait after agent signals stop ends."
        case .oneHour, .threeHours, .custom: return "Turns off when the timer ends."
        }
    }

    public static func short(_ card: PopoverCard) -> String {
        switch card {
        case .autoArm: return "Turns Keep awake on when selected tools look busy for 30 seconds."
        case .settle: return "How long Keep awake waits after local busy signals stop."
        case .terminalBusy: return "Count a terminal an agent is running as busy."
        case .notifEnable: return "Message your bot when the timer or the idle wait ends."
        case .notifDiscord: return "Your own Discord bot: token, channel id, and your user id."
        case .notifTelegram: return "Your own Telegram bot: token, chat id, and your user id."
        default: return ""
        }
    }

    public static func full(_ card: PopoverCard) -> String {
        switch card {
        case .autoArm: return AgrypnosCopy.autoArmHelp
        case .settle: return AgrypnosCopy.settleGraceHelp
        case .terminalBusy: return AgrypnosCopy.countTerminalSessionsHelp
        case .notifEnable: return AgrypnosCopy.notifEnabledHelp
        case .notifDiscord: return AgrypnosCopy.notifDiscordHelp
        case .notifTelegram: return AgrypnosCopy.notifTelegramHelp
        default: return ""
        }
    }

    /// How long's text depends on the duration, so the app builds it from `durationShort` or `durationHint`.
    public static func text(_ card: PopoverCard, expanded: Bool) -> String {
        expanded ? full(card) : short(card)
    }

    /// Help block height. How long reserves the longest text any duration can show.
    public static func height(_ card: PopoverCard, expanded: Bool) -> Int {
        let lineCount: Int
        if card == .duration {
            lineCount = expanded
                ? PopoverCopyLayout.durationHintMaxLines
                : DurationOption.presets.map { lines(durationShort($0)) }.max() ?? 1
        } else {
            lineCount = lines(text(card, expanded: expanded))
        }
        return lineCount * PopoverCopyLayout.lineHeightPoints
    }
}
