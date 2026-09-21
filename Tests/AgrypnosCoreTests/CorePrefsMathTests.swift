import XCTest
@testable import AgrypnosCore

final class CorePrefsMathTests: XCTestCase {
    let t0 = Date(timeIntervalSince1970: 10_000)

    func testBrightnessFloorDefaultIsFifteenPercentNeverZero() {
        XCTAssertEqual(UserPreferences.brightnessFloorPercentRange, 1...40)
        XCTAssertEqual(UserPreferences.default.brightnessFloorPercent, 15)
        XCTAssertEqual(UserPreferences.defaultBrightnessFloorPercent, 15)
        XCTAssertEqual(UserPreferences.default.brightnessFloor, 0.15, accuracy: 0.0001)
        XCTAssertNotEqual(UserPreferences.default.brightnessFloorPercent, 0)
        XCTAssertGreaterThan(UserPreferences.default.brightnessFloor, 0)
        XCTAssertEqual(UserPreferences.clampBrightnessFloor(0), 1)
        XCTAssertEqual(UserPreferences(brightnessFloorPercent: 0).brightnessFloorPercent, 1)
        XCTAssertNotEqual(UserPreferences(brightnessFloorPercent: 0).brightnessFloor, 0)
    }

    func testBrightnessFloorPercentClampsAndMapsToUnit() {
        XCTAssertEqual(UserPreferences.clampBrightnessFloor(0), 1)
        XCTAssertEqual(UserPreferences.clampBrightnessFloor(-3), 1)
        XCTAssertEqual(UserPreferences.clampBrightnessFloor(1), 1)
        XCTAssertEqual(UserPreferences.clampBrightnessFloor(4), 4)
        XCTAssertEqual(UserPreferences.clampBrightnessFloor(5), 5)
        XCTAssertEqual(UserPreferences.clampBrightnessFloor(20), 20)
        XCTAssertEqual(UserPreferences.clampBrightnessFloor(40), 40)
        XCTAssertEqual(UserPreferences.clampBrightnessFloor(41), 40)
        XCTAssertEqual(UserPreferences(brightnessFloorPercent: 4).brightnessFloorPercent, 4)
        XCTAssertEqual(UserPreferences(brightnessFloorPercent: 20).brightnessFloorPercent, 20)
        XCTAssertEqual(UserPreferences(brightnessFloorPercent: 99).brightnessFloorPercent, 40)
        XCTAssertEqual(UserPreferences(brightnessFloorPercent: 20).brightnessFloor, 0.20, accuracy: 0.0001)
        XCTAssertNotEqual(UserPreferences(brightnessFloorPercent: 20).brightnessFloor, 0.05)
    }

    func testBrightnessFloorPercentPersistsAndLegacyFractionDecodes() throws {
        let prefs = UserPreferences(brightnessFloorPercent: 20)
        let data = try JSONEncoder().encode(prefs)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(object["brightnessFloorPercent"] as? Int, 20)
        let loaded = try JSONDecoder().decode(UserPreferences.self, from: data)
        XCTAssertEqual(loaded.brightnessFloorPercent, 20)
        XCTAssertEqual(loaded.brightnessFloor, 0.20, accuracy: 0.0001)

        let overshoot = try JSONDecoder().decode(
            UserPreferences.self,
            from: Data(fixtureJSON(brightnessFloorPercent: 80).utf8)
        )
        XCTAssertEqual(overshoot.brightnessFloorPercent, 40)

        let legacy = try JSONDecoder().decode(
            UserPreferences.self,
            from: Data(legacyFractionJSON(brightnessFloor: 0.2).utf8)
        )
        XCTAssertEqual(legacy.brightnessFloorPercent, 20)
        XCTAssertEqual(legacy.brightnessFloor, 0.20, accuracy: 0.0001)
    }

