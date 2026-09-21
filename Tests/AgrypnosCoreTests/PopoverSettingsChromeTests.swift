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

        // Focusing Minutes with no digits must not look like a custom duration.
        // Popover open often focuses that field; empty draft used to unselect Agents.
        let focusing = DurationPickerChrome.make(
            duration: .untilAgentsSettle,
            minutesDraft: ""
        )
        XCTAssertEqual(focusing.selectedSegment, 3)
        XCTAssertEqual(focusing.minutesText, "")
        XCTAssertEqual(
            DurationPickerChrome.segmentSelection(selectedSegment: focusing.selectedSegment, count: 4),
            [false, false, false, true]
        )
        XCTAssertEqual(
            DurationPickerChrome.make(duration: .indefinite, minutesDraft: "  ").selectedSegment,
            0
        )
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

final class PopoverPrefChromeTests: XCTestCase {
    func testBrightnessFloorPercentChromeMatchesPreferencesRange() {
        XCTAssertEqual(
            BrightnessFloorPercentChrome.minPercent,
            UserPreferences.brightnessFloorPercentRange.lowerBound
        )
        XCTAssertEqual(
            BrightnessFloorPercentChrome.maxPercent,
            UserPreferences.brightnessFloorPercentRange.upperBound
        )
        XCTAssertEqual(UserPreferences.brightnessFloorPercentRange, 1...40)
        XCTAssertEqual(UserPreferences.defaultBrightnessFloorPercent, 15)
        XCTAssertEqual(BrightnessFloorPercentChrome.minLabel, "1%")
        XCTAssertEqual(BrightnessFloorPercentChrome.maxLabel, "40%")
        XCTAssertNotEqual(BrightnessFloorPercentChrome.minPercent, 0)
        XCTAssertNotEqual(BrightnessFloorPercentChrome.minLabel, "0%")
    }

    func testSettleGraceChromeMatchesPreferencesRange() {
        XCTAssertEqual(AgentSettleGraceChrome.minSeconds, UserPreferences.agentSettleGraceRange.lowerBound)
        XCTAssertEqual(AgentSettleGraceChrome.maxSeconds, UserPreferences.agentSettleGraceRange.upperBound)
        XCTAssertEqual(UserPreferences.agentSettleGraceRange, 120...900)
        XCTAssertEqual(UserPreferences.defaultAgentSettleGrace, 120)
        XCTAssertEqual(UserPreferences.default.agentSettleGrace, 120)
        XCTAssertEqual(AgentSettleGraceChrome.minLabel, "2m")
        XCTAssertNotEqual(AgentSettleGraceChrome.minLabel, "120s")
        XCTAssertEqual(AgentSettleGraceChrome.maxLabel, "15m")
        XCTAssertEqual(AgentSettleGraceChrome.valueLabel(seconds: 15), "2m")
        XCTAssertEqual(AgentSettleGraceChrome.valueLabel(seconds: 90), "2m")
        XCTAssertEqual(AgentSettleGraceChrome.valueLabel(seconds: 120), "2m")
        XCTAssertEqual(AgentSettleGraceChrome.valueLabel(seconds: 150), "2m 30s")
        XCTAssertEqual(AgentSettleGraceChrome.valueLabel(seconds: 900), "15m")
        XCTAssertEqual(AgentSettleGraceChrome.seconds(sliderValue: 5), 120)
        XCTAssertEqual(AgentSettleGraceChrome.seconds(sliderValue: 90), 120)
        XCTAssertEqual(AgentSettleGraceChrome.seconds(sliderValue: 120), 120)
        XCTAssertEqual(AgentSettleGraceChrome.seconds(sliderValue: 9_999), 900)
    }

    func testLidOpenRampChromeMapsOneTwoThreeSeconds() {
        XCTAssertEqual(LidOpenRampChrome.titles, ["1s", "2s", "3s"])
        XCTAssertEqual(LidOpenRampChrome.options, [1, 2, 3])
        XCTAssertEqual(LidOpenRampChrome.selectedSegment(seconds: 1), 0)
        XCTAssertEqual(LidOpenRampChrome.selectedSegment(seconds: 2), 1)
        XCTAssertEqual(LidOpenRampChrome.selectedSegment(seconds: 3), 2)
        XCTAssertEqual(LidOpenRampChrome.selectedSegment(seconds: 0), 0)
        XCTAssertEqual(LidOpenRampChrome.selectedSegment(seconds: 9), 2)
        XCTAssertEqual(LidOpenRampChrome.seconds(selectingSegment: 0), 1)
        XCTAssertEqual(LidOpenRampChrome.seconds(selectingSegment: 1), 2)
        XCTAssertEqual(LidOpenRampChrome.seconds(selectingSegment: 2), 3)
        XCTAssertNil(LidOpenRampChrome.seconds(selectingSegment: -1))
        XCTAssertNil(LidOpenRampChrome.seconds(selectingSegment: 3))
    }

