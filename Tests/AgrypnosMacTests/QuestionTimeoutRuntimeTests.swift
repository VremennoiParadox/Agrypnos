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
        XCTAssertTrue(fixture.runtime.engine.engaged)
        XCTAssertTrue(fixture.kernelHeld)
        XCTAssertNil(fixture.runtime.engine.preferences.lastWatchEnd)
        XCTAssertEqual(fixture.runtime.engine.preferences.duration, .untilAgentsSettle)
        XCTAssertEqual(fixture.sleepRequests, 0)
        await fixture.waitForCompletion()
        XCTAssertEqual(fixture.sleepRequests, 0)
        XCTAssertFalse(fixture.messages.contains { $0.contains("wait after agent signals stop") })
        XCTAssertFalse(fixture.questionNotices.contains { $0.contains("Keep awake turned off") })
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
        await fixture.waitForCompletion()
        XCTAssertFalse(fixture.questionNotices.contains { $0.contains("couldn't turn Keep awake off") })
        XCTAssertFalse(fixture.questionNotices.contains { $0.contains("Keep awake turned off") })
    }

    func testBusyAndUnknownTimeoutPreserveWatch() async {
        for positive in [true, false] {
            let fixture = RuntimeFixture()
            fixture.beginQuestionWatch()
            fixture.runtime.questionRelayDidChange(.observed(key, 600))
            fixture.questionUptime = 600
            fixture.runtime.questionRelayDidChange(.expired(key))
            let busy = AgentSnapshot(reports: [AgentReport(kind: .codex, processRunning: true,
                cpuBusy: false, recentSessionWrite: true, isBusy: true)])
            fixture.runtime.finishPollTick(now: Date(timeIntervalSince1970: 600), safety: safe,
                agents: positive ? busy : AgentSnapshot(reports: []), kernel: true, observeAgents: positive)
            XCTAssertTrue(fixture.runtime.engine.engaged)
            XCTAssertTrue(fixture.kernelHeld)
            XCTAssertEqual(fixture.sleepRequests, 0)
            await fixture.waitForQuestionNotice()
            XCTAssertTrue(fixture.questionNotices.first?.contains("Keep awake stays on") == true)
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
            XCTAssertTrue(fixture.runtime.engine.engaged)
            if rearm { _ = fixture.runtime.setEngaged(true) }
            else { fixture.lidClosed = false }
            await fixture.waitForCompletion()
            XCTAssertEqual(fixture.sleepRequests, 0)
            XCTAssertTrue(fixture.runtime.engine.engaged)
        }
    }

    func testLidOpeningDuringFinalConfirmationSkipsSleep() async {
        let fixture = RuntimeFixture()
        fixture.beginQuestionWatch()
        fixture.runtime.questionRelayDidChange(.observed(key, 600))
        fixture.questionUptime = 600
        fixture.runtime.questionRelayDidChange(.expired(key))
        fixture.runtime.finishPollTick(now: Date(timeIntervalSince1970: 600), safety: safe,
            agents: AgentSnapshot(reports: []), kernel: true, observeAgents: true)
        XCTAssertTrue(fixture.runtime.engine.engaged)
        fixture.lidClosed = false
        await fixture.waitForCompletion()
        XCTAssertEqual(fixture.sleepRequests, 0)
        XCTAssertTrue(fixture.runtime.engine.engaged)
    }

    func testWallClockJumpDoesNotExpireMonotonicQuestion() async {
        let fixture = RuntimeFixture()
        fixture.beginQuestionWatch()
        fixture.runtime.questionRelayDidChange(.observed(key, 600))
        fixture.questionUptime = 599
        fixture.runtime.finishPollTick(now: Date(timeIntervalSince1970: 999_999_999), safety: safe,
            agents: AgentSnapshot(reports: []), kernel: true, observeAgents: true)
        XCTAssertTrue(fixture.runtime.engine.engaged)
        fixture.questionUptime = 600
        fixture.runtime.questionRelayDidChange(.expired(key))
        fixture.runtime.finishPollTick(now: Date(timeIntervalSince1970: 1), safety: safe,
            agents: AgentSnapshot(reports: []), kernel: true, observeAgents: true)
        XCTAssertTrue(fixture.runtime.engine.engaged)
        XCTAssertNil(fixture.runtime.engine.preferences.lastWatchEnd)
        await fixture.waitForCompletion()
        XCTAssertEqual(fixture.sleepRequests, 0)
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

    func testSafetyAutoOffDoesNotClaimWatchRemainsOn() async {
        let fixture = RuntimeFixture()
        fixture.beginQuestionWatch()
        fixture.runtime.questionRelayDidChange(.observed(key, 600))
        fixture.questionUptime = 600
        fixture.runtime.questionRelayDidChange(.expired(key))
        let unsafe = SafetyInputs(batteryPercent: 1, onBatteryDischarging: true,
            thermalSerious: false, lowPowerMode: false)
        fixture.runtime.finishPollTick(now: Date(timeIntervalSince1970: 600), safety: unsafe,
            agents: AgentSnapshot(reports: []), kernel: true, observeAgents: false)
        await fixture.waitForCompletion()
        XCTAssertFalse(fixture.runtime.engine.engaged)
        XCTAssertFalse(fixture.questionNotices.contains { $0.contains("Keep awake stays on") })
    }

    func testDelayedNativeExpiryIsClearedBeforeTenMinuteWatchDecision() async {
        let fixture = RuntimeFixture()
        fixture.beginQuestionWatch()
        let runtime = fixture.runtime!
        var localReturns = 0
        runtime.questionRelay = QuestionRelayCoordinator(settings: {
            QuestionRelaySettings(enabled: true, includedKinds: [.cursor],
                telegram: TelegramQuestionDestination(token: "fixture", chatID: "9"))
        }, transport: { _ in QuestionHTTPResponse(statusCode: nil, body: Data()) },
           uptime: { [unowned fixture] in fixture.questionUptime },
           onChange: { [weak runtime] event in runtime?.questionRelayDidChange(event) })
        let batch = QuestionBatch(key: key, questions: [AgentQuestion(id: "q", prompt: "Choose?",
            options: [QuestionOption(id: "a", label: "A")])],
            receivedUptime: 0, deadlineUptime: 30)
        XCTAssertTrue(runtime.questionRelay.receive(batch, submit: { _ in .unconfirmed },
            returnLocal: { localReturns += 1 }))
        XCTAssertEqual(runtime.questionDeadlines[key], 600)
        fixture.questionUptime = 600 // Simulates the native-expiry task being delayed.
        runtime.finishPollTick(now: Date(timeIntervalSince1970: 600), safety: safe,
            agents: AgentSnapshot(reports: []), kernel: true, observeAgents: true)
        await fixture.waitForCompletion()
        XCTAssertTrue(runtime.engine.engaged)
        XCTAssertNil(runtime.engine.preferences.lastWatchEnd)
        XCTAssertTrue(runtime.questionDeadlines.isEmpty)
        XCTAssertEqual(localReturns, 1)
        XCTAssertTrue(fixture.questionNotices.isEmpty)
    }
}
