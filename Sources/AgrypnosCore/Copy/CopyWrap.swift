public enum PopoverCopyLayout: Sendable {
    /// Inner label width in the popover (~272pt at 12pt). Conservative glyph budget.
    public static let innerColumns = 36
    /// Lines a 12pt help text wraps to across the card's inner width. Tests and Linux use the
    /// conservative column estimate; the app installs real AppKit measurement at launch so
    /// each card fits its text with no blank band.
    nonisolated(unsafe) public static var measureLines: (String) -> Int = {
        max(CopyWrap.lineCount($0, columns: innerColumns), 1)
    }
    public static func lines(_ text: String) -> Int { measureLines(text) }
    /// The longest How long hint any duration, Keep awake state, or thermal setting can show.
    public static var durationHintMaxLines: Int {
        var hints: [String] = []
        for option in [DurationOption.indefinite, .oneHour, .untilAgentsSettle] {
            for engaged in [false, true] {
                for thermal in [false, true] {
                    hints.append(AgrypnosCopy.durationHint(
                        option: option, engaged: engaged, remainingSeconds: nil, thermalAutoOff: thermal))
                }
            }
        }
        return hints.map(lines).max() ?? 1
    }
    /// A running timer shows its hint plus the countdown row.
    public static var timedHintLines: Int {
        lines(AgrypnosCopy.durationHint(option: .oneHour, engaged: true, remainingSeconds: nil))
    }
    /// Leftover + “battery” wraps to 4 lines at the conservative column budget.
    public static let captionMaxLines = 4
    public static let helpMaxLines = 2
    public static var settleHelpMaxLines: Int { lines(AgrypnosCopy.settleGraceHelp) }
    public static var countTerminalSessionsHelpMaxLines: Int { lines(AgrypnosCopy.countTerminalSessionsHelp) }
    public static var autoArmHelpMaxLines: Int { lines(AgrypnosCopy.autoArmHelp) }
    public static var autoArmHelpHeightPoints: Int { autoArmHelpMaxLines * lineHeightPoints }
    public static let hotkeyHintMaxLines = 2
    public static let lastWatchEndMaxLines = 3
    public static var lastWatchEndHeightPoints: Int { lastWatchEndMaxLines * lineHeightPoints }
    public static let lineHeightPoints = 16
    public static var durationHintHeightPoints: Int { durationHintMaxLines * lineHeightPoints }
    public static let captionHeightPoints = captionMaxLines * lineHeightPoints
    public static let helpHeightPoints = helpMaxLines * lineHeightPoints
    public static var settleHelpHeightPoints: Int { settleHelpMaxLines * lineHeightPoints }
    public static var countTerminalSessionsHelpHeightPoints: Int {
        countTerminalSessionsHelpMaxLines * lineHeightPoints
    }
    public static var notifEnableHelpMaxLines: Int { lines(AgrypnosCopy.notifEnabledHelp) }
    public static var notifTelegramHelpMaxLines: Int { lines(AgrypnosCopy.notifTelegramHelp) }
    public static let notifTelegramInboundHelpMaxLines = 3
    public static let notifDiscordInboundHelpMaxLines = 4
    public static var notifDiscordHelpMaxLines: Int { lines(AgrypnosCopy.notifDiscordHelp) }
    public static var notifEnableHelpHeightPoints: Int { notifEnableHelpMaxLines * lineHeightPoints }
    public static var notifTelegramHelpHeightPoints: Int { notifTelegramHelpMaxLines * lineHeightPoints }
    public static let notifTelegramInboundHelpHeightPoints = notifTelegramInboundHelpMaxLines * lineHeightPoints
    public static let notifDiscordInboundHelpHeightPoints = notifDiscordInboundHelpMaxLines * lineHeightPoints
    public static var notifDiscordHelpHeightPoints: Int { notifDiscordHelpMaxLines * lineHeightPoints }
    public static let hotkeyHintHeightPoints = hotkeyHintMaxLines * lineHeightPoints
    /// Dim and sleep captions share this slot, sized for the taller one.
    public static var panelPowerCaptionMaxLines: Int {
        max(lines(PanelPowerChrome.caption(.floor)), lines(PanelPowerChrome.caption(.displaySleep)))
    }
    public static let panelPowerHelpMaxLines = 5
    public static var panelPowerCaptionHeightPoints: Int { panelPowerCaptionMaxLines * lineHeightPoints }
    public static var panelPowerHelpHeightPoints: Int { panelPowerHelpMaxLines * lineHeightPoints }
    /// Custom-minutes field. The "Minutes" label is wider so it does not share this slot.
    public static let minutesFieldWidthPoints = 56
    /// Right-aligned on the How long row, extending left into the gap past the 56pt field.
    public static let minutesLabelWidthPoints = 80
    public static let percentValueWidthPoints = 54
    /// "Channel" at 13pt — the widest short caption beside a Notif secret field.
    public static let secretFieldLabelWidthPoints = 80
    /// "1m 30s" at 13pt — wider than a percent so the idle-wait value does not clip.
    public static let timeValueWidthPoints = 72
}

public enum CopyWrap: Sendable {
    public static func lineCount(_ text: String, columns: Int) -> Int {
        guard columns > 0 else { return 0 }
        guard !text.isEmpty else { return 0 }
        var lines = 0
        var remaining = Substring(text)
        while !remaining.isEmpty {
            lines += 1
            if remaining.count <= columns { break }
            let cut = remaining.index(remaining.startIndex, offsetBy: columns)
            if remaining[cut] == " " {
                remaining = remaining[remaining.index(after: cut)...]
                continue
            }
            let prefix = remaining[..<cut]
            if let space = prefix.lastIndex(of: " ") {
                remaining = remaining[remaining.index(after: space)...]
            } else {
                remaining = remaining[cut...]
            }
        }
        return lines
    }
}
