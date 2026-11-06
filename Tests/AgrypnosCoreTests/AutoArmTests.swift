import XCTest
@testable import AgrypnosCore

final class AutoArmTests: XCTestCase {
    private let t0 = Date(timeIntervalSince1970: 1_000_000)
    private let calm = SafetyInputs(batteryPercent: 80, onBatteryDischarging: false, thermalSerious: false, lowPowerMode: false)

    private func at(_ seconds: TimeInterval) -> Date { t0.addingTimeInterval(seconds) }

    private func busyAgents(_ busy: Bool) -> AgentSnapshot {
        AgentSnapshot(reports: [
            AgentReport(kind: .claudeCode, processRunning: true, cpuBusy: busy, recentSessionWrite: busy, isBusy: busy),
        ])
    }

    private func autoOnEngine() -> WatchEngine {
        WatchEngine(preferences: UserPreferences(duration: .untilAgentsSettle, autoArmWhenBusy: true))
    }

    /// Feeds busy checks every 5s from `from` through `through`. Returns the first second that came back due.
    private func feed(_ engine: inout WatchEngine, busy: Bool?, from: TimeInterval, through: TimeInterval,
                      lidClosed: Bool? = false, safety: SafetyInputs? = nil) -> TimeInterval? {
        var s = from
        while s <= through {
            if engine.autoArmDue(now: at(s), busy: busy, lidClosed: lidClosed, safety: safety ?? calm) { return s }
            s += 5
        }
        return nil
    }

    // MARK: Preference

    func testDefaultOffAndMissingKeyDecodesOff() throws {
        XCTAssertFalse(UserPreferences.default.autoArmWhenBusy)
        let json = """
        {"batteryFloorPercent":15,"duration":"indefinite","keyboardBacklightOff":true,"applyBrightnessFloor":true,"brightnessFloorPercent":15,"agentSettleGrace":120,"sessionFreshness":45,"lidOpenRampSeconds":2}
        """
        XCTAssertFalse(try JSONDecoder().decode(UserPreferences.self, from: Data(json.utf8)).autoArmWhenBusy)
        let on = try JSONEncoder().encode(UserPreferences(autoArmWhenBusy: true))
        XCTAssertTrue(try JSONDecoder().decode(UserPreferences.self, from: on).autoArmWhenBusy)
    }

    // MARK: Busy count

    func testArmsAfterThirtySecondsOfContinuousBusy() {
        var engine = autoOnEngine()
        XCTAssertEqual(feed(&engine, busy: true, from: 0, through: 60), 30)
    }

    func testObservationGapRestartsTheCount() {
        var engine = autoOnEngine()
        XCTAssertNil(feed(&engine, busy: true, from: 0, through: 25))
        // 20s with no check: the next busy check starts a fresh 30s.
        XCTAssertEqual(feed(&engine, busy: true, from: 45, through: 120), 75)
    }

    func testIncompleteProbeRestartsTheCount() {
        var engine = autoOnEngine()
        XCTAssertNil(feed(&engine, busy: true, from: 0, through: 25))
        XCTAssertNil(feed(&engine, busy: nil, from: 30, through: 30))
        XCTAssertEqual(feed(&engine, busy: true, from: 35, through: 120), 65)
    }

    func testQuietRestartsTheCount() {
        var engine = autoOnEngine()
        XCTAssertNil(feed(&engine, busy: true, from: 0, through: 25))
        XCTAssertNil(feed(&engine, busy: false, from: 30, through: 30))
        XCTAssertEqual(feed(&engine, busy: true, from: 35, through: 120), 65)
    }

    // MARK: Gates

    func testOffPreferenceNeverArms() {
        var engine = WatchEngine(preferences: UserPreferences(duration: .untilAgentsSettle))
        XCTAssertNil(feed(&engine, busy: true, from: 0, through: 120))
    }

    func testOnlyWorksWhileHowLongIsAgents() {
        for duration in [DurationOption.indefinite, .oneHour, .threeHours, .custom(minutes: 33)] {
            var engine = WatchEngine(preferences: UserPreferences(duration: duration, autoArmWhenBusy: true))
            XCTAssertFalse(engine.autoArmWatching)
            XCTAssertNil(feed(&engine, busy: true, from: 0, through: 120), "\(duration)")
        }
        XCTAssertTrue(autoOnEngine().autoArmWatching)
    }

