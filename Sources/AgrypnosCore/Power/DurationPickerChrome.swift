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

    public static func segmentSelection(selectedSegment: Int, count: Int) -> [Bool] {
        (0..<count).map { $0 == selectedSegment }
    }

    public static func exclusiveSelectedIndex(nowOn: [Int], previous: Int) -> Int? {
        if nowOn.count == 1 { return nowOn[0] }
        if nowOn.count > 1 { return nowOn.first { $0 != previous } ?? nowOn[0] }
        return nil
    }

    public static func make(
        duration: DurationOption,
        minutesDraft: String? = nil
    ) -> DurationPickerChrome {
        let titles = DurationOption.presets.map(\.segmentTitle)
        if let draft = minutesDraft {
            if let minutes = parseMinutes(draft) {
                return DurationPickerChrome(
                    segmentTitles: titles,
                    selectedSegment: -1,
                    minutesText: "\(minutes)"
                )
            }
            return DurationPickerChrome(
                segmentTitles: titles,
                selectedSegment: -1,
                minutesText: draft
            )
        }
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

    /// Leaving Watch must not turn leftover Minutes digits into a custom duration
    /// over a preset (including Agents). Enter in the minutes field still commits.
    public static func shouldCommitOnLeaveWatch(minutes: Int, current: DurationOption) -> Bool {
        if case .custom = current {
            return shouldCommit(minutes: minutes, current: current)
        }
        return false
    }
}
