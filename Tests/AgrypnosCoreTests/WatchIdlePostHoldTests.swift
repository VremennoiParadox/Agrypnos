import XCTest
@testable import AgrypnosCore

final class WatchIdlePostHoldTests: XCTestCase {
    let t0 = Date(timeIntervalSince1970: 10_000)

    func testIdleAfterWaitDoesNotShowEndedWhileHoldRemains() {
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
        XCTAssertTrue(engine.holdingForIdlePost)
        XCTAssertEqual(engine.statusItemState, .agents)
        XCTAssertNil(engine.preferences.lastWatchEnd)

        let status = engine.telegramWatchStatus(now: t0.addingTimeInterval(20 + 120))
        XCTAssertTrue(status.engaged)
        XCTAssertNil(status.lastWatchEnd)
        let reply = TelegramWatchStatusCopy.reply(status, now: t0.addingTimeInterval(20 + 120))
        XCTAssertFalse(reply.lowercased().contains("ended"))
        XCTAssertTrue(reply.contains(TelegramInboundCopy.keepOn))
    }

    func testCompleteIdlePostHoldRecordsLastEndAndDropsGlyphHold() {
        var prefs = UserPreferences.default
        prefs.duration = .untilAgentsSettle
        prefs.notifEnabled = true
        var engine = WatchEngine(preferences: prefs)
        _ = engine.userSetEngaged(true, now: t0)
        XCTAssertTrue(engine.tick(now: t0.addingTimeInterval(20), safety: .acPower, agents: .busy).isEmpty)
        _ = engine.tick(now: t0.addingTimeInterval(140), safety: .acPower, agents: .idle)

        engine.completeIdlePostHold()
        XCTAssertFalse(engine.holdingForIdlePost)
        XCTAssertEqual(engine.preferences.lastWatchEnd?.reason, .agentsSettled)
        XCTAssertEqual(engine.statusItemState, .off)
        XCTAssertFalse(engine.telegramWatchStatus(now: t0.addingTimeInterval(141)).engaged)
    }

    func testRollbackClearsIdlePostHoldWithoutRecordingThePendingEnd() {
        var prefs = UserPreferences.default
        prefs.duration = .untilAgentsSettle
        prefs.notifEnabled = true
        var engine = WatchEngine(preferences: prefs)
        _ = engine.userSetEngaged(true, now: t0)
        XCTAssertTrue(engine.tick(now: t0.addingTimeInterval(20), safety: .acPower, agents: .busy).isEmpty)
        _ = engine.tick(now: t0.addingTimeInterval(140), safety: .acPower, agents: .idle)
        XCTAssertTrue(engine.holdingForIdlePost)

        _ = engine.rollbackDisarmFailure(now: t0.addingTimeInterval(141), lidClosed: false)
        XCTAssertFalse(engine.holdingForIdlePost)
        XCTAssertTrue(engine.engaged)
        XCTAssertNil(engine.preferences.lastWatchEnd)
        XCTAssertEqual(engine.statusItemState, .agents)
    }

    func testSettleWithoutNotifStillRecordsLastEndImmediately() {
        var prefs = UserPreferences.default
        prefs.duration = .untilAgentsSettle
        prefs.notifEnabled = false
        var engine = WatchEngine(preferences: prefs)
        _ = engine.userSetEngaged(true, now: t0)
        XCTAssertTrue(engine.tick(now: t0.addingTimeInterval(20), safety: .acPower, agents: .busy).isEmpty)
        _ = engine.tick(now: t0.addingTimeInterval(140), safety: .acPower, agents: .idle)
        XCTAssertFalse(engine.holdingForIdlePost)
        XCTAssertEqual(engine.preferences.lastWatchEnd?.reason, .agentsSettled)
        XCTAssertEqual(engine.statusItemState, .off)
    }

    func testTickCanSkipSettleWhenAgentSnapshotIsNotReady() {
        var prefs = UserPreferences.default
        prefs.duration = .untilAgentsSettle
        var engine = WatchEngine(preferences: prefs)
        _ = engine.userSetEngaged(true, now: t0)
        XCTAssertTrue(
            engine.tick(
                now: t0.addingTimeInterval(20),
                safety: .acPower,
                agents: .busy
            ).isEmpty
        )
        XCTAssertTrue(
            engine.tick(
                now: t0.addingTimeInterval(20 + 120),
                safety: .acPower,
                agents: .idle,
                observeAgents: false
            ).isEmpty
        )
        XCTAssertTrue(engine.engaged)
        XCTAssertEqual(
            engine.tick(
                now: t0.addingTimeInterval(20 + 120),
                safety: .acPower,
                agents: .idle,
                observeAgents: true
            ),
            [.disengage(.agentsSettled)]
        )
    }

    func testUserOffDuringIdlePostHoldUsesLastDisengageLidForSleepnow() {
        var prefs = UserPreferences.default
        prefs.duration = .untilAgentsSettle
        prefs.notifEnabled = true
        var engine = WatchEngine(preferences: prefs)
        _ = engine.userSetEngaged(true, now: t0, lidClosed: true)
        XCTAssertTrue(engine.tick(now: t0.addingTimeInterval(20), safety: .acPower, agents: .busy).isEmpty)
        _ = engine.tick(now: t0.addingTimeInterval(140), safety: .acPower, agents: .idle)

        XCTAssertTrue(engine.holdingForIdlePost)
        XCTAssertFalse(engine.lidCloseConfirmed)
        XCTAssertTrue(engine.lastDisengageLidClosed)
        XCTAssertTrue(engine.userOffLidCloseConfirmed(rawClosed: true))
        XCTAssertFalse(engine.userOffLidCloseConfirmed(rawClosed: false))

        let lidOpenedDuringHold = engine.userSetEngaged(
            false,
            now: t0.addingTimeInterval(141),
            lidClosed: engine.userOffLidCloseConfirmed(rawClosed: false)
        )
        XCTAssertFalse(lidOpenedDuringHold.contains(.requestSleep))

        engine = WatchEngine(preferences: prefs)
        _ = engine.userSetEngaged(true, now: t0, lidClosed: true)
        XCTAssertTrue(engine.tick(now: t0.addingTimeInterval(20), safety: .acPower, agents: .busy).isEmpty)
        _ = engine.tick(now: t0.addingTimeInterval(140), safety: .acPower, agents: .idle)
        let stillClosed = engine.userSetEngaged(
            false,
            now: t0.addingTimeInterval(141),
            lidClosed: engine.userOffLidCloseConfirmed(rawClosed: true)
        )
        XCTAssertTrue(stillClosed.contains(.requestSleep))
        XCTAssertEqual(
            stillClosed.contains(.requestSleep),
            TelegramInboundDisarm.shouldRequestSleep(lidCloseConfirmed: true)
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
