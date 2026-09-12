import XCTest
@testable import AgrypnosCore

final class DurationOptionTests: XCTestCase {
    func testSegmentTitlesAndMinutes() {
        XCTAssertEqual(DurationOption.indefinite.segmentTitle, "∞")
        XCTAssertEqual(DurationOption.oneHour.minutes, 60)
        XCTAssertEqual(DurationOption.threeHours.minutes, 180)
        XCTAssertNil(DurationOption.untilAgentsSettle.minutes)
        XCTAssertEqual(DurationOption.presets.count, 4)
    }
}

final class HotkeyChordTests: XCTestCase {
    func testDefaultDisplayAndCarbonBits() {
        let chord = HotkeyChord.defaultToggle
        XCTAssertEqual(chord.display, "⌥⌘A")
        XCTAssertEqual(chord.keyCode, 0)
        XCTAssertEqual(chord.carbonModifiers, (1 << 11) | (1 << 8))
    }

    func testRecorderKeysThatUsedToBeQuestionMarkHaveLabels() {
        let expected: [(UInt32, String)] = [
            (24, "="), (27, "-"), (30, "]"), (33, "["),
            (36, "Return"), (39, "'"), (41, ";"), (42, "\\"),
            (43, ","), (44, "/"), (47, "."), (48, "Tab"),
            (50, "`"), (51, "Delete"),
            (122, "F1"), (123, "←"), (124, "→"), (125, "↓"), (126, "↑"),
        ]
        for (code, label) in expected {
            XCTAssertEqual(HotkeyChord.keyLabel(code), label, "keyCode \(code)")
            let chord = HotkeyChord(keyCode: code, option: true, command: true)
            XCTAssertTrue(chord.display.hasSuffix(label), chord.display)
            XCTAssertFalse(chord.display.contains("?"))
        }
    }
}

final class AgrypnosCopyTests: XCTestCase {
    func testWedgeLanguageDoesNotClaimWattsOrForcedDisplaySleep() {
        let caption = AgrypnosCopy.captionPrepared(floor: 15)
        XCTAssertFalse(caption.lowercased().contains("watt"))
        XCTAssertFalse(caption.lowercased().contains("1.76"))
        XCTAssertTrue(AgrypnosCopy.agentsHint.lowercased().contains("busy"))
        XCTAssertEqual(AgrypnosCopy.quit, "Quit Agrypnos")
        XCTAssertEqual(AgrypnosCopy.hotkeyHint(.defaultToggle), "⌥⌘A toggles the watch")
    }

    func testCoreCopySurfaceDoesNotClaimForcedDisplaySleep() {
        assertNoDisplaySleepFiction(allUserFacingCopy().joined(separator: "\n"))
    }

    func testUserFacingCopyHasNoBannedPoetry() {
        let blob = allUserFacingCopy().joined(separator: "\n").lowercased()
        let banned = [
            "kill the keys",
            "floor the panel",
            "sleeps with you",
            "stands down",
            "watch down.",
            "safety nets",
            "sleep may return",
            "busy stays awake",
        ]
        for phrase in banned {
            XCTAssertFalse(blob.contains(phrase), "banned phrase still in copy: \(phrase)")
        }
    }

    func testArmedCaptionWaitsForLidThenFloorAndKeyboard() {
        let caption = AgrypnosCopy.captionPrepared(floor: 15)
        let lower = caption.lowercased()
        XCTAssertEqual(
            caption,
            "Armed. Waiting for lid close — then brightness floor, keyboard backlight off. Auto-off at 15% battery."
        )
        XCTAssertTrue(lower.contains("armed"))
        XCTAssertTrue(lower.contains("waiting"))
        XCTAssertTrue(lower.contains("lid close"))
        XCTAssertTrue(lower.contains("then"))
        XCTAssertTrue(lower.contains("brightness floor"))
        XCTAssertTrue(lower.contains("keyboard backlight"))
        XCTAssertFalse(lower.contains("prepared"))
        assertFitsCaption(caption)
        assertFitsCaption(AgrypnosCopy.captionPrepared(floor: 100))
        assertNoDisplaySleepFiction(caption)
    }

