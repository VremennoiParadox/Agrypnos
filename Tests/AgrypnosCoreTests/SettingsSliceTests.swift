import XCTest
@testable import AgrypnosCore

final class SettingsSliceTests: XCTestCase {
    let t0 = Date(timeIntervalSince1970: 10_000)

    func testBatteryFloorClampsTo5Through100() {
        XCTAssertEqual(UserPreferences.default.batteryFloorPercent, 15)
        XCTAssertEqual(UserPreferences(batteryFloorPercent: 4).batteryFloorPercent, 5)
        XCTAssertEqual(UserPreferences(batteryFloorPercent: 5).batteryFloorPercent, 5)
        XCTAssertEqual(UserPreferences(batteryFloorPercent: 80).batteryFloorPercent, 80)
        XCTAssertEqual(UserPreferences(batteryFloorPercent: 100).batteryFloorPercent, 100)
        XCTAssertEqual(UserPreferences(batteryFloorPercent: 101).batteryFloorPercent, 100)
    }

    func testBatteryFloor100PersistsAndDecodedOvershootClamps() throws {
        let prefs = UserPreferences(batteryFloorPercent: 100)
        let loaded = try roundTrip(prefs)
        XCTAssertEqual(loaded.batteryFloorPercent, 100)

        let json = fixtureJSON(batteryFloorPercent: 150, duration: "oneHour")
        let decoded = try JSONDecoder().decode(UserPreferences.self, from: Data(json.utf8))
        XCTAssertEqual(decoded.batteryFloorPercent, 100)
    }

    func testBatteryFloor100FiresOnlyWhileDischarging() {
        let atFloor = AutoOffEvaluator.reason(
            engaged: true,
            timerEnd: nil,
            safety: SafetyInputs(
                batteryPercent: 100,
                onBatteryDischarging: true,
                thermalSerious: false,
                lowPowerMode: false
            ),
            batteryFloorPercent: 100,
            userForcedThisSession: true
        )
        XCTAssertEqual(atFloor, .batteryFloor)

        let onAC = AutoOffEvaluator.reason(
            engaged: true,
            timerEnd: nil,
            safety: SafetyInputs(
                batteryPercent: 10,
                onBatteryDischarging: false,
                thermalSerious: false,
                lowPowerMode: false
            ),
            batteryFloorPercent: 100,
            userForcedThisSession: true
        )
        XCTAssertNil(onAC)
    }

    func testCustomMinutesAreThirtyThreeAndNotAPreset() {
        let option = DurationOption.customMinutes(33)
        XCTAssertEqual(option, .custom(minutes: 33))
        XCTAssertEqual(option.minutes, 33)
        XCTAssertEqual(option.segmentTitle, "33m")
        XCTAssertEqual(DurationOption.presets.count, 4)
        XCTAssertFalse(DurationOption.presets.contains(option))
        XCTAssertEqual(DurationOption.presets.map(\.segmentTitle), ["∞", "1h", "3h", "Agents"])
        XCTAssertEqual(DurationOption.customMinutes(0).minutes, 1)
        XCTAssertEqual(DurationOption.customMinutes(-4).minutes, 1)
    }

    func testCustomMinutesPersistAndLegacyStringDurationStillDecodes() throws {
        var prefs = UserPreferences.default
        prefs.duration = .customMinutes(33)
        let loaded = try roundTrip(prefs)
        XCTAssertEqual(loaded.duration, .custom(minutes: 33))
        XCTAssertEqual(loaded.duration.minutes, 33)

        let legacy = fixtureJSON(batteryFloorPercent: 15, duration: "threeHours")
        let decoded = try JSONDecoder().decode(UserPreferences.self, from: Data(legacy.utf8))
        XCTAssertEqual(decoded.duration, .threeHours)
        XCTAssertEqual(decoded.duration.minutes, 180)
    }

    func testCustomWatchExpiresAfterThoseMinutes() {
        var prefs = UserPreferences.default
        prefs.duration = .customMinutes(33)
        var engine = WatchEngine(preferences: prefs)
        _ = engine.userSetEngaged(true, now: t0)
        XCTAssertEqual(engine.mode, .timed)
        XCTAssertEqual(engine.timerEnd, t0.addingTimeInterval(33 * 60))
        XCTAssertTrue(
            engine.tick(
                now: t0.addingTimeInterval(32 * 60),
                safety: .acPower,
                agents: .idle
            ).isEmpty
        )
        XCTAssertEqual(
            engine.tick(
                now: t0.addingTimeInterval(33 * 60),
                safety: .acPower,
                agents: .idle
            ),
            [.disengage(.timerExpired)]
        )
    }

