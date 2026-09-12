import XCTest
@testable import AgrypnosCore

final class WatchEngineTests: XCTestCase {
    let t0 = Date(timeIntervalSince1970: 10_000)

    func testToggleOnArmsWithoutBlankingThePanel() {
        var engine = WatchEngine(preferences: .default)
        let commands = engine.userSetEngaged(true, now: t0, lidClosed: false)
        XCTAssertTrue(engine.engaged)
        XCTAssertEqual(commands, [.engage])
        XCTAssertFalse(commands.contains(.requestDisplaySleep))
        XCTAssertFalse(commands.contains(.requestKeyboardBacklightOff))
        XCTAssertFalse(commands.contains(.applyBrightnessFloor))
        XCTAssertFalse(engine.lidHygieneApplied)

        let secondTick = engine.tick(
            now: t0.addingTimeInterval(5),
            safety: .acPower,
            agents: .idle
        )
        XCTAssertTrue(secondTick.isEmpty)
        XCTAssertTrue(engine.engaged)
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

    func testAdoptLeftoverArmsWithoutBlankingWhenLidIsOpen() {
        var engine = WatchEngine(preferences: .default)
        let commands = engine.adoptLeftoverKernel(now: t0, lidClosed: false)
        XCTAssertTrue(engine.engaged)
        XCTAssertTrue(engine.leftoverAdopted)
        XCTAssertEqual(commands, [.engage])
        XCTAssertFalse(engine.lidHygieneApplied)
    }

    func testAdoptLeftoverWhileEngagedWithLidOpenDoesNotBlank() {
        var engine = WatchEngine(preferences: .default)
        _ = engine.userSetEngaged(true, now: t0, lidClosed: false)
        XCTAssertFalse(engine.leftoverAdopted)
        let commands = engine.adoptLeftoverKernel(now: t0.addingTimeInterval(1), lidClosed: false)
        XCTAssertTrue(engine.leftoverAdopted)
        XCTAssertTrue(engine.engaged)
        XCTAssertTrue(commands.isEmpty)
        XCTAssertFalse(engine.lidHygieneApplied)
    }

    func testUserEngageClearsLeftoverFlag() {
        var engine = WatchEngine(preferences: .default)
        _ = engine.adoptLeftoverKernel(now: t0)
        XCTAssertTrue(engine.leftoverAdopted)
        _ = engine.userSetEngaged(false, now: t0.addingTimeInterval(1))
        XCTAssertFalse(engine.leftoverAdopted)
        XCTAssertFalse(engine.engaged)
    }

    func testLidCloseFloorsBrightnessAndKillsKeyboardWithoutDisplaySleep() {
        var engine = WatchEngine(preferences: .default)
        XCTAssertTrue(engine.lidDidClose(now: t0).isEmpty)
        _ = engine.userSetEngaged(true, now: t0, lidClosed: false)
        let cmds = engine.lidDidClose(now: t0.addingTimeInterval(1))
        XCTAssertEqual(cmds, [.applyBrightnessFloor, .requestKeyboardBacklightOff])
        XCTAssertFalse(cmds.contains(.requestDisplaySleep))
        XCTAssertFalse(cmds.contains(.engage))
        XCTAssertTrue(engine.lidHygieneApplied)
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