    func testLidClosedCaptionIsFloorAndKeyboardNotDisplaySleep() {
        let caption = AgrypnosCopy.captionLidClosed(floor: 15)
        let lower = caption.lowercased()
        XCTAssertEqual(
            caption,
            "Lid closed. Brightness floor + keyboard backlight off. Auto-off at 15% battery."
        )
        XCTAssertTrue(lower.contains("lid closed"))
        XCTAssertTrue(lower.contains("brightness floor"))
        XCTAssertTrue(lower.contains("keyboard backlight"))
        XCTAssertFalse(lower.contains("waiting"))
        assertFitsCaption(caption)
        assertFitsCaption(AgrypnosCopy.captionLidClosed(floor: 100))
        assertNoDisplaySleepFiction(caption)
    }

    func testOffCaptionIsPlainKeepAwakeWithLidClosed() {
        XCTAssertEqual(AgrypnosCopy.captionOff, "Keeps the Mac awake with the lid closed.")
        assertFitsCaption(AgrypnosCopy.captionOff)
    }

    func testWatchCaptionUsesLidOpenPreparedAndLidClosedHolding() {
        XCTAssertEqual(
            AgrypnosCopy.watchCaption(engaged: true, leftover: false, floor: 15, lidClosed: false),
            AgrypnosCopy.captionPrepared(floor: 15)
        )
        XCTAssertEqual(
            AgrypnosCopy.watchCaption(engaged: true, leftover: false, floor: 15, lidClosed: true),
            AgrypnosCopy.captionLidClosed(floor: 15)
        )
        XCTAssertEqual(
            AgrypnosCopy.watchCaption(engaged: false, leftover: false, floor: 15, lidClosed: true),
            AgrypnosCopy.captionOff
        )
    }

    func testMenuTooltipWaitsForLidWhileArmedOpen() {
        XCTAssertEqual(AgrypnosCopy.menuTooltipOff, "Agrypnos: watch is off.")
        XCTAssertEqual(
            AgrypnosCopy.menuTooltip(engaged: true, leftover: false, onBattery: false, lidClosed: false),
            "Agrypnos: armed. Waiting for lid close — then brightness floor + keyboard backlight off."
        )
        XCTAssertEqual(
            AgrypnosCopy.menuTooltip(engaged: true, leftover: false, onBattery: true, lidClosed: false),
            "Agrypnos: armed. Waiting for lid close — then brightness floor + keyboard backlight off. On battery."
        )
        XCTAssertEqual(
            AgrypnosCopy.menuTooltip(engaged: true, leftover: false, onBattery: false, lidClosed: true),
            "Agrypnos: lid closed. Brightness floor + keyboard backlight off."
        )
        XCTAssertEqual(
            AgrypnosCopy.menuTooltip(engaged: false, leftover: false, onBattery: false, lidClosed: false),
            AgrypnosCopy.menuTooltipOff
        )
        XCTAssertEqual(
            AgrypnosCopy.menuTooltip(engaged: true, leftover: true, onBattery: false, lidClosed: false),
            AgrypnosCopy.menuTooltipLeftover
        )
        XCTAssertEqual(
            AgrypnosCopy.menuTooltipLeftover,
            "Agrypnos: adopted leftover SleepDisabled. Lid close: brightness floor + keyboard backlight off."
        )
    }

