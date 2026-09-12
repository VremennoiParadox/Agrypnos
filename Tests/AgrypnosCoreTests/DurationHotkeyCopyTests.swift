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
    func testWedgeLanguageDoesNotClaimWattsOrForcedDisplaySleep() {
        let caption = AgrypnosCopy.captionOn(floor: 15)
        XCTAssertFalse(caption.lowercased().contains("watt"))
        XCTAssertFalse(caption.lowercased().contains("1.76"))
        XCTAssertTrue(AgrypnosCopy.agentsHint.lowercased().contains("busy"))
        XCTAssertEqual(AgrypnosCopy.quit, "Quit Agrypnos")
        XCTAssertEqual(AgrypnosCopy.hotkeyHint(.defaultToggle), "⌥⌘A toggles the watch")
    }

    func testCaptionOnDoesNotClaimForcedDisplaySleep() {
        let caption = AgrypnosCopy.captionOn(floor: 15)
        let lower = caption.lowercased()
        XCTAssertEqual(
            caption,
            "Armed. Lid close floors brightness and keys. Turns off at 15% battery."
        )
        XCTAssertFalse(lower.contains("not dim"))
        XCTAssertFalse(lower.contains("sleeps for real"))
        XCTAssertFalse(lower.contains("force"))
        XCTAssertFalse(lower.contains("asleep"))
        XCTAssertFalse(lower.contains("watt"))
        XCTAssertFalse(lower.contains("1.76"))
        XCTAssertTrue(lower.contains("armed"))
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