    func testPrefRowTitlesAreNotJargon() {
        XCTAssertNotEqual(AgrypnosCopy.settleGrace, "Agents settle grace")
        XCTAssertNotEqual(AgrypnosCopy.lidOpenRamp, "Lid-open ramp")
        XCTAssertFalse(AgrypnosCopy.settleGrace.lowercased().contains("settle grace"))
        XCTAssertFalse(AgrypnosCopy.lidOpenRamp.lowercased().contains("lid-open ramp"))
        XCTAssertFalse(AgrypnosCopy.settleGraceHelp.lowercased().contains("settle grace"))
        XCTAssertFalse(AgrypnosCopy.lidOpenRampHelp.lowercased().contains("lid-open ramp"))
    }

    func testThermalAutoOffRowCopyIsPlain() {
        XCTAssertEqual(AgrypnosCopy.thermalAutoOff, "Thermal auto-off")
        XCTAssertEqual(AgrypnosCopy.thermalAutoOffHelp, "Thermal pressure turns the watch off.")
        for text in [AgrypnosCopy.thermalAutoOff, AgrypnosCopy.thermalAutoOffHelp] {
            let lower = text.lowercased()
            XCTAssertFalse(lower.contains("°c"), text)
            XCTAssertFalse(lower.contains("celsius"), text)
            XCTAssertFalse(lower.contains("safe temp"), text)
            XCTAssertFalse(lower.contains("health-gauge"), text)
            XCTAssertFalse(lower.contains("health gauge"), text)
            XCTAssertFalse(lower.contains("warranty"), text)
            XCTAssertFalse(lower.contains("smc"), text)
        }
    }
}

final class PopoverStackLayoutTests: XCTestCase {
    func testCardsStackTopToBottomWithoutOverlap() {
        let watch = PopoverStackLayout.make(section: .watch)
        let power = PopoverStackLayout.make(section: .power)
        let agents = PopoverStackLayout.make(section: .agents)
        let notif = PopoverStackLayout.make(section: .notif)
        let general = PopoverStackLayout.make(section: .general)
        assertStacked(watch.stackedCards, firstY: PopoverStackLayout.firstCardY)
        assertStacked(power.stackedCards, firstY: PopoverStackLayout.firstCardY)
        assertStacked(agents.stackedCards, firstY: PopoverStackLayout.firstCardY)
        assertStacked(notif.stackedCards, firstY: PopoverStackLayout.firstCardY)
        assertStacked(general.stackedCards, firstY: PopoverStackLayout.firstCardY)
        XCTAssertEqual(notif.stackedCards.count, 5)
        XCTAssertEqual(watch.watch?.y, PopoverStackLayout.firstCardY)
        XCTAssertGreaterThanOrEqual(general.shortcutY!, general.login!.maxY)
        XCTAssertGreaterThanOrEqual(general.hotkeyHint!.y, general.shortcutY!)
        XCTAssertGreaterThanOrEqual(general.quitY!, general.hotkeyHint!.maxY)
        XCTAssertEqual(general.contentHeight, general.quitY! + PopoverStackLayout.quitReserve)
        XCTAssertEqual(
            watch.popoverHeight,
            min(watch.contentHeight, PopoverStackLayout.maxVisibleHeight)
        )
        XCTAssertEqual(watch.needsScroll, watch.contentHeight > watch.popoverHeight)
        XCTAssertLessThanOrEqual(watch.popoverHeight, PopoverStackLayout.maxVisibleHeight)
    }

