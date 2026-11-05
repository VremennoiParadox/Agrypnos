import XCTest
@testable import AgrypnosCore

final class AgrypnosCopyTests: XCTestCase {
    func testWedgeLanguageDoesNotClaimWattsOrForcedDisplaySleep() {
        let caption = AgrypnosCopy.captionPrepared(floor: 15)
        XCTAssertFalse(caption.lowercased().contains("watt"))
        XCTAssertFalse(caption.lowercased().contains("1.76"))
        XCTAssertTrue(AgrypnosCopy.settleGraceHelp.lowercased().contains("local busy signals"))
        XCTAssertTrue(AgrypnosCopy.settleGraceHelp.lowercased().contains("keeps it from ending early"))
        XCTAssertEqual(AgrypnosCopy.quit, "Quit Agrypnos")
        XCTAssertEqual(AgrypnosCopy.hotkeyHint(.defaultToggle), "⌥⌘A toggles Keep awake")
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
            "we notify your phone",
            "agent stopped",
            "job finished",
            "1h left",
            "we track every ai",
            "we track every",
        ]
        for phrase in banned {
            XCTAssertFalse(blob.contains(phrase), "banned phrase still in copy: \(phrase)")
        }
    }

    func testArmedCaptionWaitsForLidThenFloorAndKeyboard() {
        let caption = AgrypnosCopy.captionPrepared(floor: 15, panelPowerMode: .floor)
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
        assertFitsCaption(AgrypnosCopy.captionPrepared(floor: 100, panelPowerMode: .floor))
        assertNoDisplaySleepFiction(caption)
    }

    func testLidClosedCaptionIsFloorAndKeyboardNotDisplaySleep() {
        let caption = AgrypnosCopy.captionLidClosed(floor: 15, panelPowerMode: .floor)
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
        assertFitsCaption(AgrypnosCopy.captionLidClosed(floor: 100, panelPowerMode: .floor))
        assertNoDisplaySleepFiction(caption)
    }

    func testOffCaptionIsEmptySoTheCardCanHugTheSwitch() {
        XCTAssertEqual(AgrypnosCopy.captionOff, "")
        XCTAssertEqual(
            AgrypnosCopy.watchCaption(engaged: false, leftover: false, floor: 15, lidClosed: false),
            ""
        )
    }

    func testWatchCaptionUsesLidOpenArmedAndLidClosedHolding() {
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
        XCTAssertEqual(AgrypnosCopy.menuTooltipOff, "Agrypnos: Keep awake is off.")
        XCTAssertEqual(
            AgrypnosCopy.menuTooltip(engaged: true, leftover: false, onBattery: false, lidClosed: false, panelPowerMode: .floor),
            "Agrypnos: armed. Waiting for lid close — then brightness floor + keyboard backlight off."
        )
        XCTAssertEqual(
            AgrypnosCopy.menuTooltip(engaged: true, leftover: false, onBattery: true, lidClosed: false, panelPowerMode: .floor),
            "Agrypnos: armed. Waiting for lid close — then brightness floor + keyboard backlight off. On battery."
        )
        XCTAssertEqual(
            AgrypnosCopy.menuTooltip(engaged: true, leftover: false, onBattery: false, lidClosed: true, panelPowerMode: .floor),
            "Agrypnos: lid closed. Brightness floor + keyboard backlight off."
        )
        XCTAssertEqual(
            AgrypnosCopy.menuTooltip(engaged: false, leftover: false, onBattery: false, lidClosed: false, panelPowerMode: .floor),
            AgrypnosCopy.menuTooltipOff
        )
        XCTAssertEqual(
            AgrypnosCopy.menuTooltip(engaged: true, leftover: true, onBattery: false, lidClosed: false, panelPowerMode: .floor),
            AgrypnosCopy.menuTooltipLeftover
        )
        XCTAssertEqual(
            AgrypnosCopy.menuTooltipLeftover,
            "Agrypnos: took over a leftover wake hold. Waiting for lid close — then brightness floor + keyboard backlight off."
        )
        XCTAssertEqual(
            AgrypnosCopy.menuTooltip(engaged: true, leftover: true, onBattery: false, lidClosed: true, panelPowerMode: .floor),
            "Agrypnos: took over a leftover wake hold. Lid closed. Brightness floor + keyboard backlight off."
        )
    }

    func testDurationHintsArePlainAndFitTheDurationCard() {
        let lid = "Turning Keep awake off with the lid confirmed closed sends the Mac to sleep. With the lid open or unconfirmed it turns Keep awake off and does not sleep the Mac."
        func withLid(_ base: String) -> String { base + " " + lid }
        XCTAssertEqual(
            AgrypnosCopy.agentsHint,
            "Keep awake turns off when the wait after agent signals stop ends (battery / thermal still apply)."
        )
        XCTAssertNotEqual(AgrypnosCopy.agentsHint, AgrypnosCopy.indefiniteHint)
        XCTAssertEqual(
            AgrypnosCopy.durationHint(option: .untilAgentsSettle, engaged: true, remainingSeconds: nil),
            withLid(AgrypnosCopy.agentsHint)
        )
        XCTAssertEqual(
            AgrypnosCopy.durationHint(option: .untilAgentsSettle, engaged: true, remainingSeconds: nil, thermalAutoOff: false),
            withLid("Keep awake turns off when the wait after agent signals stop ends (battery still applies).")
        )
        XCTAssertFalse(
            AgrypnosCopy.durationHint(option: .untilAgentsSettle, engaged: false, remainingSeconds: nil, thermalAutoOff: false)
                .lowercased()
                .contains("thermal")
        )
        XCTAssertEqual(
            AgrypnosCopy.durationHint(option: .indefinite, engaged: false, remainingSeconds: nil),
            withLid("Stays on until you turn it off (battery / thermal still apply).")
        )
        XCTAssertEqual(
            AgrypnosCopy.durationHint(option: .indefinite, engaged: false, remainingSeconds: nil, thermalAutoOff: true),
            withLid(AgrypnosCopy.indefiniteHint)
        )
        XCTAssertEqual(
            AgrypnosCopy.durationHint(option: .indefinite, engaged: false, remainingSeconds: nil, thermalAutoOff: false),
            withLid(AgrypnosCopy.indefiniteHint(thermalAutoOff: false))
        )
        XCTAssertEqual(
            AgrypnosCopy.indefiniteHint(thermalAutoOff: false),
            "Stays on until you turn it off (battery still applies)."
        )
        XCTAssertFalse(
            AgrypnosCopy.indefiniteHint(thermalAutoOff: false).lowercased().contains("thermal")
        )
        XCTAssertFalse(AgrypnosCopy.indefiniteHint.lowercased().contains("low power"))
        XCTAssertEqual(
            AgrypnosCopy.durationHint(option: .oneHour, engaged: false, remainingSeconds: nil),
            withLid(AgrypnosCopy.timedHint)
        )
        XCTAssertEqual(
            AgrypnosCopy.durationHint(option: .threeHours, engaged: false, remainingSeconds: nil),
            withLid(AgrypnosCopy.timedHint)
        )
        XCTAssertEqual(
            AgrypnosCopy.durationHint(option: .oneHour, engaged: true, remainingSeconds: 125),
            AgrypnosCopy.timedHint
        )
        for text in [
            AgrypnosCopy.durationHint(option: .indefinite, engaged: true, remainingSeconds: nil),
            AgrypnosCopy.durationHint(option: .untilAgentsSettle, engaged: true, remainingSeconds: nil),
            AgrypnosCopy.durationHint(option: .oneHour, engaged: false, remainingSeconds: nil),
        ] {
            XCTAssertTrue(text.contains(lid))
            XCTAssertFalse(text.lowercased().contains("disarm always sleeps"))
        }
        assertFitsDurationHint(AgrypnosCopy.agentsHint)
        assertFitsDurationHint(
            AgrypnosCopy.durationHint(option: .untilAgentsSettle, engaged: false, remainingSeconds: nil, thermalAutoOff: false)
        )
        assertFitsDurationHint(AgrypnosCopy.timedHint)
        assertFitsDurationHint(AgrypnosCopy.indefiniteHint)
        assertFitsDurationHint(
            AgrypnosCopy.durationHint(option: .indefinite, engaged: true, remainingSeconds: nil)
        )
        assertFitsDurationHint(
            AgrypnosCopy.durationHint(option: .oneHour, engaged: false, remainingSeconds: nil)
        )
        assertFitsDurationHint(
            AgrypnosCopy.durationHint(option: .customMinutes(33), engaged: false, remainingSeconds: nil)
        )
    }

    func testThermalAutoOffCopyIsPlainAndOmitsCelsius() {
        XCTAssertEqual(AgrypnosCopy.thermalAutoOff, "Thermal auto-off")
        XCTAssertEqual(
            AgrypnosCopy.thermalAutoOffHelp,
            "High temperature turns Keep awake off and sends the Mac to sleep."
        )
        let blob = allUserFacingCopy().joined(separator: "\n").lowercased()
        for banned in ["°c", "celsius", "safe temp", "health-gauge", "health gauge", "warranty"] {
            XCTAssertFalse(blob.contains(banned), "thermal fiction still in copy: \(banned)")
        }
        XCTAssertFalse(AgrypnosCopy.thermalAutoOffHelp.lowercased().contains("°c"))
        XCTAssertFalse(AgrypnosCopy.thermalAutoOff.lowercased().contains("smc"))
        assertFitsHelp(AgrypnosCopy.thermalAutoOffHelp)
        XCTAssertLessThanOrEqual(
            CopyWrap.lineCount(AgrypnosCopy.thermalAutoOff, columns: PopoverCopyLayout.innerColumns),
            2
        )
        assertFitsDurationHint(AgrypnosCopy.indefiniteHint(thermalAutoOff: false))
        assertFitsDurationHint(AgrypnosCopy.indefiniteHint(thermalAutoOff: true))
    }

    func testEndedNotificationsArePlainWatchTurnedOff() {
        XCTAssertEqual(AgrypnosCopy.notification(for: .user), "Keep awake turned off.")
        XCTAssertEqual(AgrypnosCopy.notification(for: .timerExpired), "Timer ended. Keep awake turned off.")
        XCTAssertEqual(
            AgrypnosCopy.notification(for: .batteryFloor),
            "Low battery. Keep awake turned off."
        )
        XCTAssertEqual(
            AgrypnosCopy.notification(for: .thermal),
            "Thermal pressure. Keep awake turned off."
        )
        XCTAssertEqual(AgrypnosCopy.notification(for: .agentsSettled), "The wait after agent signals stop ended. Keep awake turned off.")
        XCTAssertEqual(AgrypnosCopy.notification(for: .lowPowerMode), "Low Power Mode. Keep awake turned off.")
        XCTAssertEqual(AgrypnosCopy.notification(for: .lowPowerMode), AgrypnosCopy.lpmEnded)
        XCTAssertEqual(AgrypnosCopy.timerEnded, "Timer ended. Keep awake turned off.")
        XCTAssertEqual(AgrypnosCopy.batteryEnded, "Low battery. Keep awake turned off.")
        XCTAssertEqual(AgrypnosCopy.thermalEnded, "Thermal pressure. Keep awake turned off.")
        XCTAssertEqual(AgrypnosCopy.agentsEnded, "The wait after agent signals stop ended. Keep awake turned off.")
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
            AgrypnosCopy.watchCaption(engaged: true, leftover: true, floor: 15, lidClosed: true),
            AgrypnosCopy.durationHint(option: .indefinite, engaged: true, remainingSeconds: nil),
            AgrypnosCopy.durationHint(option: .oneHour, engaged: true, remainingSeconds: 125),
        ]
        for caption in engagedCaptions {
            XCTAssertFalse(
                caption.contains("Keep awake turned off."),
                "engaged copy must not claim ended: \(caption)"
            )
            XCTAssertFalse(caption.lowercased().contains("stands down"))
        }
    }

    func testLeftoverAdoptCopyIsVisibleAndDoesNotClaimWatts() {
        let open = AgrypnosCopy.leftoverCaption(floor: 15, lidClosed: false, panelPowerMode: .floor)
        let closed = AgrypnosCopy.leftoverCaption(floor: 15, lidClosed: true, panelPowerMode: .floor)
        let notify = AgrypnosCopy.leftoverNotify
        XCTAssertEqual(
            open,
            "Leftover wake hold. Lid close — then brightness floor, keyboard backlight off. Auto-off at 15% battery."
        )
        XCTAssertEqual(
            closed,
            "Leftover wake hold. Lid closed. Brightness floor, keyboard backlight off. Auto-off at 15% battery."
        )
        XCTAssertTrue(open.lowercased().contains("then"))
        XCTAssertFalse(closed.lowercased().contains("then"))
        XCTAssertTrue(closed.lowercased().contains("lid closed"))
        XCTAssertEqual(
            notify,
            "The wake hold was already on from before. Agrypnos took it over as Keep awake. Lid close still uses brightness floor + keyboard backlight off."
        )
        XCTAssertTrue(open.lowercased().contains("leftover"))
        XCTAssertTrue(open.lowercased().contains("wake hold"))
        XCTAssertTrue(notify.lowercased().contains("already on"))
        XCTAssertTrue(notify.lowercased().contains("took it over"))
        XCTAssertTrue(notify.lowercased().contains("brightness floor"))
        XCTAssertTrue(notify.lowercased().contains("keyboard"))
        XCTAssertFalse(open.lowercased().contains("watt"))
        XCTAssertFalse(notify.lowercased().contains("1.76"))
        assertFitsCaption(open)
        assertFitsCaption(closed)
        assertFitsCaption(AgrypnosCopy.leftoverCaption(floor: 50, lidClosed: false, panelPowerMode: .floor))
        assertFitsCaption(AgrypnosCopy.leftoverCaption(floor: 100, lidClosed: false, panelPowerMode: .floor))
        assertFitsCaption(AgrypnosCopy.leftoverCaption(floor: 50, lidClosed: true, panelPowerMode: .floor))
        assertFitsCaption(AgrypnosCopy.leftoverCaption(floor: 100, lidClosed: true, panelPowerMode: .floor))
        assertFitsCaption(AgrypnosCopy.captionPrepared(floor: 50, panelPowerMode: .floor))
        XCTAssertEqual(
            AgrypnosCopy.watchCaption(engaged: true, leftover: true, floor: 15, lidClosed: false, panelPowerMode: .floor),
            open
        )
        XCTAssertEqual(
            AgrypnosCopy.watchCaption(engaged: true, leftover: true, floor: 15, lidClosed: true, panelPowerMode: .floor),
            closed
        )
        XCTAssertEqual(
            AgrypnosCopy.watchCaption(engaged: true, leftover: false, floor: 15, lidClosed: false, panelPowerMode: .floor),
            AgrypnosCopy.captionPrepared(floor: 15, panelPowerMode: .floor)
        )
        XCTAssertEqual(
            AgrypnosCopy.watchCaption(engaged: false, leftover: true, floor: 15, lidClosed: false, panelPowerMode: .floor),
            AgrypnosCopy.captionOff
        )
    }

    func testLeftoverOpenAndClosedCaptionsBothSayBattery() {
        for lidClosed in [false, true] {
            for floor in [5, 15, 100] {
                let caption = AgrypnosCopy.leftoverCaption(floor: floor, lidClosed: lidClosed, panelPowerMode: .floor)
                XCTAssertTrue(
                    caption.lowercased().contains("battery"),
                    "leftover lidClosed=\(lidClosed) floor=\(floor) dropped battery: \(caption)"
                )
                XCTAssertTrue(caption.contains("\(floor)%"))
                assertFitsCaption(caption)
            }
        }
    }

    func testPrefRowCopyIsPlainAndFits() {
        XCTAssertFalse(AgrypnosCopy.settleGrace.lowercased().contains("settle grace"))
        XCTAssertFalse(AgrypnosCopy.lidOpenRamp.lowercased().contains("lid-open ramp"))
        XCTAssertFalse(AgrypnosCopy.settleGraceHelp.lowercased().contains("settle grace"))
        XCTAssertFalse(AgrypnosCopy.lidOpenRampHelp.lowercased().contains("lid-open ramp"))
        XCTAssertEqual(AgrypnosCopy.settleGrace, "Wait after agent signals stop")
        XCTAssertEqual(
            AgrypnosCopy.settleGraceHelp,
            "How long to wait after local busy signals stop before Keep awake turns off. A quiet gap mid-run, with no file writes or CPU use, can look finished, so this wait keeps it from ending early. Agrypnos sees only local process and session activity, not what an agent is doing."
        )
        XCTAssertTrue(AgrypnosCopy.settleGraceHelp.lowercased().contains("local busy signals"))
        XCTAssertTrue(AgrypnosCopy.settleGraceHelp.lowercased().contains("keep awake"))
        XCTAssertTrue(AgrypnosCopy.settleGraceHelp.lowercased().contains("not what an agent is doing"))
        XCTAssertFalse(AgrypnosCopy.settleGraceHelp.lowercased().contains("idle-after-wait"))
        XCTAssertFalse(AgrypnosCopy.settleGraceHelp.lowercased().contains("agent finished"))
        XCTAssertTrue(AgrypnosCopy.lidOpenRamp.lowercased().contains("brightness"))
        XCTAssertTrue(AgrypnosCopy.lidOpenRampHelp.lowercased().contains("lid"))
        XCTAssertTrue(AgrypnosCopy.brightnessFloorHelp.lowercased().contains("lid"))
        XCTAssertTrue(AgrypnosCopy.brightnessFloorHelp.lowercased().contains("percent"))
        assertFitsSettleHelp(AgrypnosCopy.settleGraceHelp)
        assertFitsHelp(AgrypnosCopy.lidOpenRampHelp)
        assertFitsHelp(AgrypnosCopy.brightnessFloorHelp)
        assertFitsHelp(AgrypnosCopy.thermalAutoOffHelp)
        XCTAssertLessThanOrEqual(
            CopyWrap.lineCount(AgrypnosCopy.settleGrace, columns: PopoverCopyLayout.innerColumns),
            2
        )
        XCTAssertLessThanOrEqual(
            CopyWrap.lineCount(AgrypnosCopy.lidOpenRamp, columns: PopoverCopyLayout.innerColumns),
            2
        )
    }

    func testHotkeyHintsFitTheHintSlot() {
        assertFitsHotkeyHint(AgrypnosCopy.hotkeyHint(.defaultToggle, registered: true))
        assertFitsHotkeyHint(AgrypnosCopy.hotkeyHint(.defaultToggle, registered: false))
        assertFitsHotkeyHint(AgrypnosCopy.hotkeyRecordingHint)
        assertFitsHotkeyHint(
            AgrypnosCopy.hotkeyHint(
                HotkeyChord(keyCode: 0, option: false, command: false),
                registered: false
            )
        )
    }

    func testHotkeyHintDoesNotClaimActiveWhenRegistrationFailed() {
        let failed = AgrypnosCopy.hotkeyHint(.defaultToggle, registered: false)
        XCTAssertTrue(failed.contains("⌥⌘A"))
        XCTAssertFalse(failed.lowercased().contains("toggles keep awake"))
        XCTAssertTrue(failed.lowercased().contains("not registered") || failed.lowercased().contains("isn’t registered"))
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

    private func assertFitsHelp(_ text: String, file: StaticString = #filePath, line: UInt = #line) {
        let lines = CopyWrap.lineCount(text, columns: PopoverCopyLayout.innerColumns)
        XCTAssertLessThanOrEqual(lines, PopoverCopyLayout.helpMaxLines, file: file, line: line)
        XCTAssertGreaterThanOrEqual(
            PopoverCopyLayout.helpHeightPoints,
            lines * PopoverCopyLayout.lineHeightPoints,
            file: file,
            line: line
        )
    }

    private func assertFitsSettleHelp(_ text: String, file: StaticString = #filePath, line: UInt = #line) {
        let lines = CopyWrap.lineCount(text, columns: PopoverCopyLayout.innerColumns)
        XCTAssertGreaterThan(lines, PopoverCopyLayout.helpMaxLines, file: file, line: line)
        XCTAssertLessThanOrEqual(lines, PopoverCopyLayout.settleHelpMaxLines, file: file, line: line)
        XCTAssertGreaterThanOrEqual(
            PopoverCopyLayout.settleHelpHeightPoints,
            lines * PopoverCopyLayout.lineHeightPoints,
            file: file,
            line: line
        )
    }

    private func assertFitsHotkeyHint(_ text: String, file: StaticString = #filePath, line: UInt = #line) {
        let lines = CopyWrap.lineCount(text, columns: PopoverCopyLayout.innerColumns)
        XCTAssertLessThanOrEqual(lines, PopoverCopyLayout.hotkeyHintMaxLines, file: file, line: line)
        XCTAssertGreaterThanOrEqual(
            PopoverCopyLayout.hotkeyHintHeightPoints,
            lines * PopoverCopyLayout.lineHeightPoints,
            file: file,
            line: line
        )
    }
}