    func testAgentSettleGraceDefaultIsTwoMinutesAndClampsUpFromOldFloor() {
        XCTAssertEqual(UserPreferences.agentSettleGraceRange, 120...900)
        XCTAssertEqual(UserPreferences.defaultAgentSettleGrace, 120)
        XCTAssertEqual(UserPreferences.default.agentSettleGrace, 120)
        XCTAssertEqual(UserPreferences.clampAgentSettleGrace(5), 120)
        XCTAssertEqual(UserPreferences.clampAgentSettleGrace(15), 120)
        XCTAssertEqual(UserPreferences.clampAgentSettleGrace(90), 120)
        XCTAssertEqual(UserPreferences.clampAgentSettleGrace(120), 120)
        XCTAssertEqual(UserPreferences.clampAgentSettleGrace(900), 900)
        XCTAssertEqual(UserPreferences.clampAgentSettleGrace(12_000), 900)
        XCTAssertEqual(UserPreferences.clampAgentSettleGrace(minutes: 0), 120)
        XCTAssertEqual(UserPreferences.clampAgentSettleGrace(minutes: 2), 120)
        XCTAssertEqual(UserPreferences.clampAgentSettleGrace(minutes: 20), 900)
        XCTAssertEqual(UserPreferences(agentSettleGrace: 5).agentSettleGrace, 120)
        XCTAssertEqual(UserPreferences(agentSettleGrace: 15).agentSettleGrace, 120)
        XCTAssertEqual(UserPreferences(agentSettleGrace: 90).agentSettleGrace, 120)
        XCTAssertEqual(UserPreferences(agentSettleGrace: 120).agentSettleGrace, 120)
        XCTAssertEqual(UserPreferences(agentSettleGrace: 9_999).agentSettleGrace, 900)
        XCTAssertEqual(UserPreferences.clampAgentSettleGrace(1e20), 900)
        XCTAssertEqual(UserPreferences.clampAgentSettleGrace(.infinity), 120)
        XCTAssertEqual(UserPreferences(agentSettleGrace: .nan).agentSettleGrace, 120)
    }

    func testAgentSettleGracePersistsAndDecodedOvershootClamps() throws {
        let prefs = UserPreferences(agentSettleGrace: 120)
        let loaded = try roundTrip(prefs)
        XCTAssertEqual(loaded.agentSettleGrace, 120)

        let decoded = try JSONDecoder().decode(
            UserPreferences.self,
            from: Data(fixtureJSON(agentSettleGrace: 5_000).utf8)
        )
        XCTAssertEqual(decoded.agentSettleGrace, 900)
    }

    func testMissingRampKeyDecodesToDefaultTwoSeconds() throws {
        let decoded = try JSONDecoder().decode(
            UserPreferences.self,
            from: Data(legacyFractionJSON(brightnessFloor: 0.15).utf8)
        )
        XCTAssertEqual(decoded.lidOpenRampSeconds, 2)
        XCTAssertEqual(decoded.agentSettleGrace, 120)
        XCTAssertEqual(decoded.brightnessFloorPercent, 15)
        XCTAssertTrue(decoded.thermalAutoOff)
    }

    func testMissingSettleGraceKeyDecodesToTwoMinutes() throws {
        let json = """
        {"batteryFloorPercent":15,"duration":"indefinite","keyboardBacklightOff":true,"applyBrightnessFloor":true,"brightnessFloorPercent":15,"sessionFreshness":45,"lidOpenRampSeconds":2,"hotkey":{"keyCode":0,"option":true,"command":true,"shift":false,"control":false}}
        """
        let decoded = try JSONDecoder().decode(UserPreferences.self, from: Data(json.utf8))
        XCTAssertEqual(decoded.agentSettleGrace, 120)
        XCTAssertEqual(decoded.agentSettleGrace, UserPreferences.defaultAgentSettleGrace)
    }

