import XCTest
@testable import AgrypnosCore

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
        XCTAssertEqual(UserPreferences.agentSettleGraceRange, 90...600)
        XCTAssertEqual(UserPreferences.defaultAgentSettleGrace, 120)
        XCTAssertEqual(UserPreferences.default.agentSettleGrace, 120)
        XCTAssertEqual(AgentSettleGraceChrome.minLabel, "1m 30s")
        XCTAssertNotEqual(AgentSettleGraceChrome.minLabel, "1m")
        XCTAssertNotEqual(AgentSettleGraceChrome.minLabel, "120s")
        XCTAssertEqual(AgentSettleGraceChrome.maxLabel, "10m")
        XCTAssertEqual(AgentSettleGraceChrome.valueLabel(seconds: 15), "1m 30s")
        XCTAssertEqual(AgentSettleGraceChrome.valueLabel(seconds: 90), "1m 30s")
        XCTAssertEqual(AgentSettleGraceChrome.valueLabel(seconds: 120), "2m")
        XCTAssertEqual(AgentSettleGraceChrome.valueLabel(seconds: 150), "2m 30s")
        XCTAssertEqual(AgentSettleGraceChrome.valueLabel(seconds: 600), "10m")
        XCTAssertEqual(AgentSettleGraceChrome.valueLabel(seconds: 900), "10m")
        XCTAssertEqual(AgentSettleGraceChrome.seconds(sliderValue: 5), 90)
        XCTAssertEqual(AgentSettleGraceChrome.seconds(sliderValue: 90), 90)
        XCTAssertEqual(AgentSettleGraceChrome.seconds(sliderValue: 120), 120)
        XCTAssertEqual(AgentSettleGraceChrome.seconds(sliderValue: 9_999), 600)
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
        XCTAssertEqual(
            AgrypnosCopy.thermalAutoOffHelp,
            "High temperature turns Keep awake off and sends the Mac to sleep."
        )
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
