import XCTest
@testable import AgrypnosCore

final class DurationPickerChromeTests: XCTestCase {
    func testMinutesLabelSlotIsWiderThanTheFieldSoMinutesDoesNotClip() {
        XCTAssertEqual(AgrypnosCopy.minutesLabel, "Minutes")
        XCTAssertEqual(PopoverCopyLayout.minutesFieldWidthPoints, 56)
        XCTAssertGreaterThan(
            PopoverCopyLayout.minutesLabelWidthPoints,
            PopoverCopyLayout.minutesFieldWidthPoints
        )
        // 13pt Latin budget (~9pt/glyph) plus cell padding — 56pt was the clip.
        let needed = AgrypnosCopy.minutesLabel.count * 9 + 8
        XCTAssertGreaterThanOrEqual(PopoverCopyLayout.minutesLabelWidthPoints, needed)
    }

    func testCustomMinutesFillsTheFieldAndLeavesPresetsUnselected() {
        let chrome = DurationPickerChrome.make(duration: .customMinutes(33))
        XCTAssertEqual(chrome.segmentTitles, ["∞", "1h", "3h", "Agents"])
        XCTAssertEqual(chrome.segmentTitles, DurationOption.presets.map(\.segmentTitle))
        XCTAssertEqual(chrome.selectedSegment, -1)
        XCTAssertEqual(chrome.minutesText, "33")
        XCTAssertFalse(DurationOption.presets.indices.contains(chrome.selectedSegment))
        XCTAssertEqual(
            DurationPickerChrome.segmentSelection(selectedSegment: chrome.selectedSegment, count: 4),
            [false, false, false, false]
        )
        XCTAssertEqual(
            DurationPickerChrome.exclusiveSelectedIndex(nowOn: [3], previous: 3),
            3
        )
        XCTAssertEqual(
            DurationPickerChrome.exclusiveSelectedIndex(nowOn: [1, 3], previous: 3),
            1
        )
        XCTAssertNil(DurationPickerChrome.exclusiveSelectedIndex(nowOn: [], previous: 3))
    }

    func testPresetAndMinutesCannotBothLookSelected() {
        let agents = DurationPickerChrome.make(duration: .untilAgentsSettle)
        XCTAssertEqual(agents.selectedSegment, 3)
        XCTAssertEqual(agents.minutesText, "")
        XCTAssertEqual(
            DurationPickerChrome.segmentSelection(selectedSegment: agents.selectedSegment, count: 4),
            [false, false, false, true]
        )

        let draft = DurationPickerChrome.make(
            duration: .untilAgentsSettle,
            minutesDraft: "33"
        )
        XCTAssertEqual(draft.selectedSegment, -1)
        XCTAssertEqual(draft.minutesText, "33")
        XCTAssertEqual(
            DurationPickerChrome.segmentSelection(selectedSegment: draft.selectedSegment, count: 4),
            [false, false, false, false]
        )

        // Minutes focus (empty or digits) is the custom option — presets off.
        let focusing = DurationPickerChrome.make(
            duration: .untilAgentsSettle,
            minutesDraft: ""
        )
        XCTAssertEqual(focusing.selectedSegment, -1)
        XCTAssertEqual(focusing.minutesText, "")
        XCTAssertEqual(
            DurationPickerChrome.segmentSelection(selectedSegment: focusing.selectedSegment, count: 4),
            [false, false, false, false]
        )

        // Live typing lives in the field editor; stringValue can still be empty.
        XCTAssertEqual(
            DurationPickerChrome.minutesDraft(isEditing: true, fieldText: "", editorText: "33"),
            "33"
        )
        XCTAssertNil(DurationPickerChrome.minutesDraft(isEditing: false, fieldText: "33", editorText: nil))
    }

