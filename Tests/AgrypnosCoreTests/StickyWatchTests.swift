import XCTest
@testable import AgrypnosCore

final class StickyWatchTests: XCTestCase {
    let t0 = Date(timeIntervalSince1970: 10_000)

    func testAgentsIdleTurnsTheWatchOffAndLeavesDurationAlone() {
        var prefs = UserPreferences.default
        prefs.duration = .untilAgentsSettle
        var engine = WatchEngine(preferences: prefs)
        _ = engine.userSetEngaged(true, now: t0)

        XCTAssertTrue(engine.tick(now: t0.addingTimeInterval(20), safety: .acPower, agents: .busy).isEmpty)
        let commands = engine.tick(
            now: t0.addingTimeInterval(20 + 120),
            safety: .acPower,
            agents: .idle
        )
        XCTAssertEqual(commands, [.disengage(.agentsSettled)])
        XCTAssertFalse(engine.engaged)
        XCTAssertEqual(engine.preferences.duration, .untilAgentsSettle)
        XCTAssertEqual(
            engine.preferences.lastWatchEnd,
            LastWatchEnd(endedAt: t0.addingTimeInterval(20 + 120), reason: .agentsSettled)
        )
    }

    func testTimerEndKeepsTheWatchOnAndLeavesDurationAlone() {
        var prefs = UserPreferences.default
        prefs.duration = .customMinutes(33)
        var engine = WatchEngine(preferences: prefs)
        _ = engine.userSetEngaged(true, now: t0)
        let commands = engine.tick(
            now: t0.addingTimeInterval(33 * 60),
            safety: .acPower,
            agents: .idle
        )
        XCTAssertTrue(commands.isEmpty)
        XCTAssertTrue(engine.engaged)
        XCTAssertEqual(engine.preferences.duration, .custom(minutes: 33))
        XCTAssertNil(engine.preferences.lastWatchEnd)
    }

    func testLidCloseOpenDoesNotDisengageOrChangeDuration() {
        var prefs = UserPreferences.default
        prefs.duration = .untilAgentsSettle
        var engine = WatchEngine(preferences: prefs)
        _ = engine.userSetEngaged(true, now: t0, lidClosed: false)
        _ = engine.tick(now: t0.addingTimeInterval(5), safety: .acPower, agents: .busy)
        _ = engine.lidDidClose(now: t0.addingTimeInterval(10))
        XCTAssertTrue(
            engine.tick(now: t0.addingTimeInterval(15), safety: .acPower, agents: .busy).isEmpty
        )
        XCTAssertTrue(engine.engaged)
        XCTAssertEqual(engine.preferences.duration, .untilAgentsSettle)

        let open = engine.lidDidOpen(now: t0.addingTimeInterval(16))
        XCTAssertFalse(open.contains { if case .disengage = $0 { return true }; return false })
        let afterOpen = engine.tick(
            now: t0.addingTimeInterval(20),
            safety: .acPower,
            agents: .busy
        )
        XCTAssertFalse(afterOpen.contains { if case .disengage = $0 { return true }; return false })
        XCTAssertTrue(engine.engaged)
        XCTAssertEqual(engine.preferences.duration, .untilAgentsSettle)
    }

    func testUserOffStillTurnsTheWatchOff() {
        var engine = WatchEngine(preferences: .default)
        _ = engine.userSetEngaged(true, now: t0)
        XCTAssertEqual(engine.userSetEngaged(false, now: t0.addingTimeInterval(1)), [.disengage(.user)])
        XCTAssertFalse(engine.engaged)
        XCTAssertEqual(engine.preferences.duration, .indefinite)
    }

