public enum PopoverCopyLayout: Sendable {
    /// Inner label width in the popover (~272pt at 12pt). Conservative glyph budget.
    public static let innerColumns = 36
    public static let durationHintMaxLines = 3
    public static let captionMaxLines = 3
    public static let lineHeightPoints = 16
    public static let durationHintHeightPoints = 48
    public static let captionHeightPoints = 48
    /// Custom-minutes field. The "Minutes" label is wider so it does not share this slot.
    public static let minutesFieldWidthPoints = 56
    /// Right-aligned on the How long row, extending left into the gap past the 56pt field.
    public static let minutesLabelWidthPoints = 80
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
