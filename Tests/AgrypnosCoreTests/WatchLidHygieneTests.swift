import XCTest
@testable import AgrypnosCore

final class WatchLidHygieneTests: XCTestCase {
    let t0 = Date(timeIntervalSince1970: 10_000)

    func testLidCloseReassertsSleepDisabledThenHygiene() {
        var engine = WatchEngine(preferences: .default)
        _ = engine.userSetEngaged(true, now: t0, lidClosed: false)
        XCTAssertEqual(
            engine.lidDidClose(now: t0.addingTimeInterval(1)),
            [.assertSleepDisabled, .applyBrightnessFloor, .requestKeyboardBacklightOff]
        )
        XCTAssertFalse(engine.lidDidClose(now: t0.addingTimeInterval(2)).contains(.requestSleep))
    }

    func testArmWithLidAlreadyClosedAppliesFloorAndKeyboard() {
        var engine = WatchEngine(preferences: .default)
        let commands = engine.userSetEngaged(true, now: t0, lidClosed: true)
        XCTAssertEqual(
            commands,
            [.engage, .assertSleepDisabled, .applyBrightnessFloor, .requestKeyboardBacklightOff]
        )
        XCTAssertTrue(engine.lidHygieneApplied)
    }

    func testSecondLidCloseIsNoOp() {
        var engine = WatchEngine(preferences: .default)
        _ = engine.userSetEngaged(true, now: t0, lidClosed: false)
        XCTAssertEqual(
            engine.lidDidClose(now: t0.addingTimeInterval(1)),
            [.assertSleepDisabled, .applyBrightnessFloor, .requestKeyboardBacklightOff]
        )
        XCTAssertTrue(engine.lidDidClose(now: t0.addingTimeInterval(2)).isEmpty)
        XCTAssertTrue(engine.lidHygieneApplied)
    }

    func testLidOpenWhileArmedRampsBrightnessAndRestoresKeyboard() {
        var engine = WatchEngine(preferences: .default)
        _ = engine.userSetEngaged(true, now: t0, lidClosed: false)
        _ = engine.lidDidClose(now: t0.addingTimeInterval(1))
        let cmds = engine.lidDidOpen(now: t0.addingTimeInterval(2))
        XCTAssertEqual(cmds, [.rampBrightnessRestore, .restoreKeyboardBacklight])
        XCTAssertFalse(engine.lidHygieneApplied)
        XCTAssertTrue(engine.engaged)
    }

    func testLidOpenWithoutPriorCloseIsNoOp() {
        var engine = WatchEngine(preferences: .default)
        _ = engine.userSetEngaged(true, now: t0, lidClosed: false)
        XCTAssertTrue(engine.lidDidOpen(now: t0.addingTimeInterval(1)).isEmpty)
        XCTAssertTrue(engine.engaged)
    }

    func testLidOpenWhileDisengagedIsNoOp() {
        var engine = WatchEngine(preferences: .default)
        XCTAssertTrue(engine.lidDidOpen(now: t0).isEmpty)
    }

    func testAdoptLeftoverWithLidClosedAppliesFloorAndKeyboard() {
        var engine = WatchEngine(preferences: .default)
        let commands = engine.adoptLeftoverKernel(now: t0, lidClosed: true)
        XCTAssertTrue(engine.engaged)
        XCTAssertTrue(engine.leftoverAdopted)
        XCTAssertEqual(commands.first, .engage)
        XCTAssertTrue(commands.contains(.assertSleepDisabled))
        XCTAssertTrue(commands.contains(.applyBrightnessFloor))
        XCTAssertTrue(commands.contains(.requestKeyboardBacklightOff))
        XCTAssertTrue(engine.lidHygieneApplied)
    }

    func testAdoptLeftoverWhileEngagedWithLidClosedReappliesFloorAndKeys() {
        var engine = WatchEngine(preferences: .default)
        _ = engine.userSetEngaged(true, now: t0, lidClosed: true)
        let commands = engine.adoptLeftoverKernel(now: t0.addingTimeInterval(1), lidClosed: true)
        XCTAssertTrue(engine.leftoverAdopted)
        XCTAssertEqual(commands, [.applyBrightnessFloor, .requestKeyboardBacklightOff])
        XCTAssertFalse(commands.contains(.engage))
    }

    func testAgentsModeStaysArmedAcrossLidCloseOpen() {
        var prefs = UserPreferences.default
        prefs.duration = .untilAgentsSettle
        var engine = WatchEngine(preferences: prefs)
        _ = engine.userSetEngaged(true, now: t0, lidClosed: false)
        _ = engine.lidDidClose(now: t0.addingTimeInterval(1))
        _ = engine.lidDidOpen(now: t0.addingTimeInterval(2))
        XCTAssertTrue(engine.engaged)
        XCTAssertTrue(
            engine.tick(now: t0.addingTimeInterval(10), safety: .acPower, agents: .idle).isEmpty
        )
    }

