import XCTest
import AgrypnosCore
@testable import AgrypnosMac

@MainActor
final class QuestionTimeoutRuntimeTests: XCTestCase {
    private let safe = SafetyInputs(batteryPercent: 90, onBatteryDischarging: false, thermalSerious: false, lowPowerMode: false)
    private let key = QuestionKey(provider: .cursor, instanceID: "app", sessionID: "test", requestID: "q")

    func testVerifiedReleasePrecedesNoticeAndClosedLidSleep() async {
        let fixture = RuntimeFixture()
        fixture.beginQuestionWatch()
        fixture.runtime.questionRelayDidChange(.observed(key, 600))
        fixture.questionUptime = 600
        fixture.runtime.questionRelayDidChange(.expired(key))
        fixture.runtime.finishPollTick(now: Date(timeIntervalSince1970: 600), safety: safe,
            agents: AgentSnapshot(reports: []), kernel: true, observeAgents: true)
        XCTAssertFalse(fixture.runtime.engine.engaged)
        XCTAssertFalse(fixture.kernelHeld)
        XCTAssertEqual(fixture.runtime.engine.preferences.lastWatchEnd?.reason, .questionUnanswered)
        XCTAssertEqual(fixture.sleepRequests, 0)
        await fixture.waitForQuestionNotice()
        XCTAssertTrue(fixture.questionNotices.first?.contains("watch turned off because an agent question went unanswered for 10 minutes") == true)
        fixture.completeQuestionNotice()
        await fixture.waitForCompletion()
        XCTAssertEqual(fixture.sleepRequests, 1)
        XCTAssertFalse(fixture.messages.contains { $0.contains("local busy signals went idle") })
    }

    func testFailedKernelReleaseRollsBackAndDoesNotSendSuccessCopy() async {
        let fixture = RuntimeFixture()
        fixture.beginQuestionWatch()
        fixture.kernelWriteSucceeds = false
        fixture.runtime.questionRelayDidChange(.observed(key, 600))
        fixture.questionUptime = 600
        fixture.runtime.questionRelayDidChange(.expired(key))
        fixture.runtime.finishPollTick(now: Date(timeIntervalSince1970: 600), safety: safe,
            agents: AgentSnapshot(reports: []), kernel: true, observeAgents: true)
        XCTAssertTrue(fixture.runtime.engine.engaged)
        XCTAssertTrue(fixture.kernelHeld)
        XCTAssertNil(fixture.runtime.engine.preferences.lastWatchEnd)
        XCTAssertEqual(fixture.sleepRequests, 0)
        await fixture.waitForQuestionNotice()
        XCTAssertTrue(fixture.questionNotices.first?.contains("couldn't turn the watch off") == true)
        fixture.completeQuestionNotice()
    }

    func testBusyAndUnknownTimeoutPreserveWatch() async {
        for positive in [true, false] {
            let fixture = RuntimeFixture()
            fixture.beginQuestionWatch()
            fixture.runtime.questionRelayDidChange(.observed(key, 600))
            fixture.questionUptime = 600
            fixture.runtime.questionRelayDidChange(.expired(key))
            let busy = AgentSnapshot(reports: [AgentReport(kind: .cursor, processRunning: true,
                cpuBusy: false, recentSessionWrite: true, isBusy: true)])
            fixture.runtime.finishPollTick(now: Date(timeIntervalSince1970: 600), safety: safe,
                agents: positive ? busy : AgentSnapshot(reports: []), kernel: true, observeAgents: positive)
            XCTAssertTrue(fixture.runtime.engine.engaged)
            XCTAssertTrue(fixture.kernelHeld)
            XCTAssertEqual(fixture.sleepRequests, 0)
            await fixture.waitForQuestionNotice()
            XCTAssertTrue(fixture.questionNotices.first?.contains("watch remains on") == true)
            fixture.completeQuestionNotice()
        }
    }

    func testRearmDuringMessageCancelsOldSleepAndLidOpeningSkipsSleep() async {
        for rearm in [true, false] {
            let fixture = RuntimeFixture()
            fixture.beginQuestionWatch()
            fixture.runtime.questionRelayDidChange(.observed(key, 600))
            fixture.questionUptime = 600
            fixture.runtime.questionRelayDidChange(.expired(key))
            fixture.runtime.finishPollTick(now: Date(timeIntervalSince1970: 600), safety: safe,
                agents: AgentSnapshot(reports: []), kernel: true, observeAgents: true)
            await fixture.waitForQuestionNotice()
            if rearm { _ = fixture.runtime.setEngaged(true) }
            else { fixture.lidClosed = false }
            fixture.completeQuestionNotice()
            await fixture.waitForCompletion()
            XCTAssertEqual(fixture.sleepRequests, 0)
        }
    }

    func testObservedWhileOffDoesNotProtectLaterArm() {
        let fixture = RuntimeFixture()
        fixture.runtime.questionRelayDidChange(.observed(key, 600))
        fixture.beginQuestionWatch()
        fixture.questionUptime = 600
        fixture.runtime.questionRelayDidChange(.expired(key))
        fixture.runtime.finishPollTick(now: Date(timeIntervalSince1970: 600), safety: safe,
            agents: AgentSnapshot(reports: []), kernel: true, observeAgents: true)
        XCTAssertTrue(fixture.runtime.engine.engaged)
        XCTAssertTrue(fixture.questionNotices.isEmpty)
    }
}
