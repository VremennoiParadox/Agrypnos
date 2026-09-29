import XCTest
@testable import AgrypnosCore

/// I2: popover / hotkey off uses the same lid-gated sleepnow as inbound `/disarm`.
final class WatchUserOffSleepTests: XCTestCase {
    let t0 = Date(timeIntervalSince1970: 10_000)

    func testPopoverOffWithConfirmedLidRequestsSleepOnTheInboundPath() {
        var engine = WatchEngine(preferences: .default)
        _ = engine.userSetEngaged(true, now: t0, lidClosed: false)
        XCTAssertTrue(engine.observeLid(closed: true, now: t0).isEmpty)
        _ = engine.observeLid(closed: true, now: t0.addingTimeInterval(LidCloseConfirm.pulseInterval))
        XCTAssertTrue(engine.lidCloseConfirmed)

        let commands = engine.userSetEngaged(
            false,
            now: t0.addingTimeInterval(1),
            lidClosed: engine.lidCloseConfirmed
        )
        XCTAssertFalse(engine.engaged)
        XCTAssertTrue(commands.contains(.disengage(.user)))
        XCTAssertTrue(commands.contains(.requestSleep))
        XCTAssertEqual(
            commands.contains(.requestSleep),
            TelegramInboundDisarm.shouldRequestSleep(lidCloseConfirmed: true)
        )
        XCTAssertEqual(commands.filter { $0 == .requestSleep }.count, 1)
    }

    func testHotkeyOffWithConfirmedLidIsTheSameSleepStoryAsInboundDisarm() {
        var popover = WatchEngine(preferences: .default)
        var inbound = WatchEngine(preferences: .default)
        _ = popover.userSetEngaged(true, now: t0, lidClosed: true)
        _ = inbound.userSetEngaged(true, now: t0, lidClosed: true)

        let userOff = popover.userSetEngaged(false, now: t0.addingTimeInterval(1), lidClosed: true)
        let inboundOff = inbound.applyInbound(.disarm, now: t0.addingTimeInterval(1), lidCloseConfirmed: true)

        XCTAssertEqual(userOff, inboundOff)
        XCTAssertTrue(userOff.contains(.requestSleep))
        XCTAssertTrue(inboundOff.contains(.disengage(.user)))
        XCTAssertEqual(inboundOff.filter { $0 == .requestSleep }.count, 1)
    }

    func testUserOffLidOpenDoesNotSleep() {
        var engine = WatchEngine(preferences: .default)
        _ = engine.userSetEngaged(true, now: t0, lidClosed: false)
        let commands = engine.userSetEngaged(false, now: t0.addingTimeInterval(1), lidClosed: false)
        XCTAssertEqual(commands, [.disengage(.user)])
        XCTAssertFalse(commands.contains(.requestSleep))
        XCTAssertFalse(TelegramInboundDisarm.shouldRequestSleep(lidCloseConfirmed: false))
    }

    func testUserOffUnconfirmedCloseDoesNotSleep() {
        var engine = WatchEngine(preferences: .default)
        _ = engine.userSetEngaged(true, now: t0, lidClosed: false)
        XCTAssertTrue(engine.observeLid(closed: true, now: t0).isEmpty)
        XCTAssertFalse(engine.lidCloseConfirmed)

        let commands = engine.userSetEngaged(
            false,
            now: t0.addingTimeInterval(0.1),
            lidClosed: engine.lidCloseConfirmed
        )
        XCTAssertFalse(engine.engaged)
        XCTAssertFalse(commands.contains(.requestSleep))
    }

    func testInboundAlreadyOffStillSleepsOnceWhenLidConfirmed() {
        var engine = WatchEngine(preferences: .default)
        XCTAssertFalse(engine.engaged)
        let commands = engine.applyInbound(.disarm, now: t0, lidCloseConfirmed: true)
        XCTAssertEqual(commands, [.requestSleep])
    }

    func testAgentsIdleAndSafetyKeepExistingLidClosedSleepPath() {
        var prefs = UserPreferences.default
        prefs.duration = .untilAgentsSettle
        var agents = WatchEngine(preferences: prefs)
        _ = agents.userSetEngaged(true, now: t0, lidClosed: true)
        XCTAssertTrue(
            agents.tick(
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
        observeHealthyIdle(&agents, before: t0.addingTimeInterval(120))
        XCTAssertEqual(
            agents.tick(now: t0.addingTimeInterval(120), safety: .acPower, agents: .idle),
            [.disengage(.agentsSettled), .requestSleep]
        )

        var safety = WatchEngine(preferences: .default)
        _ = safety.userSetEngaged(true, now: t0, lidClosed: true)
        observeHealthyIdle(&safety, before: t0.addingTimeInterval(1))
        XCTAssertEqual(
            safety.tick(
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