    func testLidHygieneHonorsPreferenceToggles() {
        var prefs = UserPreferences.default
        prefs.applyBrightnessFloor = false
        prefs.keyboardBacklightOff = false
        var engine = WatchEngine(preferences: prefs)
        _ = engine.userSetEngaged(true, now: t0, lidClosed: false)
        XCTAssertEqual(
            engine.lidDidClose(now: t0.addingTimeInterval(1)),
            [.assertSleepDisabled]
        )
        XCTAssertTrue(engine.lidDidOpen(now: t0.addingTimeInterval(2)).isEmpty)
    }

    func testDisengageClearsLidHygiene() {
        var engine = WatchEngine(preferences: .default)
        _ = engine.userSetEngaged(true, now: t0, lidClosed: true)
        XCTAssertTrue(engine.lidHygieneApplied)
        XCTAssertEqual(
            engine.userSetEngaged(false, now: t0.addingTimeInterval(1), lidClosed: true),
            [.disengage(.user)]
        )
        XCTAssertFalse(engine.engaged)
        XCTAssertFalse(engine.lidHygieneApplied)
    }

    func testAgentsIdleWithLidClosedTurnsWatchOffAndRequestsSleep() {
        var prefs = UserPreferences.default
        prefs.duration = .untilAgentsSettle
        var engine = WatchEngine(preferences: prefs)
        _ = engine.userSetEngaged(true, now: t0, lidClosed: true)
        XCTAssertTrue(
            engine.tick(
                now: t0,
                safety: .acPower,
                agents: AgentSnapshot(reports: [
                    AgentReport(
                        kind: .claudeCode,
                        processRunning: true,
                        cpuBusy: true,
                        recentSessionWrite: true,
                        isBusy: true
                    )
                ])
            ).isEmpty
        )
        XCTAssertEqual(
            engine.tick(now: t0.addingTimeInterval(120), safety: .acPower, agents: .idle),
            [.disengage(.agentsSettled), .requestSleep]
        )
        XCTAssertFalse(engine.engaged)
        XCTAssertEqual(engine.preferences.duration, .untilAgentsSettle)
    }

    func testTimerEndWithLidClosedDoesNotSleepTheMac() {
        var prefs = UserPreferences.default
        prefs.duration = .oneHour
        var engine = WatchEngine(preferences: prefs)
        _ = engine.userSetEngaged(true, now: t0, lidClosed: true)
        XCTAssertTrue(
            engine.tick(now: t0.addingTimeInterval(3600), safety: .acPower, agents: .idle).isEmpty
        )
        XCTAssertTrue(engine.engaged)
        XCTAssertEqual(engine.preferences.duration, .oneHour)
    }

    func testStayArmedAcrossLidOpenAfterTheClock() {
        var prefs = UserPreferences.default
        prefs.duration = .oneHour
        var engine = WatchEngine(preferences: prefs)
        _ = engine.userSetEngaged(true, now: t0, lidClosed: false)
        _ = engine.lidDidClose(now: t0.addingTimeInterval(10))
        _ = engine.lidDidOpen(now: t0.addingTimeInterval(20))
        XCTAssertTrue(engine.engaged)
        XCTAssertTrue(
            engine.tick(now: t0.addingTimeInterval(30), safety: .acPower, agents: .idle).isEmpty
        )
        XCTAssertTrue(
            engine.tick(now: t0.addingTimeInterval(3600), safety: .acPower, agents: .idle).isEmpty
        )
        XCTAssertTrue(engine.engaged)
        XCTAssertEqual(engine.preferences.duration, .oneHour)
    }

    func testBatteryFloorWithLidClosedRequestsSleep() {
        var engine = WatchEngine(preferences: .default)
        _ = engine.userSetEngaged(true, now: t0, lidClosed: true)
        XCTAssertEqual(
            engine.tick(
                now: t0.addingTimeInterval(1),
                safety: SafetyInputs(
                    batteryPercent: 12,
                    onBatteryDischarging: true,
                    thermalSerious: false,
                    lowPowerMode: false
                ),
                agents: .idle
            ),
            [.disengage(.batteryFloor), .requestSleep]
        )
        XCTAssertEqual(engine.preferences.duration, .indefinite)
    }

    func testPreferencesDecodeIgnoresUnknownForceDisplaySleepKey() throws {
        let json = """
        {"batteryFloorPercent":20,"duration":"oneHour","forceDisplaySleep":true,"keyboardBacklightOff":false,"applyBrightnessFloor":true,"brightnessFloor":0.2,"agentSettleGrace":90,"sessionFreshness":45,"hotkey":{"keyCode":0,"option":true,"command":true,"shift":false,"control":false}}
        """
        let prefs = try JSONDecoder().decode(UserPreferences.self, from: Data(json.utf8))
        XCTAssertEqual(prefs.batteryFloorPercent, 20)
        XCTAssertEqual(prefs.duration, .oneHour)
        XCTAssertFalse(prefs.keyboardBacklightOff)
        XCTAssertEqual(prefs.brightnessFloor, 0.2)
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