    func testNeverArmsWithTheLidClosed() {
        var engine = autoOnEngine()
        XCTAssertNil(feed(&engine, busy: true, from: 0, through: 60, lidClosed: true))
        // Desktop Macs report no lid; that is not a closed lid.
        var desktop = autoOnEngine()
        XCTAssertEqual(feed(&desktop, busy: true, from: 0, through: 60, lidClosed: nil), 30)
    }

    func testDoesNotArmWhenSafetyWouldTurnItRightBackOff() {
        let cases = [
            SafetyInputs(batteryPercent: 10, onBatteryDischarging: true, thermalSerious: false, lowPowerMode: false),
            SafetyInputs(batteryPercent: 80, onBatteryDischarging: false, thermalSerious: true, lowPowerMode: false),
            SafetyInputs(batteryPercent: 80, onBatteryDischarging: true, thermalSerious: false, lowPowerMode: true),
        ]
        for safety in cases {
            var engine = autoOnEngine()
            XCTAssertNil(feed(&engine, busy: true, from: 0, through: 60, safety: safety), "\(safety)")
        }
    }

    // MARK: Arm and settle

    func testAutoArmEntersAgentsAndSettlesOffOnItsOwn() {
        var engine = autoOnEngine()
        XCTAssertEqual(feed(&engine, busy: true, from: 0, through: 60), 30)
        XCTAssertEqual(engine.autoArm(now: at(30)), [.engage])
        XCTAssertTrue(engine.engaged)
        XCTAssertTrue(engine.autoArmed)
        XCTAssertEqual(engine.mode, .untilAgentsSettle)
        XCTAssertFalse(engine.userForcedThisSession)
        XCTAssertTrue(engine.settle.sawBusy)
        XCTAssertEqual(engine.preferences.duration, .untilAgentsSettle)

        // Quiet right after the arm still ends the watch when the wait after agent signals stop ends.
        var ended: [WatchCommand] = []
        var s: TimeInterval = 35
        while ended.isEmpty, s <= 300 {
            ended = engine.tick(now: at(s), safety: calm, agents: busyAgents(false))
            s += 5
        }
        XCTAssertTrue(ended.contains(.disengage(.agentsSettled)))
        XCTAssertFalse(engine.engaged)
        XCTAssertFalse(engine.autoArmed)
        XCTAssertEqual(engine.preferences.duration, .untilAgentsSettle)
    }

    /// Human decision 2026-11-06: an Auto-on watch that ends with the lid open sends no bot message.
    func testAutoOnEndWithLidOpenIsQuietAndWithLidConfirmedClosedStillMessages() {
        for closeLid in [false, true] {
            var engine = WatchEngine(preferences: UserPreferences(
                duration: .untilAgentsSettle, notifEnabled: true, autoArmWhenBusy: true))
            XCTAssertEqual(feed(&engine, busy: true, from: 0, through: 60), 30)
            _ = engine.autoArm(now: at(30))
            if closeLid {
                _ = engine.observeLid(closed: true, now: at(31))
                _ = engine.observeLid(closed: true, now: at(33))
                XCTAssertTrue(engine.lidCloseConfirmed)
            }
            var ended: [WatchCommand] = []
            var s: TimeInterval = 35
            while ended.isEmpty, s <= 300 {
                ended = engine.tick(now: at(s), safety: calm, agents: busyAgents(false))
                s += 5
            }
            XCTAssertTrue(ended.contains(.disengage(.agentsSettled)))
            XCTAssertEqual(ended.contains(.postIdleAfterWaitNotif), closeLid, "lid closed: \(closeLid)")
            XCTAssertEqual(engine.lastEndQuiet, !closeLid)
        }
    }

    func testUserArmEndingWithLidOpenStillMessages() {
        var engine = WatchEngine(preferences: UserPreferences(duration: .untilAgentsSettle, notifEnabled: true))
        _ = engine.userSetEngaged(true, now: at(0))
        _ = engine.tick(now: at(5), safety: calm, agents: busyAgents(true))
        var ended: [WatchCommand] = []
        var s: TimeInterval = 10
        while ended.isEmpty, s <= 300 {
            ended = engine.tick(now: at(s), safety: calm, agents: busyAgents(false))
            s += 5
        }
        XCTAssertTrue(ended.contains(.postIdleAfterWaitNotif))
        XCTAssertFalse(engine.lastEndQuiet)
    }

