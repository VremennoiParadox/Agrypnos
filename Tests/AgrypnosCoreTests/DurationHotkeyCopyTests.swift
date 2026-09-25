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

