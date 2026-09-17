import XCTest
@testable import AgrypnosCore

final class LastWatchEndTests: XCTestCase {
    let t0 = Date(timeIntervalSince1970: 10_000)

    func testDefaultPreferencesHaveNoLastWatchEnd() {
        XCTAssertNil(UserPreferences.default.lastWatchEnd)
        XCTAssertNil(UserPreferences().lastWatchEnd)
    }

    func testLastWatchEndRoundTripsWithPreferences() throws {
        var prefs = UserPreferences.default
        prefs.lastWatchEnd = LastWatchEnd(endedAt: t0, reason: .batteryFloor)
        let loaded = try JSONDecoder().decode(UserPreferences.self, from: try JSONEncoder().encode(prefs))
        XCTAssertEqual(loaded.lastWatchEnd?.endedAt, t0)
        XCTAssertEqual(loaded.lastWatchEnd?.reason, .batteryFloor)
    }

    func testMissingLastWatchEndKeyDecodesNil() throws {
        let json = """
        {"batteryFloorPercent":15,"duration":"indefinite","keyboardBacklightOff":true,"applyBrightnessFloor":true,"brightnessFloorPercent":15,"agentSettleGrace":120,"sessionFreshness":45,"lidOpenRampSeconds":2,"hotkey":{"keyCode":0,"option":true,"command":true,"shift":false,"control":false},"thermalAutoOff":true,"notifEnabled":false}
        """
        let decoded = try JSONDecoder().decode(UserPreferences.self, from: Data(json.utf8))
        XCTAssertNil(decoded.lastWatchEnd)
    }
}
