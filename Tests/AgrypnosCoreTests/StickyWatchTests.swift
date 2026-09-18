import XCTest
@testable import AgrypnosCore

final class StickyWatchTests: XCTestCase {
    let t0 = Date(timeIntervalSince1970: 10_000)

    func testAgentsIdleKeepsTheWatchOnAndLeavesDurationAlone() {
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
        XCTAssertFalse(commands.contains { if case .disengage = $0 { return true }; return false })
        XCTAssertTrue(engine.engaged)
        XCTAssertEqual(engine.preferences.duration, .untilAgentsSettle)
        XCTAssertNil(engine.preferences.lastWatchEnd)
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
        _ = engine.tick(now: t0.addingTimeInterval(10 + 120), safety: .acPower, agents: .idle)
        XCTAssertTrue(engine.engaged)
        XCTAssertEqual(engine.preferences.duration, .untilAgentsSettle)

        let open = engine.lidDidOpen(now: t0.addingTimeInterval(11))
        XCTAssertFalse(open.contains { if case .disengage = $0 { return true }; return false })
        let afterOpen = engine.tick(
            now: t0.addingTimeInterval(11 + 120),
            safety: .acPower,
            agents: .idle
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

    func testAgentsSettleCanPostWithoutDisengage() {
        var prefs = UserPreferences.default
        prefs.duration = .untilAgentsSettle
        prefs.notifEnabled = true
        var engine = WatchEngine(preferences: prefs)
        _ = engine.userSetEngaged(true, now: t0)
        XCTAssertTrue(engine.tick(now: t0.addingTimeInterval(20), safety: .acPower, agents: .busy).isEmpty)
        XCTAssertEqual(
            engine.tick(now: t0.addingTimeInterval(20 + 120), safety: .acPower, agents: .idle),
            [.postIdleAfterWaitNotif]
        )
        XCTAssertTrue(engine.engaged)
        XCTAssertTrue(engine.postedThisUserArm)
        XCTAssertEqual(engine.preferences.duration, .untilAgentsSettle)
        XCTAssertTrue(
            engine.tick(now: t0.addingTimeInterval(20 + 180), safety: .acPower, agents: .idle).isEmpty
        )
    }

    func testTimerAndAgentsIdleDoNotCountAsTurningTheWatchOff() {
        XCTAssertFalse(DisengageReason.timerExpired.turnsWatchOff)
        XCTAssertFalse(DisengageReason.agentsSettled.turnsWatchOff)
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