    func testThermalAutoOffDefaultsOnAndMissingKeyDecodesTrue() throws {
        XCTAssertTrue(UserPreferences.default.thermalAutoOff)
        XCTAssertTrue(UserPreferences().thermalAutoOff)

        let encoded = try JSONEncoder().encode(UserPreferences.default)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        XCTAssertEqual(object["thermalAutoOff"] as? Bool, true)
        let loaded = try JSONDecoder().decode(UserPreferences.self, from: encoded)
        XCTAssertTrue(loaded.thermalAutoOff)

        let missing = try JSONDecoder().decode(
            UserPreferences.self,
            from: Data(legacyFractionJSON(brightnessFloor: 0.15).utf8)
        )
        XCTAssertTrue(missing.thermalAutoOff)

        let off = UserPreferences(thermalAutoOff: false)
        XCTAssertFalse(off.thermalAutoOff)
        let roundTripped = try roundTrip(off)
        XCTAssertFalse(roundTripped.thermalAutoOff)
    }

    func testMissingBrightnessFloorKeysDecodeToDefaultFifteenPercent() throws {
        let json = """
        {"batteryFloorPercent":15,"duration":"indefinite","keyboardBacklightOff":true,"applyBrightnessFloor":true,"agentSettleGrace":90,"sessionFreshness":45,"hotkey":{"keyCode":0,"option":true,"command":true,"shift":false,"control":false}}
        """
        let decoded = try JSONDecoder().decode(UserPreferences.self, from: Data(json.utf8))
        XCTAssertEqual(decoded.brightnessFloorPercent, 15)
        XCTAssertEqual(decoded.brightnessFloor, 0.15, accuracy: 0.0001)
        XCTAssertEqual(decoded.lidOpenRampSeconds, 2)
        XCTAssertEqual(decoded.agentSettleGrace, 120)
        XCTAssertTrue(decoded.thermalAutoOff)
    }

    func testLidOpenRampDefaultIsTwoSecondsAndClampsToOneTwoThree() {
        XCTAssertEqual(UserPreferences.lidOpenRampRange, 1...3)
        XCTAssertEqual(UserPreferences.default.lidOpenRampSeconds, 2)
        XCTAssertEqual(UserPreferences.clampLidOpenRamp(0), 1)
        XCTAssertEqual(UserPreferences.clampLidOpenRamp(1), 1)
        XCTAssertEqual(UserPreferences.clampLidOpenRamp(2), 2)
        XCTAssertEqual(UserPreferences.clampLidOpenRamp(3), 3)
        XCTAssertEqual(UserPreferences.clampLidOpenRamp(9), 3)
        XCTAssertEqual(UserPreferences(lidOpenRampSeconds: 1).lidOpenRampSeconds, 1)
        XCTAssertEqual(UserPreferences(lidOpenRampSeconds: 3).lidOpenRampSeconds, 3)
        XCTAssertEqual(UserPreferences(lidOpenRampSeconds: 0).lidOpenRampSeconds, 1)
        XCTAssertEqual(UserPreferences(lidOpenRampSeconds: 4).lidOpenRampSeconds, 3)
        XCTAssertEqual(HygieneRestore.lidOpenRampDuration, 2)
        XCTAssertEqual(HygieneRestore.lidOpenRampDuration(seconds: 1), 1)
        XCTAssertEqual(HygieneRestore.lidOpenRampDuration(seconds: 2), 2)
        XCTAssertEqual(HygieneRestore.lidOpenRampDuration(seconds: 3), 3)
        XCTAssertEqual(HygieneRestore.lidOpenRampDuration(seconds: 0), 1)
        XCTAssertEqual(HygieneRestore.lidOpenRampDuration(seconds: 9), 3)
    }

    func testLidOpenRampPersistsAndDecodedOvershootClamps() throws {
        let prefs = UserPreferences(lidOpenRampSeconds: 3)
        let loaded = try roundTrip(prefs)
        XCTAssertEqual(loaded.lidOpenRampSeconds, 3)

        let decoded = try JSONDecoder().decode(
            UserPreferences.self,
            from: Data(fixtureJSON(lidOpenRampSeconds: 11).utf8)
        )
        XCTAssertEqual(decoded.lidOpenRampSeconds, 3)
    }

