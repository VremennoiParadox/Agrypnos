public struct DurationPickerChrome: Equatable, Sendable {
    public var segmentTitles: [String]
    public var selectedSegment: Int
    public var minutesText: String

    public init(
        segmentTitles: [String],
        selectedSegment: Int,
        minutesText: String
    ) {
        self.segmentTitles = segmentTitles
        self.selectedSegment = selectedSegment
        self.minutesText = minutesText
    }

    public static func make(duration: DurationOption) -> DurationPickerChrome {
        let titles = DurationOption.presets.map(\.segmentTitle)
        switch duration {
        case .custom(let minutes):
            let value = max(minutes, 1)
            return DurationPickerChrome(
                segmentTitles: titles,
                selectedSegment: -1,
                minutesText: "\(value)"
            )
        default:
            let index = DurationOption.presets.firstIndex(of: duration) ?? 0
            return DurationPickerChrome(
                segmentTitles: titles,
                selectedSegment: index,
                minutesText: ""
            )
        }
    }

    public static func parseMinutes(_ text: String) -> Int? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let value = Int(trimmed) else { return nil }
        return DurationOption.customMinutes(value).minutes
    }

    public static func duration(selectingSegment index: Int) -> DurationOption? {
        guard DurationOption.presets.indices.contains(index) else { return nil }
        return DurationOption.presets[index]
    }

    public static func shouldCommit(minutes: Int, current: DurationOption) -> Bool {
        current != .customMinutes(minutes)
    }
}