    func testDurationHintsArePlainAndFitTheDurationCard() {
        XCTAssertEqual(
            AgrypnosCopy.agentsHint,
            "Stays awake while agents are busy. Allows sleep after they go idle."
        )
        XCTAssertEqual(
            AgrypnosCopy.durationHint(option: .untilAgentsSettle, engaged: true, remainingSeconds: nil),
            AgrypnosCopy.agentsHint
        )
        XCTAssertEqual(
            AgrypnosCopy.durationHint(option: .indefinite, engaged: false, remainingSeconds: nil),
            "Stays on until you turn it off (battery / thermal / Low Power Mode safety still apply)."
        )
        XCTAssertEqual(
            AgrypnosCopy.durationHint(option: .oneHour, engaged: false, remainingSeconds: nil),
            "Runs for the selected time, then turns the watch off."
        )
        XCTAssertEqual(
            AgrypnosCopy.durationHint(option: .threeHours, engaged: false, remainingSeconds: nil),
            AgrypnosCopy.timedHint
        )
        XCTAssertEqual(
            AgrypnosCopy.durationHint(option: .oneHour, engaged: true, remainingSeconds: 125),
            "Auto-off in 2:05"
        )
        assertFitsDurationHint(AgrypnosCopy.agentsHint)
        assertFitsDurationHint(AgrypnosCopy.timedHint)
        assertFitsDurationHint(AgrypnosCopy.indefiniteHint)
        assertFitsDurationHint(
            AgrypnosCopy.durationHint(option: .customMinutes(33), engaged: false, remainingSeconds: nil)
        )
    }

    func testEndedNotificationsArePlainWatchTurnedOff() {
        XCTAssertEqual(AgrypnosCopy.notification(for: .user), "Watch turned off.")
        XCTAssertEqual(AgrypnosCopy.notification(for: .timerExpired), "Timer ended. Watch turned off.")
        XCTAssertEqual(
            AgrypnosCopy.notification(for: .batteryFloor),
            "Battery floor reached. Watch turned off."
        )
        XCTAssertEqual(
            AgrypnosCopy.notification(for: .thermal),
            "Thermal pressure. Watch turned off."
        )
        XCTAssertEqual(AgrypnosCopy.notification(for: .agentsSettled), "Agents idle. Watch turned off.")
        XCTAssertEqual(AgrypnosCopy.notification(for: .lowPowerMode), "Low Power Mode. Watch turned off.")
        XCTAssertEqual(AgrypnosCopy.notification(for: .lowPowerMode), AgrypnosCopy.lpmEnded)
        XCTAssertEqual(AgrypnosCopy.timerEnded, "Timer ended. Watch turned off.")
        XCTAssertEqual(AgrypnosCopy.batteryEnded, "Battery floor reached. Watch turned off.")
        XCTAssertEqual(AgrypnosCopy.thermalEnded, "Thermal pressure. Watch turned off.")
        XCTAssertEqual(AgrypnosCopy.agentsEnded, "Agents idle. Watch turned off.")
    }

    func testLowPowerModeEndedCopyOnlyMatchesWhenEvaluatorWouldDisengage() {
        let lpmDischarging = SafetyInputs(
            batteryPercent: 50,
            onBatteryDischarging: true,
            thermalSerious: false,
            lowPowerMode: true
        )
        XCTAssertNil(
            AutoOffEvaluator.reason(
                engaged: true,
                timerEnd: nil,
                safety: lpmDischarging,
                batteryFloorPercent: 15,
                userForcedThisSession: true
            )
        )
        XCTAssertEqual(
            AutoOffEvaluator.reason(
                engaged: true,
                timerEnd: nil,
                safety: lpmDischarging,
                batteryFloorPercent: 15,
                userForcedThisSession: false
            ),
            .lowPowerMode
        )
        let engagedCaptions = [
            AgrypnosCopy.watchCaption(engaged: true, leftover: false, floor: 15, lidClosed: false),
            AgrypnosCopy.watchCaption(engaged: true, leftover: false, floor: 15, lidClosed: true),
            AgrypnosCopy.watchCaption(engaged: true, leftover: true, floor: 15, lidClosed: false),
            AgrypnosCopy.durationHint(option: .indefinite, engaged: true, remainingSeconds: nil),
            AgrypnosCopy.durationHint(option: .oneHour, engaged: true, remainingSeconds: 125),
        ]
        for caption in engagedCaptions {
            XCTAssertFalse(
                caption.contains("Watch turned off."),
                "engaged copy must not claim ended: \(caption)"
            )
            XCTAssertFalse(caption.lowercased().contains("stands down"))
        }
    }