    func testBundleRoundTripKeepsFloorGraceAndRamp() throws {
        var prefs = UserPreferences(
            brightnessFloorPercent: 20,
            agentSettleGrace: 120,
            lidOpenRampSeconds: 1
        )
        XCTAssertTrue(prefs.applyHotkeyRemap(HotkeyChord(keyCode: 13, option: true, command: true)))
        prefs.duration = .customMinutes(33)
        prefs.batteryFloorPercent = 80
        let loaded = try roundTrip(prefs)
        XCTAssertEqual(loaded.brightnessFloorPercent, 20)
        XCTAssertEqual(loaded.brightnessFloor, 0.20, accuracy: 0.0001)
        XCTAssertEqual(loaded.agentSettleGrace, 120)
        XCTAssertEqual(loaded.lidOpenRampSeconds, 1)
        XCTAssertEqual(loaded.batteryFloorPercent, 80)
        XCTAssertEqual(loaded.duration, .custom(minutes: 33))
        XCTAssertEqual(loaded.hotkey.display, "⌥⌘W")
        XCTAssertTrue(loaded.thermalAutoOff)
    }

    func testAgentsSettleUsesPreferenceGraceNotHardcodedDefault() {
        var prefs = UserPreferences(agentSettleGrace: 180)
        prefs.duration = .untilAgentsSettle
        prefs.notifEnabled = true
        var engine = WatchEngine(preferences: prefs)
        _ = engine.userSetEngaged(true, now: t0, lidClosed: false)
        XCTAssertTrue(
            engine.tick(now: t0, safety: .acPower, agents: .busy).isEmpty
        )
        XCTAssertTrue(
            engine.tick(now: t0.addingTimeInterval(179), safety: .acPower, agents: .idle).isEmpty
        )
        XCTAssertEqual(
            engine.tick(now: t0.addingTimeInterval(180), safety: .acPower, agents: .idle),
            [.postIdleAfterWaitNotif]
        )
        XCTAssertTrue(engine.engaged)
        XCTAssertEqual(engine.preferences.duration, .untilAgentsSettle)
    }

    func testShorteningSettleGraceWhileArmedUsesTheNewWindow() {
        var prefs = UserPreferences(agentSettleGrace: 300)
        prefs.duration = .untilAgentsSettle
        prefs.notifEnabled = true
        var engine = WatchEngine(preferences: prefs)
        _ = engine.userSetEngaged(true, now: t0, lidClosed: false)
        XCTAssertTrue(engine.tick(now: t0, safety: .acPower, agents: .busy).isEmpty)
        XCTAssertTrue(
            engine.tick(now: t0.addingTimeInterval(150), safety: .acPower, agents: .idle).isEmpty
        )
        engine.userSetAgentSettleGrace(120)
        XCTAssertEqual(engine.preferences.agentSettleGrace, 120)
        XCTAssertEqual(
            engine.tick(now: t0.addingTimeInterval(150), safety: .acPower, agents: .idle),
            [.postIdleAfterWaitNotif]
        )
        XCTAssertTrue(engine.engaged)
    }

    func testShorteningSettleGraceBelowTwoMinutesClampsUp() {
        var prefs = UserPreferences.default
        prefs.duration = .untilAgentsSettle
        var engine = WatchEngine(preferences: prefs)
        _ = engine.userSetEngaged(true, now: t0, lidClosed: false)
        XCTAssertTrue(engine.tick(now: t0, safety: .acPower, agents: .busy).isEmpty)
        XCTAssertTrue(
            engine.tick(now: t0.addingTimeInterval(40), safety: .acPower, agents: .idle).isEmpty
        )
        engine.userSetAgentSettleGrace(30)
        XCTAssertEqual(engine.preferences.agentSettleGrace, 120)
        XCTAssertTrue(
            engine.tick(now: t0.addingTimeInterval(40), safety: .acPower, agents: .idle).isEmpty
        )
    }