    func testBatteryFloorStillTurnsTheWatchOff() {
        var prefs = UserPreferences.default
        prefs.duration = .untilAgentsSettle
        var engine = WatchEngine(preferences: prefs)
        _ = engine.userSetEngaged(true, now: t0)
        XCTAssertEqual(
            engine.tick(
                now: t0.addingTimeInterval(1),
                safety: SafetyInputs(
                    batteryPercent: 12,
                    onBatteryDischarging: true,
                    thermalSerious: false,
                    lowPowerMode: false
                ),
                agents: .busy
            ),
            [.disengage(.batteryFloor)]
        )
        XCTAssertFalse(engine.engaged)
        XCTAssertEqual(engine.preferences.duration, .untilAgentsSettle)
    }

    func testAgentsSettlePostsAndTurnsTheWatchOff() {
        var prefs = UserPreferences.default
        prefs.duration = .untilAgentsSettle
        prefs.notifEnabled = true
        var engine = WatchEngine(preferences: prefs)
        _ = engine.userSetEngaged(true, now: t0)
        XCTAssertTrue(engine.tick(now: t0.addingTimeInterval(20), safety: .acPower, agents: .busy).isEmpty)
        XCTAssertEqual(
            engine.tick(now: t0.addingTimeInterval(20 + 120), safety: .acPower, agents: .idle),
            [.disengage(.agentsSettled), .postIdleAfterWaitNotif]
        )
        XCTAssertFalse(engine.engaged)
        XCTAssertTrue(engine.postedThisUserArm)
        XCTAssertEqual(engine.preferences.duration, .untilAgentsSettle)
        XCTAssertTrue(
            engine.tick(now: t0.addingTimeInterval(20 + 180), safety: .acPower, agents: .idle).isEmpty
        )
    }

    func testAgentsIdleWithDroppedKernelDisengagesWithoutReasserting() {
        var prefs = UserPreferences.default
        prefs.duration = .untilAgentsSettle
        prefs.notifEnabled = true
        var engine = WatchEngine(preferences: prefs)
        _ = engine.userSetEngaged(true, now: t0)
        XCTAssertTrue(engine.tick(now: t0.addingTimeInterval(20), safety: .acPower, agents: .busy).isEmpty)
        XCTAssertEqual(
            engine.tick(
                now: t0.addingTimeInterval(20 + 120),
                safety: .acPower,
                agents: .idle,
                kernelSleepDisabled: false
            ),
            [.disengage(.agentsSettled), .postIdleAfterWaitNotif]
        )
        XCTAssertFalse(engine.engaged)
        XCTAssertEqual(engine.preferences.duration, .untilAgentsSettle)
        XCTAssertTrue(
            engine.tick(
                now: t0.addingTimeInterval(20 + 180),
                safety: .acPower,
                agents: .idle,
                kernelSleepDisabled: false
            ).isEmpty
        )
    }

    func testLeftoverTimedWatchStillAutoOffsOnLowPowerModeAfterTheClock() {
        var prefs = UserPreferences.default
        prefs.duration = .oneHour
        var engine = WatchEngine(preferences: prefs)
        _ = engine.adoptLeftoverKernel(now: t0)
        XCTAssertFalse(engine.userForcedThisSession)
        XCTAssertEqual(
            engine.tick(
                now: t0.addingTimeInterval(3600),
                safety: SafetyInputs(
                    batteryPercent: 50,
                    onBatteryDischarging: true,
                    thermalSerious: false,
                    lowPowerMode: true
                ),
                agents: .idle
            ),
            [.disengage(.lowPowerMode)]
        )
        XCTAssertEqual(engine.preferences.duration, .oneHour)
    }

    func testTimerDoesNotTurnTheWatchOffAndAgentsIdleDoes() {
        XCTAssertFalse(DisengageReason.timerExpired.turnsWatchOff)
        XCTAssertTrue(DisengageReason.agentsSettled.turnsWatchOff)
        XCTAssertFalse(DisengageReason.user.turnsWatchOff)
        XCTAssertTrue(DisengageReason.batteryFloor.turnsWatchOff)
        XCTAssertTrue(DisengageReason.thermal.turnsWatchOff)
        XCTAssertTrue(DisengageReason.lowPowerMode.turnsWatchOff)
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
