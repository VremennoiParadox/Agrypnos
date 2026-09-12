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

    func testPreparedCaptionWaitsForLidAndDoesNotClaimDisplaySleep() {
        let caption = AgrypnosCopy.captionPrepared(floor: 15)
        let lower = caption.lowercased()
        XCTAssertEqual(
            caption,
            "Prepared. Waiting for the lid — I'll floor the panel and kill the keys. Turns off at 15% battery."
        )
        XCTAssertTrue(lower.contains("prepared"))
        XCTAssertTrue(lower.contains("waiting"))
        XCTAssertTrue(lower.contains("lid"))
        XCTAssertFalse(lower.contains("armed"))
        let captionLines = CopyWrap.lineCount(caption, columns: PopoverCopyLayout.innerColumns)
        XCTAssertLessThanOrEqual(captionLines, PopoverCopyLayout.captionMaxLines)
        XCTAssertGreaterThanOrEqual(
            PopoverCopyLayout.captionHeightPoints,
            captionLines * PopoverCopyLayout.lineHeightPoints
        )
        assertNoDisplaySleepFiction(caption)
    }

    func testLidClosedCaptionIsFloorAndKeysNotDisplaySleep() {
        let caption = AgrypnosCopy.captionLidClosed(floor: 15)
        let lower = caption.lowercased()
        XCTAssertEqual(
            caption,
            "Lid's down. Brightness floored, keys dark. Turns off at 15% battery."
        )
        XCTAssertTrue(lower.contains("floor"))
        XCTAssertTrue(lower.contains("keys"))
        XCTAssertFalse(lower.contains("waiting"))
        assertNoDisplaySleepFiction(caption)
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
        XCTAssertEqual(
            AgrypnosCopy.menuTooltip(engaged: true, leftover: false, onBattery: false, lidClosed: false),
            "Agrypnos: prepared. Waiting for the lid."
        )
        XCTAssertEqual(
            AgrypnosCopy.menuTooltip(engaged: true, leftover: false, onBattery: true, lidClosed: false),
            "Agrypnos: prepared. Waiting for the lid. On battery."
        )
        XCTAssertEqual(
            AgrypnosCopy.menuTooltip(engaged: true, leftover: false, onBattery: false, lidClosed: true),
            "Agrypnos: lid down. Brightness floored, keys dark."
        )
        XCTAssertEqual(
            AgrypnosCopy.menuTooltip(engaged: false, leftover: false, onBattery: false, lidClosed: false),
            AgrypnosCopy.menuTooltipOff
        )
        XCTAssertEqual(
            AgrypnosCopy.menuTooltip(engaged: true, leftover: true, onBattery: false, lidClosed: false),
            AgrypnosCopy.menuTooltipLeftover
        )
    }

    func testAgentsHintIsACompleteSentenceThatFitsTheDurationCard() {
        XCTAssertEqual(
            AgrypnosCopy.agentsHint,
            "Busy stays awake. When they settle, sleep may return."
        )
        XCTAssertEqual(
            AgrypnosCopy.durationHint(option: .untilAgentsSettle, engaged: true, remainingSeconds: nil),
            AgrypnosCopy.agentsHint
        )
        XCTAssertEqual(
            AgrypnosCopy.durationHint(option: .indefinite, engaged: false, remainingSeconds: nil),
            "Until you say otherwise — plus safety nets."
        )
        XCTAssertEqual(
            AgrypnosCopy.durationHint(option: .oneHour, engaged: false, remainingSeconds: nil),
            "Then the watch stands down."
        )
        XCTAssertEqual(
            AgrypnosCopy.durationHint(option: .oneHour, engaged: true, remainingSeconds: 125),
            "Auto-off in 2:05"
        )
        let lines = CopyWrap.lineCount(AgrypnosCopy.agentsHint, columns: PopoverCopyLayout.innerColumns)
        XCTAssertLessThanOrEqual(lines, PopoverCopyLayout.durationHintMaxLines)
        XCTAssertGreaterThanOrEqual(
            PopoverCopyLayout.durationHintHeightPoints,
            lines * PopoverCopyLayout.lineHeightPoints
        )
    }

    func testLeftoverAdoptCopyIsVisibleAndDoesNotClaimWatts() {
        let caption = AgrypnosCopy.leftoverCaption(floor: 15)
        let notify = AgrypnosCopy.leftoverNotify
        XCTAssertTrue(caption.lowercased().contains("leftover"))
        XCTAssertTrue(caption.lowercased().contains("adopt"))
        XCTAssertTrue(notify.lowercased().contains("leftover") || notify.lowercased().contains("already on"))
        XCTAssertTrue(notify.lowercased().contains("adopt"))
        XCTAssertFalse(caption.lowercased().contains("watt"))
        XCTAssertFalse(notify.lowercased().contains("1.76"))
        let leftoverLines = CopyWrap.lineCount(caption, columns: PopoverCopyLayout.innerColumns)
        XCTAssertLessThanOrEqual(leftoverLines, PopoverCopyLayout.captionMaxLines)
        XCTAssertGreaterThanOrEqual(
            PopoverCopyLayout.captionHeightPoints,
            leftoverLines * PopoverCopyLayout.lineHeightPoints
        )
        XCTAssertLessThanOrEqual(
            CopyWrap.lineCount(AgrypnosCopy.leftoverCaption(floor: 50), columns: PopoverCopyLayout.innerColumns),
            PopoverCopyLayout.captionMaxLines
        )
        XCTAssertLessThanOrEqual(
            CopyWrap.lineCount(AgrypnosCopy.captionPrepared(floor: 50), columns: PopoverCopyLayout.innerColumns),
            PopoverCopyLayout.captionMaxLines
        )
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
            AgrypnosCopy.keyboardDark,
            AgrypnosCopy.brightnessFloor,
            AgrypnosCopy.batteryFloor,
            AgrypnosCopy.launchAtLogin,
            AgrypnosCopy.quit,
            AgrypnosCopy.agentsHint,
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
            AgrypnosCopy.captionLidClosed(floor: 15),
            AgrypnosCopy.leftoverCaption(floor: 15),
            AgrypnosCopy.hotkeyHint(.defaultToggle, registered: true),
            AgrypnosCopy.hotkeyHint(.defaultToggle, registered: false),
            AgrypnosCopy.durationHint(option: .untilAgentsSettle, engaged: false, remainingSeconds: nil),
            AgrypnosCopy.durationHint(option: .indefinite, engaged: false, remainingSeconds: nil),
            AgrypnosCopy.durationHint(option: .oneHour, engaged: false, remainingSeconds: nil),
            AgrypnosCopy.durationHint(option: .customMinutes(33), engaged: false, remainingSeconds: nil),
            AgrypnosCopy.notification(for: .user),
            AgrypnosCopy.notification(for: .timerExpired),
            AgrypnosCopy.notification(for: .batteryFloor),
            AgrypnosCopy.notification(for: .thermal),
            AgrypnosCopy.notification(for: .agentsSettled),
            AgrypnosCopy.notification(for: .lowPowerMode),
        ]
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