    func testAfterManualOffWaitsForTheNextRun() {
        var engine = autoOnEngine()
        XCTAssertEqual(feed(&engine, busy: true, from: 0, through: 60), 30)
        _ = engine.autoArm(now: at(30))
        _ = engine.userSetEngaged(false, now: at(40))

        XCTAssertNil(feed(&engine, busy: true, from: 45, through: 300), "still the same run")
        XCTAssertNil(feed(&engine, busy: false, from: 305, through: 305))
        XCTAssertEqual(feed(&engine, busy: true, from: 310, through: 400), 340)
    }

    func testFailedArmWaitsForTheNextRun() {
        var engine = autoOnEngine()
        XCTAssertEqual(feed(&engine, busy: true, from: 0, through: 60), 30)
        engine.autoArmDidFail()
        XCTAssertNil(feed(&engine, busy: true, from: 35, through: 300))
        XCTAssertNil(feed(&engine, busy: false, from: 305, through: 305))
        XCTAssertEqual(feed(&engine, busy: true, from: 310, through: 400), 340)
    }

    func testUserArmIsNotAutoArmed() {
        var engine = autoOnEngine()
        _ = engine.userSetEngaged(true, now: t0)
        XCTAssertFalse(engine.autoArmed)
    }

    // MARK: Probe, copy, layout

    func testProbesBusySignalsWhileOffOnlyWhenWatching() {
        XCTAssertEqual(WatchTickProbe.needed(engaged: false, mode: .idle, autoArmWatching: true), .safetyAndAgents)
        XCTAssertEqual(WatchTickProbe.needed(engaged: false, mode: .idle, autoArmWatching: false), .none)
        XCTAssertEqual(WatchTickProbe.needed(engaged: true, mode: .indefinite, autoArmWatching: true), .safety)
    }

    func testWatchCaptionSaysAutoOnAndFits() {
        for mode in [PanelPowerMode.floor, .displaySleep] {
            let caption = AgrypnosCopy.watchCaption(
                engaged: true, leftover: false, floor: 100, lidClosed: false, panelPowerMode: mode, autoArmed: true
            )
            XCTAssertTrue(caption.hasPrefix("Turned on by Auto-on."), caption)
            XCTAssertLessThanOrEqual(
                CopyWrap.lineCount(caption, columns: PopoverCopyLayout.innerColumns),
                PopoverCopyLayout.captionMaxLines
            )
            XCTAssertFalse(
                AgrypnosCopy.watchCaption(engaged: true, leftover: false, floor: 15, lidClosed: false, panelPowerMode: mode)
                    .contains("Auto-on")
            )
        }
    }

    func testAutoOnCopyIsPlainAndFits() {
        XCTAssertEqual(
            CopyWrap.lineCount(AgrypnosCopy.autoArmHelp, columns: PopoverCopyLayout.innerColumns),
            PopoverCopyLayout.autoArmHelpMaxLines
        )
        let all = (AgrypnosCopy.autoArm + " " + AgrypnosCopy.autoArmHelp).lowercased()
        XCTAssertTrue(all.contains("30 seconds"))
        XCTAssertTrue(all.contains("agents"))
        XCTAssertTrue(all.contains("wait after agent signals stop"))
        XCTAssertFalse(all.contains("idle wait"))
        for banned in ["thinking", "agent started", "job", "finished"] {
            XCTAssertFalse(all.contains(banned), banned)
        }
    }

    func testAutoOnCardSitsUnderHowLongAndWatchStillFits() throws {
        XCTAssertEqual(PopoverSection.watch.cards, [.watch, .duration, .autoArm, .lastWatchEnd])
        XCTAssertFalse(PopoverSection.agents.cards.contains(.autoArm))
        for caption in [false, true] {
            let layout = PopoverStackLayout.make(section: .watch, showsWatchCaption: caption)
            let duration = try XCTUnwrap(layout.duration)
            let slot = try XCTUnwrap(layout.autoArm)
            XCTAssertEqual(slot.y, duration.maxY + PopoverStackLayout.cardGap)
            XCTAssertFalse(layout.needsScroll, "caption \(caption)")
        }
    }
}
