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
    }

    func testBatterySliderChromeReadsThePreferencesRange() {
        XCTAssertEqual(BatteryFloorChrome.minPercent, UserPreferences.batteryFloorRange.lowerBound)
        XCTAssertEqual(BatteryFloorChrome.maxPercent, UserPreferences.batteryFloorRange.upperBound)
        XCTAssertEqual(BatteryFloorChrome.minLabel, "\(UserPreferences.batteryFloorRange.lowerBound)%")
        XCTAssertEqual(BatteryFloorChrome.maxLabel, "\(UserPreferences.batteryFloorRange.upperBound)%")
        XCTAssertEqual(UserPreferences.batteryFloorRange, 5...100)
    }
}

final class HotkeyRecorderChromeTests: XCTestCase {
    func testIdleShowsLiveChordAndDoesNotClaimADeadBind() {
        let live = HotkeyRecorderChrome.make(
            liveChord: .defaultToggle,
            registered: true,
            isRecording: false,
            failedAttempt: nil
        )
        XCTAssertEqual(live.buttonTitle, "⌥⌘A")
        XCTAssertEqual(live.hint, "⌥⌘A toggles the watch")
        XCTAssertFalse(live.isRecording)

        let dead = HotkeyRecorderChrome.make(
            liveChord: .defaultToggle,
            registered: false,
            isRecording: false,
            failedAttempt: nil
        )
        XCTAssertEqual(dead.buttonTitle, "⌥⌘A")
        XCTAssertFalse(dead.hint.lowercased().contains("toggles the watch"))
        XCTAssertTrue(dead.hint.lowercased().contains("not registered") || dead.hint.lowercased().contains("isn’t registered"))
    }

    func testFailedRemapKeepsLiveButtonAndShowsTheAttemptHonestly() {
        let attempted = HotkeyChord(keyCode: 1, option: true, command: true)
        let chrome = HotkeyRecorderChrome.make(
            liveChord: .defaultToggle,
            registered: true,
            isRecording: false,
            failedAttempt: attempted
        )
        XCTAssertEqual(chrome.buttonTitle, "⌥⌘A")
        XCTAssertTrue(chrome.hint.contains("⌥⌘S"))
        XCTAssertFalse(chrome.hint.lowercased().contains("toggles the watch"))
        XCTAssertEqual(chrome.hint, AgrypnosCopy.hotkeyHint(attempted, registered: false))
    }

    func testFailedPlanAlwaysRebindsPreviousAndUsesHotkeyHintRegisteredFalse() {
        let previous = HotkeyChord.defaultToggle
        let naked = HotkeyChord(keyCode: 0, option: false, command: false)
        let nakedPlan = HotkeyRemapPlan.make(
            attempted: naked,
            previous: previous,
            osRegistered: false
        )
        XCTAssertFalse(nakedPlan.persist)
        XCTAssertEqual(nakedPlan.chordToRegister, previous)
        XCTAssertEqual(nakedPlan.failedAttempt, naked)
        XCTAssertEqual(nakedPlan.hint, AgrypnosCopy.hotkeyHint(naked, registered: false))

        let taken = HotkeyChord(keyCode: 1, option: true, command: true)
        let osFail = HotkeyRemapPlan.make(
            attempted: taken,
            previous: previous,
            osRegistered: false
        )
        XCTAssertFalse(osFail.persist)
        XCTAssertEqual(osFail.chordToRegister, previous)
        XCTAssertEqual(osFail.failedAttempt, taken)
        XCTAssertEqual(osFail.hint, AgrypnosCopy.hotkeyHint(taken, registered: false))

        let ok = HotkeyRemapPlan.make(
            attempted: taken,
            previous: previous,
            osRegistered: true
        )
        XCTAssertTrue(ok.persist)
        XCTAssertEqual(ok.chordToRegister, taken)
        XCTAssertNil(ok.failedAttempt)
        XCTAssertNil(ok.hint)
    }

    func testRecordingCopyAsksForAChord() {
        let chrome = HotkeyRecorderChrome.make(
            liveChord: .defaultToggle,
            registered: true,
            isRecording: true,
            failedAttempt: HotkeyChord(keyCode: 1, option: true, command: true)
        )
        XCTAssertEqual(chrome.buttonTitle, AgrypnosCopy.hotkeyRecording)
        XCTAssertEqual(chrome.hint, AgrypnosCopy.hotkeyRecordingHint)
        XCTAssertTrue(chrome.isRecording)
        XCTAssertFalse(chrome.hint.lowercased().contains("toggles the watch"))
        XCTAssertFalse(chrome.hint.lowercased().contains("watt"))
        XCTAssertFalse(chrome.hint.lowercased().contains("display asleep"))
    }

    func testCaptureBuildsAChordIgnoresModifiersAndCancelsOnEscape() {
        XCTAssertEqual(
            HotkeyCapture.from(keyCode: 0, option: true, command: true, shift: false, control: false),
            .chord(.defaultToggle)
        )
        XCTAssertEqual(
            HotkeyCapture.from(keyCode: 53, option: true, command: true, shift: false, control: false),
            .cancel
        )
        XCTAssertEqual(
            HotkeyCapture.from(keyCode: 55, option: false, command: true, shift: false, control: false),
            .ignore
        )
        if case .chord(let chord) = HotkeyCapture.from(
            keyCode: 1,
            option: true,
            command: true,
            shift: false,
            control: false
        ) {
            XCTAssertEqual(chord.display, "⌥⌘S")
            XCTAssertTrue(chord.isBindable)
        } else {
            XCTFail("expected a chord")
        }
        if case .chord(let naked) = HotkeyCapture.from(
            keyCode: 0,
            option: false,
            command: false,
            shift: false,
            control: false
        ) {
            XCTAssertFalse(naked.isBindable)
        } else {
            XCTFail("naked key should still capture so bind failure can be shown")
        }
        XCTAssertEqual(
            HotkeyCapture.from(keyCode: 57, option: false, command: false, shift: false, control: false),
            .ignore
        )
    }

    func testCapturedChordsDoNotDisplayQuestionMark() {
        for code in UInt32(0)...UInt32(127) {
            switch HotkeyCapture.from(
                keyCode: code,
                option: true,
                command: true,
                shift: false,
                control: false
            ) {
            case .ignore, .cancel:
                continue
            case .chord(let chord):
                XCTAssertFalse(
                    chord.display.contains("?"),
                    "keyCode \(code) displayed \(chord.display)"
                )
            }
        }
    }
}