    func testLeftoverAdoptCopyIsVisibleAndDoesNotClaimWatts() {
        let caption = AgrypnosCopy.leftoverCaption(floor: 15)
        let notify = AgrypnosCopy.leftoverNotify
        XCTAssertEqual(
            caption,
            "Leftover adopted. Lid close — then brightness floor, keyboard backlight off. Auto-off at 15% battery."
        )
        XCTAssertEqual(
            notify,
            "SleepDisabled was already on. Agrypnos adopted it. Lid close still uses brightness floor + keyboard backlight off."
        )
        XCTAssertTrue(caption.lowercased().contains("leftover"))
        XCTAssertTrue(caption.lowercased().contains("adopt"))
        XCTAssertTrue(notify.lowercased().contains("already on"))
        XCTAssertTrue(notify.lowercased().contains("adopt"))
        XCTAssertTrue(notify.lowercased().contains("brightness floor"))
        XCTAssertTrue(notify.lowercased().contains("keyboard"))
        XCTAssertFalse(caption.lowercased().contains("watt"))
        XCTAssertFalse(notify.lowercased().contains("1.76"))
        assertFitsCaption(caption)
        assertFitsCaption(AgrypnosCopy.leftoverCaption(floor: 50))
        assertFitsCaption(AgrypnosCopy.leftoverCaption(floor: 100))
        assertFitsCaption(AgrypnosCopy.captionPrepared(floor: 50))
        XCTAssertEqual(
            AgrypnosCopy.watchCaption(engaged: true, leftover: true, floor: 15, lidClosed: false),
            caption
        )
        XCTAssertEqual(
            AgrypnosCopy.watchCaption(engaged: true, leftover: true, floor: 15, lidClosed: true),
            caption
        )
        XCTAssertEqual(
            AgrypnosCopy.watchCaption(engaged: true, leftover: false, floor: 15, lidClosed: false),
            AgrypnosCopy.captionPrepared(floor: 15)
        )
        XCTAssertEqual(
            AgrypnosCopy.watchCaption(engaged: false, leftover: true, floor: 15, lidClosed: false),
            AgrypnosCopy.captionOff
        )
    }

    func testHotkeyHintDoesNotClaimActiveWhenRegistrationFailed() {
        let failed = AgrypnosCopy.hotkeyHint(.defaultToggle, registered: false)
        XCTAssertTrue(failed.contains("⌥⌘A"))
        XCTAssertFalse(failed.lowercased().contains("toggles the watch"))
        XCTAssertTrue(failed.lowercased().contains("not registered") || failed.lowercased().contains("isn’t registered"))
    }