    func testCorePrefsChromeMatchesClamps() {
        XCTAssertEqual(BrightnessFloorPercentChrome.minPercent, 1)
        XCTAssertEqual(BrightnessFloorPercentChrome.maxPercent, 40)
        XCTAssertEqual(BrightnessFloorPercentChrome.minLabel, "1%")
        XCTAssertEqual(BrightnessFloorPercentChrome.maxLabel, "40%")
        XCTAssertEqual(AgentSettleGraceChrome.minSeconds, 120)
        XCTAssertEqual(AgentSettleGraceChrome.maxSeconds, 900)
        XCTAssertEqual(AgentSettleGraceChrome.minLabel, "2m")
        XCTAssertNotEqual(AgentSettleGraceChrome.minLabel, "120s")
        XCTAssertEqual(AgentSettleGraceChrome.maxLabel, "15m")
        XCTAssertEqual(LidOpenRampChrome.titles, ["1s", "2s", "3s"])
        XCTAssertEqual(LidOpenRampChrome.selectedSegment(seconds: 2), 1)
        XCTAssertEqual(LidOpenRampChrome.seconds(selectingSegment: 0), 1)
        XCTAssertEqual(LidOpenRampChrome.seconds(selectingSegment: 2), 3)
        XCTAssertNil(LidOpenRampChrome.seconds(selectingSegment: 3))
        XCTAssertFalse(AgrypnosCopy.settleGrace.lowercased().contains("settle grace"))
        XCTAssertFalse(AgrypnosCopy.lidOpenRamp.lowercased().contains("lid-open ramp"))
    }

    func testDefaultSessionFreshnessIsFortyFiveSecondsNotASecondSettle() {
        XCTAssertEqual(UserPreferences.defaultSessionFreshness, 45)
        XCTAssertEqual(UserPreferences.default.sessionFreshness, 45)
        XCTAssertEqual(AgentHeuristicConfig().sessionFreshness, 45)
        XCTAssertEqual(UserPreferences.clampSessionFreshness(45), 45)
        XCTAssertEqual(UserPreferences.clampSessionFreshness(10), 15)
        XCTAssertEqual(UserPreferences.clampSessionFreshness(120), 120)
        XCTAssertEqual(UserPreferences.clampSessionFreshness(900), 45)
        XCTAssertEqual(UserPreferences.clampSessionFreshness(1_800), 45)
    }

    func testStoredFortyFiveSecondFreshnessDoesNotBecomeFifteenMinutes() throws {
        let loaded = try JSONDecoder().decode(
            UserPreferences.self,
            from: Data(fixtureJSON().utf8)
        )
        XCTAssertEqual(loaded.sessionFreshness, 45)
    }

    private func roundTrip(_ prefs: UserPreferences) throws -> UserPreferences {
        let data = try JSONEncoder().encode(prefs)
        return try JSONDecoder().decode(UserPreferences.self, from: data)
    }

    private func fixtureJSON(
        brightnessFloorPercent: Int = 15,
        agentSettleGrace: TimeInterval = 120,
        lidOpenRampSeconds: Int = 2
    ) -> String {
        """
        {"batteryFloorPercent":15,"duration":"indefinite","keyboardBacklightOff":true,"applyBrightnessFloor":true,"brightnessFloorPercent":\(brightnessFloorPercent),"agentSettleGrace":\(Int(agentSettleGrace)),"sessionFreshness":45,"lidOpenRampSeconds":\(lidOpenRampSeconds),"hotkey":{"keyCode":0,"option":true,"command":true,"shift":false,"control":false}}
        """
    }

    private func legacyFractionJSON(brightnessFloor: Double) -> String {
        """
        {"batteryFloorPercent":15,"duration":"indefinite","keyboardBacklightOff":true,"applyBrightnessFloor":true,"brightnessFloor":\(brightnessFloor),"agentSettleGrace":90,"sessionFreshness":45,"hotkey":{"keyCode":0,"option":true,"command":true,"shift":false,"control":false}}
        """
    }
}

private extension SafetyInputs {
    static let acPower = SafetyInputs(
        batteryPercent: 90,
        onBatteryDischarging: false,
        thermalSerious: false,
        lowPowerMode: false
    )
}

private extension AgentSnapshot {
    static let idle = AgentSnapshot(reports: [])
    static let busy = AgentSnapshot(reports: [
        AgentReport(
            kind: .claudeCode,
            processRunning: true,
            cpuBusy: true,
            recentSessionWrite: true,
            isBusy: true
        )
    ])
}
