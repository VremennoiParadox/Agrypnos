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
        let title = AgrypnosCopy.displaySleep.lowercased()
        let help = AgrypnosCopy.displaySleepHelp.lowercased()
        let caption = AgrypnosCopy.captionOn(floor: 15).lowercased()
        XCTAssertTrue(title.contains("built-in"))
        XCTAssertFalse(title.contains("force display asleep"))
        XCTAssertTrue(help.contains("extra"))
        XCTAssertTrue(help.contains("not dim"))
        XCTAssertTrue(caption.contains("built-in"))
        XCTAssertFalse(caption.contains("watt"))
    }

    func testHotkeyHintDoesNotClaimActiveWhenRegistrationFailed() {
        let failed = AgrypnosCopy.hotkeyHint(.defaultToggle, registered: false)
        XCTAssertTrue(failed.contains("⌥⌘A"))
        XCTAssertFalse(failed.lowercased().contains("toggles the watch"))
        XCTAssertTrue(failed.lowercased().contains("not registered") || failed.lowercased().contains("isn’t registered"))
    }
}