    private func allUserFacingCopy() -> [String] {
        [
            AgrypnosCopy.appName,
            AgrypnosCopy.keepWatch,
            AgrypnosCopy.durationLabel,
            AgrypnosCopy.minutesLabel,
            AgrypnosCopy.minutesPlaceholder,
            AgrypnosCopy.shortcutLabel,
            AgrypnosCopy.hotkeyRecording,
            AgrypnosCopy.hotkeyRecordingHint,
            AgrypnosCopy.keyboardDark,
            AgrypnosCopy.brightnessFloor,
            AgrypnosCopy.settleGrace,
            AgrypnosCopy.lidOpenRamp,
            AgrypnosCopy.batteryFloor,
            AgrypnosCopy.launchAtLogin,
            AgrypnosCopy.quit,
            AgrypnosCopy.agentsHint,
            AgrypnosCopy.timedHint,
            AgrypnosCopy.indefiniteHint,
            AgrypnosCopy.captionOff,
            AgrypnosCopy.grantNeeded,
            AgrypnosCopy.timerEnded,
            AgrypnosCopy.batteryEnded,
            AgrypnosCopy.thermalEnded,
            AgrypnosCopy.agentsEnded,
            AgrypnosCopy.lpmEnded,
            AgrypnosCopy.leftoverNotify,
            AgrypnosCopy.menuTooltipOff,
            AgrypnosCopy.menuTooltipOn,
            AgrypnosCopy.menuTooltipArmed,
            AgrypnosCopy.menuTooltipLidClosed,
            AgrypnosCopy.menuTooltipLeftover,
            AgrypnosCopy.captionPrepared(floor: 15),
            AgrypnosCopy.captionPrepared(floor: 100),
            AgrypnosCopy.captionLidClosed(floor: 15),
            AgrypnosCopy.captionLidClosed(floor: 100),
            AgrypnosCopy.leftoverCaption(floor: 15),
            AgrypnosCopy.leftoverCaption(floor: 100),
            AgrypnosCopy.hotkeyHint(.defaultToggle, registered: true),
            AgrypnosCopy.hotkeyHint(.defaultToggle, registered: false),
            AgrypnosCopy.hotkeyHint(HotkeyChord(keyCode: 0, option: false, command: false), registered: false),
            AgrypnosCopy.durationHint(option: .untilAgentsSettle, engaged: false, remainingSeconds: nil),
            AgrypnosCopy.durationHint(option: .indefinite, engaged: false, remainingSeconds: nil),
            AgrypnosCopy.durationHint(option: .oneHour, engaged: false, remainingSeconds: nil),
            AgrypnosCopy.durationHint(option: .threeHours, engaged: false, remainingSeconds: nil),
            AgrypnosCopy.durationHint(option: .customMinutes(33), engaged: false, remainingSeconds: nil),
            AgrypnosCopy.durationHint(option: .customMinutes(33), engaged: true, remainingSeconds: 125),
            AgrypnosCopy.notification(for: .user),
            AgrypnosCopy.notification(for: .timerExpired),
            AgrypnosCopy.notification(for: .batteryFloor),
            AgrypnosCopy.notification(for: .thermal),
            AgrypnosCopy.notification(for: .agentsSettled),
            AgrypnosCopy.notification(for: .lowPowerMode),
        ]
    }

    private func assertFitsCaption(_ text: String, file: StaticString = #filePath, line: UInt = #line) {
        let lines = CopyWrap.lineCount(text, columns: PopoverCopyLayout.innerColumns)
        XCTAssertLessThanOrEqual(lines, PopoverCopyLayout.captionMaxLines, file: file, line: line)
        XCTAssertGreaterThanOrEqual(
            PopoverCopyLayout.captionHeightPoints,
            lines * PopoverCopyLayout.lineHeightPoints,
            file: file,
            line: line
        )
    }

    private func assertFitsDurationHint(_ text: String, file: StaticString = #filePath, line: UInt = #line) {
        let lines = CopyWrap.lineCount(text, columns: PopoverCopyLayout.innerColumns)
        XCTAssertLessThanOrEqual(lines, PopoverCopyLayout.durationHintMaxLines, file: file, line: line)
        XCTAssertGreaterThanOrEqual(
            PopoverCopyLayout.durationHintHeightPoints,
            lines * PopoverCopyLayout.lineHeightPoints,
            file: file,
            line: line
        )
    }

    private func assertNoDisplaySleepFiction(_ blob: String, file: StaticString = #filePath, line: UInt = #line) {
        let lower = blob.lowercased()
        XCTAssertFalse(lower.contains("not dim"), file: file, line: line)
        XCTAssertFalse(lower.contains("not just dim"), file: file, line: line)
        XCTAssertFalse(lower.contains("sleeps for real"), file: file, line: line)
        XCTAssertFalse(lower.contains("displaysleepnow"), file: file, line: line)
        XCTAssertFalse(lower.contains("force display"), file: file, line: line)
        XCTAssertFalse(lower.contains("built-in display asleep"), file: file, line: line)
        XCTAssertFalse(lower.contains("asleep, not dim"), file: file, line: line)
        XCTAssertFalse(lower.contains("display asleep"), file: file, line: line)
        XCTAssertFalse(lower.contains("watt"), file: file, line: line)
        XCTAssertFalse(lower.contains("1.76"), file: file, line: line)
    }
}
