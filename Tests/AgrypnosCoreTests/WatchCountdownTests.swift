import XCTest
@testable import AgrypnosCore

final class WatchCountdownTests: XCTestCase {
    let start = Date(timeIntervalSince1970: 10_000)
    let safe = SafetyInputs(batteryPercent: 90, onBatteryDischarging: false,
                            thermalSerious: false, lowPowerMode: false)
    let idle = AgentSnapshot(reports: [])

    func testTimedChoicesExpireAtTheirDeadlineAndKeepTheSelection() {
        let cases: [(DurationOption, TimeInterval)] = [(.oneHour, 3600), (.threeHours, 10800), (.customMinutes(33), 1980)]
        for (option, seconds) in cases {
            var engine = WatchEngine(preferences: UserPreferences(duration: option))
            _ = engine.userSetDuration(option, now: start)
            XCTAssertNil(engine.timerEnd)
            _ = engine.userSetEngaged(true, now: start)
            XCTAssertEqual(engine.timerEnd, start.addingTimeInterval(seconds))
            XCTAssertTrue(engine.tick(now: start.addingTimeInterval(seconds - 1), safety: safe, agents: idle).isEmpty)
            let end = start.addingTimeInterval(seconds)
            XCTAssertTrue(engine.tick(now: end, safety: safe, agents: idle).contains(.disengage(.timerExpired)))
            XCTAssertFalse(engine.engaged)
            XCTAssertNil(engine.timerEnd)
            XCTAssertEqual(engine.preferences.duration, option)
            XCTAssertEqual(engine.preferences.lastWatchEnd, LastWatchEnd(endedAt: end, reason: .timerExpired))
            XCTAssertTrue(engine.tick(now: end.addingTimeInterval(1), safety: safe, agents: idle).isEmpty)
        }
    }

    func testReopeningLidPreservesCountdownAndStillExpires() {
        var engine = WatchEngine(preferences: UserPreferences(duration: .oneHour))
        _ = engine.userSetEngaged(true, now: start)
        _ = engine.lidDidClose(now: start.addingTimeInterval(10))
        _ = engine.lidDidOpen(now: start.addingTimeInterval(20))
        XCTAssertEqual(engine.timerEnd, start.addingTimeInterval(3600))
        XCTAssertTrue(engine.engaged)
        XCTAssertTrue(engine.tick(now: start.addingTimeInterval(3600), safety: safe, agents: idle).contains(.disengage(.timerExpired)))
        XCTAssertFalse(engine.engaged)
    }

    func testChangingDurationStartsFreshAndUntimedModesCancelDeadline() {
        var engine = WatchEngine(preferences: UserPreferences(duration: .oneHour))
        _ = engine.userSetEngaged(true, now: start)
        _ = engine.userSetDuration(.customMinutes(33), now: start.addingTimeInterval(10))
        XCTAssertEqual(engine.timerEnd, start.addingTimeInterval(1990))
        for option in [DurationOption.indefinite, .untilAgentsSettle] {
            _ = engine.userSetDuration(option, now: start.addingTimeInterval(20))
            XCTAssertNil(engine.timerEnd)
            XCTAssertTrue(engine.tick(now: start.addingTimeInterval(20000), safety: safe, agents: idle).isEmpty)
            XCTAssertTrue(engine.engaged)
        }
    }

    func testFailedDisarmRestoresExpiredDeadlineInsteadOfRestartingTimer() {
        var engine = WatchEngine(preferences: UserPreferences(duration: .customMinutes(1)))
        _ = engine.userSetEngaged(true, now: start)
        _ = engine.tick(now: start.addingTimeInterval(60), safety: safe, agents: idle)
        _ = engine.rollbackDisarmFailure(now: start.addingTimeInterval(61))
        XCTAssertTrue(engine.engaged)
        XCTAssertEqual(engine.timerEnd, start.addingTimeInterval(60))
        XCTAssertNil(engine.preferences.lastWatchEnd)
    }

    func testRealRemainingTimeIsNilWhileOffAndClampedAfterExpiry() {
        var engine = WatchEngine(preferences: UserPreferences(duration: .oneHour))
        XCTAssertNil(engine.statusItemRemainingSeconds(now: start))
        _ = engine.userSetEngaged(true, now: start)
        XCTAssertEqual(engine.statusItemRemainingSeconds(now: start), 3600)
        XCTAssertEqual(engine.statusItemRemainingSeconds(now: start.addingTimeInterval(3475)), 125)
        XCTAssertEqual(engine.statusItemRemainingSeconds(now: start.addingTimeInterval(3599.9)), 1)
        XCTAssertEqual(engine.statusItemRemainingSeconds(now: start.addingTimeInterval(3601)), 0)
        _ = engine.userSetDuration(.indefinite, now: start)
        XCTAssertNil(engine.statusItemRemainingSeconds(now: start))
    }
}