    func testWatchCaptionSlotHoldsLeftoverBatteryWrap() {
        let layout = PopoverStackLayout.make(section: .watch)
        XCTAssertGreaterThanOrEqual(
            PopoverCopyLayout.captionMaxLines,
            CopyWrap.lineCount(
                AgrypnosCopy.leftoverCaption(floor: 100, lidClosed: false),
                columns: PopoverCopyLayout.innerColumns
            )
        )
        XCTAssertGreaterThanOrEqual(
            layout.watch!.height,
            PopoverStackLayout.inset + 28 + PopoverCopyLayout.captionHeightPoints + PopoverStackLayout.inset
        )
        XCTAssertEqual(
            PopoverCopyLayout.captionHeightPoints,
            PopoverCopyLayout.captionMaxLines * PopoverCopyLayout.lineHeightPoints
        )
    }

    func testHygieneSettleAndRampSlotsFitNativeControls() {
        let watch = PopoverStackLayout.make(section: .watch)
        let power = PopoverStackLayout.make(section: .power)
        let agents = PopoverStackLayout.make(section: .agents)
        let general = PopoverStackLayout.make(section: .general)
        XCTAssertGreaterThanOrEqual(
            power.hygiene!.height,
            2 * PopoverStackLayout.switchRowHeight
                + PopoverCopyLayout.helpHeightPoints
                + PopoverStackLayout.sliderBlockHeight
        )
        XCTAssertGreaterThanOrEqual(
            agents.settle!.height,
            PopoverStackLayout.titleRowHeight
                + PopoverCopyLayout.settleHelpHeightPoints
                + PopoverStackLayout.sliderBlockHeight
        )
        XCTAssertGreaterThanOrEqual(
            power.ramp!.height,
            PopoverStackLayout.titleRowHeight
                + PopoverCopyLayout.helpHeightPoints
                + PopoverStackLayout.segmentRowHeight
        )
        XCTAssertEqual(
            power.thermal!.height,
            PopoverStackLayout.inset
                + PopoverStackLayout.titleRowHeight
                + PopoverCopyLayout.helpHeightPoints
                + PopoverStackLayout.switchRowHeight
                + PopoverStackLayout.inset
        )
        XCTAssertEqual(
            power.thermal!.height,
            PopoverStackLayout.prefControlY
                + PopoverStackLayout.switchRowHeight
                + PopoverStackLayout.inset
        )
        XCTAssertEqual(watch.duration!.height, 136)
        XCTAssertEqual(power.battery!.height, 88)
        XCTAssertEqual(general.login!.height, 44)
        XCTAssertEqual(general.hotkeyHint!.height, PopoverCopyLayout.hotkeyHintHeightPoints)
        XCTAssertFalse(watch.needsScroll)
        XCTAssertFalse(power.needsScroll)
        XCTAssertFalse(agents.needsScroll)
        XCTAssertFalse(general.needsScroll)
        XCTAssertEqual(watch.popoverHeight, watch.contentHeight)
        XCTAssertLessThan(watch.contentHeight, PopoverStackLayout.maxVisibleHeight)
    }

    func testLoginSwitchRowCentersTheLabelInTheLoginCard() {
        let layout = PopoverStackLayout.make(section: .general)
        XCTAssertEqual(layout.login!.height, PopoverStackLayout.loginCardHeight)
        let y = PopoverStackLayout.loginSwitchRowY
        let below = PopoverStackLayout.loginCardHeight - y - PopoverStackLayout.switchRowLabelHeight
        XCTAssertEqual(y, below)
    }

    private func assertStacked(_ cards: [PopoverSlot], firstY: Int, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertFalse(cards.isEmpty, file: file, line: line)
        XCTAssertEqual(cards[0].y, firstY, file: file, line: line)
        for (index, card) in cards.enumerated() {
            XCTAssertGreaterThan(card.height, 0, "card \(index)", file: file, line: line)
            if index > 0 {
                XCTAssertEqual(
                    card.y,
                    cards[index - 1].maxY + PopoverStackLayout.cardGap,
                    "card \(index) smashed into the previous card",
                    file: file,
                    line: line
                )
            }
        }
    }

    func testSwitchControlSitsOnTheLabelMidline() {
        XCTAssertEqual(PopoverStackLayout.switchControlY(labelY: 11, switchHeight: 21), 11.5)
        XCTAssertEqual(PopoverStackLayout.switchControlY(labelY: 10, switchHeight: 22), 10)
        XCTAssertEqual(PopoverStackLayout.switchControlY(labelY: 11, switchHeight: 25), 9.5)
    }