    func testChangingToCustomMinutesWhileArmedResetsTimer() {
        var engine = WatchEngine(preferences: .default)
        _ = engine.userSetEngaged(true, now: t0)
        XCTAssertNil(engine.timerEnd)
        _ = engine.userSetDuration(.customMinutes(33), now: t0)
        XCTAssertEqual(engine.timerEnd, t0.addingTimeInterval(33 * 60))
        XCTAssertEqual(engine.preferences.duration, .custom(minutes: 33))
    }

    func testTimedHintTreatsCustomMinutesLikeOtherTimers() {
        XCTAssertEqual(
            AgrypnosCopy.durationHint(option: .customMinutes(33), engaged: false, remainingSeconds: nil),
            AgrypnosCopy.timedHint
        )
        XCTAssertEqual(
            AgrypnosCopy.durationHint(option: .customMinutes(33), engaged: true, remainingSeconds: 125),
            "Auto-off in 2:05"
        )
    }

    func testRemappedHotkeyPersistsAndDefaultStaysOptionCommandA() throws {
        XCTAssertEqual(UserPreferences.default.hotkey, .defaultToggle)
        XCTAssertEqual(UserPreferences.default.hotkey.display, "⌥⌘A")

        var prefs = UserPreferences.default
        let remap = HotkeyChord(keyCode: 1, option: true, command: true)
        XCTAssertTrue(remap.isBindable)
        XCTAssertTrue(prefs.applyHotkeyRemap(remap))
        XCTAssertEqual(prefs.hotkey, remap)
        XCTAssertEqual(prefs.hotkey.display, "⌥⌘S")

        let loaded = try roundTrip(prefs)
        XCTAssertEqual(loaded.hotkey, remap)
        XCTAssertEqual(loaded.hotkey.display, "⌥⌘S")
        XCTAssertEqual(loaded.duration, .indefinite)
        XCTAssertEqual(loaded.batteryFloorPercent, 15)
    }

    func testModifierlessAndShiftOnlyChordsAreRejectedAndNotPersisted() {
        var prefs = UserPreferences.default
        let naked = HotkeyChord(keyCode: 0, option: false, command: false)
        let shiftOnly = HotkeyChord(keyCode: 0, option: false, command: false, shift: true)
        XCTAssertFalse(naked.isBindable)
        XCTAssertFalse(shiftOnly.isBindable)
        XCTAssertFalse(prefs.applyHotkeyRemap(naked))
        XCTAssertFalse(prefs.applyHotkeyRemap(shiftOnly))
        XCTAssertEqual(prefs.hotkey, .defaultToggle)
    }

    func testBindFailureCopyDoesNotClaimTheChordIsLive() {
        let remap = HotkeyChord(keyCode: 1, option: true, command: true)
        let failed = AgrypnosCopy.hotkeyHint(remap, registered: false)
        XCTAssertTrue(failed.contains("⌥⌘S"))
        XCTAssertFalse(failed.lowercased().contains("toggles the watch"))
        XCTAssertTrue(failed.lowercased().contains("not registered") || failed.lowercased().contains("isn’t registered"))
        XCTAssertEqual(AgrypnosCopy.hotkeyHint(remap, registered: true), "⌥⌘S toggles the watch")
    }

    func testSettingsBundleRoundTripKeepsRemapCustomMinutesAndBattery() throws {
        var prefs = UserPreferences(batteryFloorPercent: 80)
        XCTAssertTrue(prefs.applyHotkeyRemap(HotkeyChord(keyCode: 13, option: true, command: true)))
        prefs.duration = .customMinutes(33)
        let loaded = try roundTrip(prefs)
        XCTAssertEqual(loaded.batteryFloorPercent, 80)
        XCTAssertEqual(loaded.duration, .custom(minutes: 33))
        XCTAssertEqual(loaded.hotkey.display, "⌥⌘W")
    }

    private func roundTrip(_ prefs: UserPreferences) throws -> UserPreferences {
        let data = try JSONEncoder().encode(prefs)
        return try JSONDecoder().decode(UserPreferences.self, from: data)
    }

    private func fixtureJSON(batteryFloorPercent: Int, duration: String) -> String {
        """
        {"batteryFloorPercent":\(batteryFloorPercent),"duration":"\(duration)","keyboardBacklightOff":true,"applyBrightnessFloor":true,"brightnessFloor":0.15,"agentSettleGrace":90,"sessionFreshness":45,"hotkey":{"keyCode":0,"option":true,"command":true,"shift":false,"control":false}}
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
}
