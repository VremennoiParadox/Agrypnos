public struct DurationPickerChrome: Equatable, Sendable {
    public static let customSegmentIndex = 4

    public var segmentTitles: [String]
    public var selectedSegment: Int
    public var minutesText: String
    public var customSelected: Bool

    public init(
        segmentTitles: [String],
        selectedSegment: Int,
        minutesText: String,
        customSelected: Bool
    ) {
        self.segmentTitles = segmentTitles
        self.selectedSegment = selectedSegment
        self.minutesText = minutesText
        self.customSelected = customSelected
    }

    public static func make(duration: DurationOption) -> DurationPickerChrome {
        var titles = DurationOption.presets.map(\.segmentTitle)
        switch duration {
        case .custom(let minutes):
            let value = max(minutes, 1)
            titles.append("\(value)m")
            return DurationPickerChrome(
                segmentTitles: titles,
                selectedSegment: customSegmentIndex,
                minutesText: "\(value)",
                customSelected: true
            )
        default:
            titles.append(AgrypnosCopy.minutesSegmentIdle)
            let index = DurationOption.presets.firstIndex(of: duration) ?? 0
            return DurationPickerChrome(
                segmentTitles: titles,
                selectedSegment: index,
                minutesText: "",
                customSelected: false
            )
        }
    }

    public static func parseMinutes(_ text: String) -> Int? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let value = Int(trimmed) else { return nil }
        return DurationOption.customMinutes(value).minutes
    }

    public static func duration(selectingSegment index: Int, minutesText: String) -> DurationOption? {
        if DurationOption.presets.indices.contains(index) {
            return DurationOption.presets[index]
        }
        if index == customSegmentIndex, let minutes = parseMinutes(minutesText) {
            return .customMinutes(minutes)
        }
        return nil
    }
}