    func testPresetSelectionStaysOnTheFourPresets() {
        let idle = DurationPickerChrome.make(duration: .indefinite)
        XCTAssertEqual(idle.segmentTitles, ["∞", "1h", "3h", "Agents"])
        XCTAssertEqual(idle.selectedSegment, 0)
        XCTAssertEqual(idle.minutesText, "")

        let hour = DurationPickerChrome.make(duration: .oneHour)
        XCTAssertEqual(hour.selectedSegment, 1)
        XCTAssertEqual(DurationPickerChrome.make(duration: .threeHours).selectedSegment, 2)
        XCTAssertEqual(DurationPickerChrome.make(duration: .untilAgentsSettle).selectedSegment, 3)
    }

    func testMinutesFieldParsesThirtyThreeAndRejectsJunk() {
        XCTAssertEqual(DurationPickerChrome.parseMinutes("33"), 33)
        XCTAssertEqual(DurationPickerChrome.parseMinutes(" 7 "), 7)
        XCTAssertEqual(DurationPickerChrome.parseMinutes("0"), 1)
        XCTAssertNil(DurationPickerChrome.parseMinutes(""))
        XCTAssertNil(DurationPickerChrome.parseMinutes("  "))
        XCTAssertNil(DurationPickerChrome.parseMinutes("nope"))
        XCTAssertNil(DurationPickerChrome.parseMinutes("3.5"))
    }

    func testSegmentClickMapsToTheFourPresets() {
        XCTAssertEqual(DurationPickerChrome.duration(selectingSegment: 0), .indefinite)
        XCTAssertEqual(DurationPickerChrome.duration(selectingSegment: 3), .untilAgentsSettle)
        XCTAssertNil(DurationPickerChrome.duration(selectingSegment: 4))
        XCTAssertNil(DurationPickerChrome.duration(selectingSegment: 9))
        XCTAssertNil(DurationPickerChrome.duration(selectingSegment: -1))
    }

    func testSameCustomMinutesDoNotCountAsANewCommit() {
        XCTAssertFalse(DurationPickerChrome.shouldCommit(minutes: 33, current: .customMinutes(33)))
        XCTAssertTrue(DurationPickerChrome.shouldCommit(minutes: 40, current: .customMinutes(33)))
        XCTAssertTrue(DurationPickerChrome.shouldCommit(minutes: 33, current: .indefinite))
        XCTAssertTrue(DurationPickerChrome.shouldCommit(minutes: 60, current: .oneHour))
        XCTAssertTrue(DurationPickerChrome.shouldCommit(minutes: 33, current: .untilAgentsSettle))
    }

    func testLeaveWatchDoesNotReplacePresetsWithLeftoverMinutes() {
        XCTAssertFalse(
            DurationPickerChrome.shouldCommitOnLeaveWatch(minutes: 33, current: .untilAgentsSettle)
        )
        XCTAssertFalse(
            DurationPickerChrome.shouldCommitOnLeaveWatch(minutes: 1, current: .indefinite)
        )
        XCTAssertFalse(
            DurationPickerChrome.shouldCommitOnLeaveWatch(minutes: 60, current: .oneHour)
        )
        XCTAssertFalse(
            DurationPickerChrome.shouldCommitOnLeaveWatch(minutes: 33, current: .customMinutes(33))
        )
        XCTAssertTrue(
            DurationPickerChrome.shouldCommitOnLeaveWatch(minutes: 40, current: .customMinutes(33))
        )
    }

    func testBatterySliderChromeReadsThePreferencesRange() {
        XCTAssertEqual(BatteryFloorChrome.minPercent, UserPreferences.batteryFloorRange.lowerBound)
        XCTAssertEqual(BatteryFloorChrome.maxPercent, UserPreferences.batteryFloorRange.upperBound)
        XCTAssertEqual(BatteryFloorChrome.minLabel, "\(UserPreferences.batteryFloorRange.lowerBound)%")
        XCTAssertEqual(BatteryFloorChrome.maxLabel, "\(UserPreferences.batteryFloorRange.upperBound)%")
        XCTAssertEqual(UserPreferences.batteryFloorRange, 5...100)
    }
}
