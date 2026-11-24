import XCTest
import AgrypnosCore
@testable import AgrypnosMac

/// Automatic watch ends do not sleep a Mac someone is using: a desktop (no lid) or a closed
/// laptop driving an external display. User off and `/disarm` keep the confirmed-lid rule.
@MainActor
final class UserAtMacSleepTests: XCTestCase {
    private let calm = SafetyInputs(batteryPercent: 90, onBatteryDischarging: false, thermalSerious: false, lowPowerMode: false)

    private func expireTimer(_ f: RuntimeFixture) {
        f.runtime.engine.preferences.notifEnabled = false
        f.runtime.engine.preferences.duration = .customMinutes(1)
        let start = Date()
        _ = f.runtime.engine.userSetEngaged(true, now: start)
        f.runtime.finishPollTick(now: start.addingTimeInterval(60), safety: calm,
                                 agents: AgentSnapshot(reports: []), kernel: true, observeAgents: false)
        XCTAssertFalse(f.runtime.engaged)
    }

    private func confirmClosed(_ f: RuntimeFixture) -> [WatchCommand] {
        let start = Date()
        _ = f.runtime.engine.userSetEngaged(true, now: start, lidClosed: false)
        _ = f.runtime.engine.observeLid(closed: true, now: start)
        return f.runtime.engine.observeLid(closed: true, now: start.addingTimeInterval(LidCloseConfirm.pulseInterval))
    }

    func testTimerOnADesktopInUseDoesNotSleep() {
        let f = RuntimeFixture()
        f.lidUnknown = true
        f.secondsSinceInput = 5
        expireTimer(f)
        XCTAssertEqual(f.sleepRequests, 0)
    }

    func testTimerOnAnIdleDesktopStillSleeps() {
        let f = RuntimeFixture()
        f.lidUnknown = true
        f.secondsSinceInput = 600
        expireTimer(f)
        XCTAssertEqual(f.sleepRequests, 1)
    }

    func testClosedLidWithExternalDisplayInUseDoesNotSleep() {
        let f = RuntimeFixture()
        f.externalDisplay = true
        f.secondsSinceInput = 5
        expireTimer(f)
        XCTAssertEqual(f.sleepRequests, 0)
    }

    func testClosedLidWithoutExternalDisplayStillSleepsRightAfterTyping() {
        let f = RuntimeFixture()
        f.secondsSinceInput = 5
        expireTimer(f)
        XCTAssertEqual(f.sleepRequests, 1)
    }

    func testUserOffWithClosedLidAndExternalDisplayStillSleeps() {
        let f = RuntimeFixture()
        f.runtime.engine.preferences.notifEnabled = false
        f.externalDisplay = true
        f.secondsSinceInput = 1
        _ = confirmClosed(f)
        _ = f.runtime.setEngaged(false)
        XCTAssertEqual(f.sleepRequests, 1)
    }

    func testUnansweredQuestionDoesNotSleepAMacInUse() async {
        let f = RuntimeFixture()
        f.externalDisplay = true
        f.secondsSinceInput = 5
        f.beginQuestionWatch()
        let key = QuestionKey(provider: .cursor, instanceID: "app", sessionID: "test", requestID: "q")
        f.runtime.questionRelayDidChange(.observed(key, 600))
        f.questionUptime = 600
        f.runtime.questionRelayDidChange(.expired(key))
        f.runtime.finishPollTick(now: Date(timeIntervalSince1970: 600), safety: calm,
                                 agents: AgentSnapshot(reports: []), kernel: true, observeAgents: true)
        XCTAssertFalse(f.runtime.engine.engaged)
        await f.waitForQuestionNotice()
        f.completeQuestionNotice()
        await f.waitForCompletion()
        XCTAssertEqual(f.sleepRequests, 0)
    }

    func testSleepPanelLeavesAnExternalDisplayOn() {
        for external in [false, true] {
            let f = RuntimeFixture()
            f.runtime.engine.preferences.panelPowerMode = .displaySleep
            f.externalDisplay = external
            f.runtime.apply(confirmClosed(f))
            XCTAssertEqual(f.panelSleepRequests, external ? 0 : 1, "external display: \(external)")
        }
    }
}
