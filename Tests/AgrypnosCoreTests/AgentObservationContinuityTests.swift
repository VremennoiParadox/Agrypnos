import XCTest
@testable import AgrypnosCore

final class AgentObservationContinuityTests: XCTestCase {
    let t0 = Date(timeIntervalSince1970: 10_000)
    let safe = SafetyInputs(batteryPercent: 90, onBatteryDischarging: false, thermalSerious: false, lowPowerMode: false)
    let busy = AgentSnapshot(reports: [
        AgentReport(kind: .cursor, processRunning: true, cpuBusy: false, recentSessionWrite: true, isBusy: true)
    ])
    let idle = AgentSnapshot(reports: [])

    func armed() -> WatchEngine {
        var prefs = UserPreferences.default
        prefs.duration = .untilAgentsSettle
        prefs.notifEnabled = true
        var engine = WatchEngine(preferences: prefs)
        _ = engine.userSetEngaged(true, now: t0)
        _ = engine.tick(now: t0, safety: safe, agents: busy)
        return engine
    }

    func testFirstIdleAfterOneHourGapDoesNotSettle() {
        var engine = armed()
        _ = engine.lidDidClose(now: t0)
        let commands = engine.tick(now: t0.addingTimeInterval(3600), safety: safe, agents: idle)
        XCTAssertTrue(commands.isEmpty)
        XCTAssertTrue(engine.engaged)
        XCTAssertTrue(engine.settle.sawBusy)
        XCTAssertEqual(engine.settle.lastBusyAt, t0)
        XCTAssertNil(engine.preferences.lastWatchEnd)
    }

    func testLongGapRequiresFullGraceAgain() {
        var engine = armed()
        for second in stride(from: 3600, through: 3715, by: 5) {
            XCTAssertTrue(engine.tick(now: t0.addingTimeInterval(Double(second)), safety: safe, agents: idle).isEmpty)
        }
        XCTAssertEqual(
            engine.tick(now: t0.addingTimeInterval(3720), safety: safe, agents: idle),
            [.disengage(.agentsSettled), .postIdleAfterWaitNotif]
        )
        XCTAssertEqual(engine.preferences.duration, .untilAgentsSettle)
        XCTAssertTrue(engine.tick(now: t0.addingTimeInterval(3725), safety: safe, agents: idle).isEmpty)
    }

    func testStatusPeekCannotReportSettledAcrossMissingObservations() {
        let engine = armed()
        XCTAssertEqual(engine.settle.activity(busy: false, now: t0.addingTimeInterval(3600)), .settling)
        XCTAssertEqual(engine.settle.lastBusyAt, t0)
    }

    func testBackwardClockRestartsWaitWithoutInventingBusy() {
        var tracker = AgentSettleTracker(grace: 120)
        _ = tracker.observe(busy: true, now: t0)
        _ = tracker.observe(busy: false, now: t0.addingTimeInterval(-1000))
        for second in stride(from: -995, through: -885, by: 5) {
            XCTAssertEqual(tracker.observe(busy: false, now: t0.addingTimeInterval(Double(second))), .settling)
        }
        XCTAssertEqual(tracker.observe(busy: false, now: t0.addingTimeInterval(-880)), .settled)
        XCTAssertEqual(tracker.lastBusyAt, t0)
    }

    func testSafetyStillWinsAfterObservationGap() {
        for (safety, reason) in [
            (SafetyInputs(batteryPercent: 2, onBatteryDischarging: true, thermalSerious: false, lowPowerMode: false), DisengageReason.batteryFloor),
            (SafetyInputs(batteryPercent: 90, onBatteryDischarging: false, thermalSerious: true, lowPowerMode: false), .thermal)
        ] {
            var engine = armed()
            XCTAssertEqual(engine.tick(now: t0.addingTimeInterval(3600), safety: safety, agents: idle), [.disengage(reason)])
            XCTAssertFalse(engine.engaged)
        }
    }
    func testInterruptedWaitRequiresFullGraceAgain() {
        var engine = armed()
        for second in stride(from: 5, through: 60, by: 5) {
            _ = engine.tick(now: t0.addingTimeInterval(Double(second)), safety: safe, agents: idle)
        }
        engine.interruptAgentObservations()
        engine.interruptAgentObservations()
        XCTAssertTrue(engine.settle.sawBusy)
        XCTAssertEqual(engine.settle.lastBusyAt, t0)
        for second in stride(from: 65, through: 180, by: 5) {
            XCTAssertTrue(engine.tick(now: t0.addingTimeInterval(Double(second)), safety: safe, agents: idle).isEmpty)
        }
        XCTAssertEqual(engine.tick(now: t0.addingTimeInterval(185), safety: safe, agents: idle),
                       [.disengage(.agentsSettled), .postIdleAfterWaitNotif])
    }

    func testNeverBusyInterruptionDoesNotInventBusy() {
        var tracker = AgentSettleTracker(grace: 120)
        tracker.interruptObservations()
        for second in stride(from: 0, through: 180, by: 5) {
            XCTAssertEqual(tracker.observe(busy: false, now: t0.addingTimeInterval(Double(second))), .quiet)
        }
        XCTAssertFalse(tracker.sawBusy)
        XCTAssertNil(tracker.lastBusyAt)
    }

    func testHealthyCadenceStillSettlesAtOriginalDeadline() {
        var engine = armed()
        for second in stride(from: 5, through: 115, by: 5) {
            XCTAssertTrue(engine.tick(now: t0.addingTimeInterval(Double(second)), safety: safe, agents: idle).isEmpty)
        }
        XCTAssertEqual(engine.tick(now: t0.addingTimeInterval(120), safety: safe, agents: idle),
                       [.disengage(.agentsSettled), .postIdleAfterWaitNotif])
    }

}
