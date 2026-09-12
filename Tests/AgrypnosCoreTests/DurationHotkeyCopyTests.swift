import XCTest
@testable import AgrypnosCore

final class DurationOptionTests: XCTestCase {
    func testSegmentTitlesAndMinutes() {
        XCTAssertEqual(DurationOption.indefinite.segmentTitle, "∞")
        XCTAssertEqual(DurationOption.oneHour.minutes, 60)
        XCTAssertEqual(DurationOption.threeHours.minutes, 180)
        XCTAssertNil(DurationOption.untilAgentsSettle.minutes)
        XCTAssertEqual(DurationOption.allCases.count, 4)
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
    func testWedgeLanguageDoesNotClaimWattsOrDimAsSleep() {
        let caption = AgrypnosCopy.captionOn(floor: 15)
        XCTAssertFalse(caption.lowercased().contains("watt"))
        XCTAssertFalse(caption.lowercased().contains("1.76"))
        XCTAssertTrue(caption.lowercased().contains("not dim") || AgrypnosCopy.displaySleepHelp.lowercased().contains("not dim"))
        XCTAssertTrue(AgrypnosCopy.agentsHint.lowercased().contains("busy"))
        XCTAssertEqual(AgrypnosCopy.quit, "Quit Agrypnos")
        XCTAssertEqual(AgrypnosCopy.hotkeyHint(.defaultToggle), "⌥⌘A toggles the watch")
    }

    func testDisplaySleepCopyMatchesBuiltInOnlyBehavior() {
        XCTAssertEqual(AgrypnosCopy.displaySleep, "Built-in display asleep")
        XCTAssertEqual(
            AgrypnosCopy.displaySleepHelp,
            "Asleep, not dim. Skips when an external display is connected."
        )
        XCTAssertEqual(
            AgrypnosCopy.captionOn(floor: 15),
            "Lid can fall. Built-in display sleeps for real — not dim. Turns off at 15% battery."
        )
        XCTAssertFalse(AgrypnosCopy.displaySleep.lowercased().contains("force"))
        let help = AgrypnosCopy.displaySleepHelp.lowercased()
        let caption = AgrypnosCopy.captionOn(floor: 15).lowercased()
        XCTAssertTrue(help.contains("not dim"))
        XCTAssertTrue(help.contains("external"))
        XCTAssertTrue(help.contains("skip"))
        XCTAssertTrue(caption.contains("built-in"))
        XCTAssertTrue(caption.contains("not dim"))
        XCTAssertFalse(caption.contains("watt"))
        XCTAssertFalse(caption.contains("1.76"))
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
        XCTAssertEqual(
            AgrypnosCopy.watchCaption(engaged: true, leftover: true, floor: 15),
            caption
        )
        XCTAssertEqual(
            AgrypnosCopy.watchCaption(engaged: true, leftover: false, floor: 15),
            AgrypnosCopy.captionOn(floor: 15)
        )
        XCTAssertEqual(AgrypnosCopy.watchCaption(engaged: false, leftover: true, floor: 15), AgrypnosCopy.captionOff)
    }

    func testHotkeyHintDoesNotClaimActiveWhenRegistrationFailed() {
        let failed = AgrypnosCopy.hotkeyHint(.defaultToggle, registered: false)
        XCTAssertTrue(failed.contains("⌥⌘A"))
        XCTAssertFalse(failed.lowercased().contains("toggles the watch"))
        XCTAssertTrue(failed.lowercased().contains("not registered") || failed.lowercased().contains("isn’t registered"))
    }
}
