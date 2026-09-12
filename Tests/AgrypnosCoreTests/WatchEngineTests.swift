import XCTest
@testable import AgrypnosCore

final class WatchEngineTests: XCTestCase {
    let t0 = Date(timeIntervalSince1970: 10_000)

    func testToggleOnEmitsEngageAndHygieneOnce() {
        var engine = WatchEngine(preferences: .default)
        let commands = engine.userSetEngaged(true, now: t0)
        XCTAssertTrue(engine.engaged)
        XCTAssertEqual(commands.first, .engage)
        XCTAssertTrue(commands.contains(.requestDisplaySleep))
        XCTAssertTrue(commands.contains(.requestKeyboardBacklightOff))
        XCTAssertTrue(commands.contains(.applyBrightnessFloor))

        let secondTick = engine.tick(
            now: t0.addingTimeInterval(5),
            safety: .acPower,
            agents: .idle
        )
        XCTAssertTrue(secondTick.isEmpty)
    }

    func testToggleOffIsUserDisengage() {
        var engine = WatchEngine(preferences: .default)
        _ = engine.userSetEngaged(true, now: t0)
        XCTAssertEqual(engine.userSetEngaged(false, now: t0.addingTimeInterval(1)), [.disengage(.user)])
        XCTAssertFalse(engine.engaged)
    }

    func testTimedWatchExpires() {
        var prefs = UserPreferences.default
        prefs.duration = .oneHour
        var engine = WatchEngine(preferences: prefs)
        _ = engine.userSetEngaged(true, now: t0)
        XCTAssertEqual(
            engine.tick(now: t0.addingTimeInterval(3600), safety: .acPower, agents: .idle),
            [.disengage(.timerExpired)]
        )
        XCTAssertFalse(engine.engaged)
    }

    func testAgentsModeHoldsUntilSettled() {
        var prefs = UserPreferences.default
        prefs.duration = .untilAgentsSettle
        var engine = WatchEngine(preferences: prefs)
        _ = engine.userSetEngaged(true, now: t0)

        XCTAssertTrue(engine.tick(now: t0.addingTimeInterval(10), safety: .acPower, agents: .idle).isEmpty)

        XCTAssertTrue(
            engine.tick(
                now: t0.addingTimeInterval(20),
                safety: .acPower,
                agents: AgentSnapshot(reports: [
                    AgentReport(kind: .claudeCode, processRunning: true, cpuBusy: true, recentSessionWrite: true, isBusy: true)
                ])
            ).isEmpty
        )

        XCTAssertTrue(
            engine.tick(
                now: t0.addingTimeInterval(20 + 89),
                safety: .acPower,
                agents: .idle
            ).isEmpty
        )

        XCTAssertEqual(
            engine.tick(
                now: t0.addingTimeInterval(20 + 90),
                safety: .acPower,
                agents: .idle
            ),
            [.disengage(.agentsSettled)]
        )
    }

    func testLidCloseReappliesHygieneWhileEngaged() {
        var engine = WatchEngine(preferences: .default)
        XCTAssertTrue(engine.lidDidClose(now: t0).isEmpty)
        _ = engine.userSetEngaged(true, now: t0)
        let cmds = engine.lidDidClose(now: t0.addingTimeInterval(1))
        XCTAssertTrue(cmds.contains(.requestDisplaySleep))
        XCTAssertTrue(cmds.contains(.requestKeyboardBacklightOff))
        XCTAssertTrue(cmds.contains(.applyBrightnessFloor))
        XCTAssertFalse(cmds.contains(.engage))
    }

    func testBatteryFloorDisengages() {
        var engine = WatchEngine(preferences: .default)
        _ = engine.userSetEngaged(true, now: t0)
        XCTAssertEqual(
            engine.tick(
                now: t0.addingTimeInterval(1),
                safety: SafetyInputs(batteryPercent: 12, onBatteryDischarging: true, thermalSerious: false, lowPowerMode: false),
                agents: .idle
            ),
            [.disengage(.batteryFloor)]
        )
    }

    func testThermalTickDisengages() {
        var engine = WatchEngine(preferences: .default)
        _ = engine.userSetEngaged(true, now: t0)
        XCTAssertEqual(
            engine.tick(
                now: t0.addingTimeInterval(1),
                safety: SafetyInputs(batteryPercent: 90, onBatteryDischarging: false, thermalSerious: true, lowPowerMode: false),
                agents: .idle
            ),
            [.disengage(.thermal)]
        )
    }

    func testChangingDurationWhileOnResetsTimer() {
        var engine = WatchEngine(preferences: .default)
        _ = engine.userSetEngaged(true, now: t0)
        _ = engine.userSetDuration(.oneHour, now: t0)
        XCTAssertEqual(engine.timerEnd, t0.addingTimeInterval(3600))
        XCTAssertTrue(
            engine.tick(now: t0.addingTimeInterval(10), safety: .acPower, agents: .idle).isEmpty
        )
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