    func testSettleHelpNeedsItsOwnSlotAndKeepsOtherHelpAtTwoLines() {
        let settleLines = CopyWrap.lineCount(
            AgrypnosCopy.settleGraceHelp,
            columns: PopoverCopyLayout.innerColumns
        )
        XCTAssertEqual(PopoverCopyLayout.helpMaxLines, 2)
        XCTAssertEqual(PopoverCopyLayout.helpHeightPoints, 2 * PopoverCopyLayout.lineHeightPoints)
        XCTAssertGreaterThan(settleLines, PopoverCopyLayout.helpMaxLines)
        XCTAssertEqual(settleLines, 8)
        XCTAssertEqual(PopoverCopyLayout.settleHelpMaxLines, 8)
        XCTAssertEqual(
            PopoverCopyLayout.settleHelpHeightPoints,
            8 * PopoverCopyLayout.lineHeightPoints
        )
        XCTAssertGreaterThanOrEqual(
            PopoverCopyLayout.settleHelpHeightPoints,
            settleLines * PopoverCopyLayout.lineHeightPoints
        )
        XCTAssertLessThanOrEqual(
            CopyWrap.lineCount(
                AgrypnosCopy.brightnessFloorHelp,
                columns: PopoverCopyLayout.innerColumns
            ),
            PopoverCopyLayout.helpMaxLines
        )
        XCTAssertLessThanOrEqual(
            CopyWrap.lineCount(
                AgrypnosCopy.lidOpenRampHelp,
                columns: PopoverCopyLayout.innerColumns
            ),
            PopoverCopyLayout.helpMaxLines
        )
        XCTAssertLessThanOrEqual(
            CopyWrap.lineCount(
                AgrypnosCopy.thermalAutoOffHelp,
                columns: PopoverCopyLayout.innerColumns
            ),
            PopoverCopyLayout.helpMaxLines
        )
        XCTAssertEqual(AgentSettleGraceChrome.minLabel, "2m")
        XCTAssertNotEqual(AgentSettleGraceChrome.minLabel, "15s")
        XCTAssertEqual(AgentSettleGraceChrome.maxLabel, "15m")
    }

    func testSettleCardGrowsWithSettleHelpAndLeavesRampThermalOnTheTwoLineSlot() {
        let agents = PopoverStackLayout.make(section: .agents)
        let power = PopoverStackLayout.make(section: .power)
        XCTAssertEqual(
            agents.settle!.height,
            PopoverStackLayout.inset
                + PopoverStackLayout.titleRowHeight
                + PopoverCopyLayout.settleHelpHeightPoints
                + PopoverStackLayout.sliderBlockHeight
                + PopoverStackLayout.inset
        )
        XCTAssertGreaterThan(
            PopoverCopyLayout.settleHelpHeightPoints,
            PopoverCopyLayout.helpHeightPoints
        )
        XCTAssertEqual(
            PopoverStackLayout.settleControlY,
            PopoverStackLayout.prefHelpY + PopoverCopyLayout.settleHelpHeightPoints
        )
        XCTAssertEqual(
            PopoverStackLayout.settleMinMaxY,
            PopoverStackLayout.settleControlY + 24
        )
        XCTAssertGreaterThan(
            PopoverStackLayout.settleControlY,
            PopoverStackLayout.prefControlY
        )
        XCTAssertEqual(
            PopoverStackLayout.prefControlY,
            PopoverStackLayout.prefHelpY + PopoverCopyLayout.helpHeightPoints
        )
        XCTAssertEqual(
            power.ramp!.height,
            PopoverStackLayout.inset
                + PopoverStackLayout.titleRowHeight
                + PopoverCopyLayout.helpHeightPoints
                + PopoverStackLayout.segmentRowHeight
                + PopoverStackLayout.inset
        )
        XCTAssertEqual(
            power.thermal!.height,
            PopoverStackLayout.inset
                + PopoverStackLayout.titleRowHeight
                + PopoverCopyLayout.helpHeightPoints
                + PopoverStackLayout.switchRowHeight
                + PopoverStackLayout.inset
        )
        XCTAssertFalse(agents.needsScroll)
        XCTAssertLessThan(agents.contentHeight, PopoverStackLayout.maxVisibleHeight)
    }

    func testTimeValueSlotFitsOneMinuteThirty() {
        let needed = "1m 30s".count * 9 + 8
        XCTAssertGreaterThan(
            PopoverCopyLayout.timeValueWidthPoints,
            PopoverCopyLayout.percentValueWidthPoints
        )
        XCTAssertGreaterThanOrEqual(PopoverCopyLayout.timeValueWidthPoints, needed)
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
