public enum PopoverCopyLayout: Sendable {
    /// Inner label width in the popover (~272pt at 12pt). Conservative glyph budget.
    public static let innerColumns = 36
    public static let durationHintMaxLines = 3
    /// Leftover + “battery” wraps to 4 lines at the conservative column budget.
    public static let captionMaxLines = 4
    public static let helpMaxLines = 2
    /// `AgrypnosCopy.settleGraceHelp` wraps to 8 lines at `innerColumns`. Power/Watch help stays at 2.
    public static let settleHelpMaxLines = 8
    public static let hotkeyHintMaxLines = 2
    public static let lineHeightPoints = 16
    public static let durationHintHeightPoints = 48
    public static let captionHeightPoints = captionMaxLines * lineHeightPoints
    public static let helpHeightPoints = helpMaxLines * lineHeightPoints
    public static let settleHelpHeightPoints = settleHelpMaxLines * lineHeightPoints
    /// `AgrypnosCopy.notifSetupHelp` wraps to 17 lines at `innerColumns`. Enable 4, Telegram 3.
    public static let notifEnableHelpMaxLines = 4
    public static let notifTelegramHelpMaxLines = 3
    public static let notifSetupHelpMaxLines = 17
    public static let notifDiscordStatusMaxLines = 2
    public static let notifEnableHelpHeightPoints = notifEnableHelpMaxLines * lineHeightPoints
    public static let notifTelegramHelpHeightPoints = notifTelegramHelpMaxLines * lineHeightPoints
    public static let notifSetupHelpHeightPoints = notifSetupHelpMaxLines * lineHeightPoints
    public static let notifDiscordStatusHeightPoints = notifDiscordStatusMaxLines * lineHeightPoints
    public static let hotkeyHintHeightPoints = hotkeyHintMaxLines * lineHeightPoints
    /// Custom-minutes field. The "Minutes" label is wider so it does not share this slot.
    public static let minutesFieldWidthPoints = 56
    /// Right-aligned on the How long row, extending left into the gap past the 56pt field.
    public static let minutesLabelWidthPoints = 80
    public static let percentValueWidthPoints = 54
    /// "Chat id" at 13pt — token/chat labels beside the Notif secret fields.
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
