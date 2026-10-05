import XCTest
import AgrypnosCore
@testable import AgrypnosMac

@MainActor
final class TimedWatchRuntimeTests: XCTestCase {
    let safe = SafetyInputs(batteryPercent: 90, onBatteryDischarging: false,
                            thermalSerious: false, lowPowerMode: false)

    func expire(_ fixture: RuntimeFixture, start: Date) {
        fixture.runtime.finishPollTick(now: start.addingTimeInterval(60), safety: safe,
            agents: AgentSnapshot(reports: []), kernel: true, observeAgents: false)
    }

    func arm(_ fixture: RuntimeFixture) -> Date {
        fixture.runtime.engine.preferences.notifEnabled = false
        fixture.runtime.engine.preferences.duration = .customMinutes(1)
        let start = Date()
        _ = fixture.runtime.engine.userSetEngaged(true, now: start)
        return start
    }

    func testClosedLidTimerReleasesKernelAndSleepsOnce() {
        let fixture = RuntimeFixture()
        let start = arm(fixture)
        expire(fixture, start: start)
        XCTAssertFalse(fixture.kernelHeld)
        XCTAssertFalse(fixture.runtime.engaged)
        XCTAssertEqual(fixture.sleepRequests, 1)
        expire(fixture, start: start)
        XCTAssertEqual(fixture.sleepRequests, 1)
    }

    func testKnownOpenLidTimerDisarmsWithoutSleep() {
        let fixture = RuntimeFixture()
        fixture.lidClosed = false
        let start = arm(fixture)
        expire(fixture, start: start)
        XCTAssertFalse(fixture.kernelHeld)
        XCTAssertFalse(fixture.runtime.engaged)
        XCTAssertEqual(fixture.sleepRequests, 0)
    }

    func testLidOpeningDuringKernelClearPreventsSleep() {
        let fixture = RuntimeFixture()
        let start = arm(fixture)
        fixture.kernelWriteHook = { held in if !held { fixture.lidClosed = false } }
        expire(fixture, start: start)
        XCTAssertFalse(fixture.runtime.engaged)
        XCTAssertEqual(fixture.sleepRequests, 0)
    }

    func testFailedKernelClearDoesNotSleepOrGrantFreshTime() {
        let fixture = RuntimeFixture()
        let start = arm(fixture)
        fixture.kernelWriteSucceeds = false
        expire(fixture, start: start)
        XCTAssertTrue(fixture.runtime.engaged)
        XCTAssertTrue(fixture.kernelHeld)
        XCTAssertEqual(fixture.sleepRequests, 0)
        XCTAssertEqual(fixture.runtime.engine.timerEnd, start.addingTimeInterval(60))
        XCTAssertNil(fixture.runtime.preferences.lastWatchEnd)
    }

    func testUnknownLidAtTimerExpiryRequestsSleep() {
        let fixture = RuntimeFixture()
        let start = arm(fixture)
        fixture.lidUnknown = true
        expire(fixture, start: start)
        XCTAssertFalse(fixture.runtime.engaged)
        XCTAssertEqual(fixture.sleepRequests, 1)
    }

    func testTimerPostCarriesExpiryReasonAndHoldsUntilAttemptCompletes() async {
        let fixture = RuntimeFixture()
        let start = arm(fixture)
        fixture.runtime.engine.preferences.notifEnabled = true
        expire(fixture, start: start)
        await fixture.waitForPost()
        XCTAssertEqual(fixture.postReasons, [.timerExpired])
        XCTAssertTrue(fixture.kernelHeld)
        XCTAssertEqual(fixture.sleepRequests, 0)
        fixture.completePost()
        await fixture.waitForCompletion()
        XCTAssertFalse(fixture.kernelHeld)
        XCTAssertFalse(fixture.runtime.engaged)
        XCTAssertEqual(fixture.sleepRequests, 1)
    }

    func testOpenDuringTimerPostPreventsSleep() async {
        let fixture = RuntimeFixture()
        let start = arm(fixture)
        fixture.runtime.engine.preferences.notifEnabled = true
        expire(fixture, start: start)
        await fixture.waitForPost()
        fixture.lidClosed = false
        fixture.completePost()
        await fixture.waitForCompletion()
        XCTAssertFalse(fixture.runtime.engaged)
        XCTAssertEqual(fixture.sleepRequests, 0)
    }

    func testRearmRetiresPendingTimerPostSleep() async {
        let fixture = RuntimeFixture()
        let start = arm(fixture)
        fixture.runtime.engine.preferences.notifEnabled = true
        expire(fixture, start: start)
        await fixture.waitForPost()
        fixture.runtime.setEngaged(true)
        let deadline = fixture.runtime.engine.timerEnd
        fixture.completePost()
        await fixture.waitForCompletion()
        XCTAssertTrue(fixture.runtime.engaged)
        XCTAssertTrue(fixture.kernelHeld)
        XCTAssertEqual(fixture.runtime.engine.timerEnd, deadline)
        XCTAssertEqual(fixture.sleepRequests, 0)
    }

    func testNativeDeadlineTracksSelectionAndCancelsForUntimedModes() {
        let fixture = RuntimeFixture()
        _ = arm(fixture)
        fixture.runtime.setDuration(.oneHour)
        XCTAssertEqual(fixture.runtime.deadlineTimer?.fireDate, fixture.runtime.engine.timerEnd)
        let original = fixture.runtime.deadlineTimer
        fixture.lidClosed = false
        fixture.runtime.pollLid()
        XCTAssertTrue(fixture.runtime.deadlineTimer === original)
        fixture.runtime.setDuration(.threeHours)
        XCTAssertEqual(fixture.runtime.deadlineTimer?.fireDate, fixture.runtime.engine.timerEnd)
        XCTAssertFalse(original?.isValid ?? true)
        fixture.runtime.setDuration(.indefinite)
        XCTAssertNil(fixture.runtime.deadlineTimer)
        fixture.runtime.setDuration(.untilAgentsSettle)
        XCTAssertNil(fixture.runtime.deadlineTimer)
    }

    func testNativeDeadlineFiresWithoutWaitingForFiveSecondPoll() async throws {
        let fixture = RuntimeFixture()
        _ = arm(fixture)
        _ = fixture.runtime.engine.userSetEngaged(true, now: Date().addingTimeInterval(-59.9))
        fixture.runtime.syncDeadlineTimer()
        for _ in 0..<100 where fixture.runtime.engaged {
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        XCTAssertFalse(fixture.runtime.engaged)
        XCTAssertFalse(fixture.kernelHeld)
        XCTAssertEqual(fixture.sleepRequests, 1)
    }

    func testTimerOutboundUsesExpiryMessageAndAgentsKeepsIdleMessage() throws {
        let secrets = NotifSecrets(discordWebhookURL: "https://discord.com/api/webhooks/123/test",
                                   telegramBotToken: "123:test", telegramChatId: "42")
        let timed = NotifIdlePoster.requests(secrets: secrets, reason: .timerExpired)
        XCTAssertEqual(timed.count, 2)
        for request in timed {
            let body = try XCTUnwrap(JSONSerialization.jsonObject(with: request.body) as? [String: Any])
            XCTAssertEqual((body["text"] ?? body["content"]) as? String, "Agrypnos: your watch timer ended.")
        }
        let agents = NotifIdlePoster.requests(secrets: secrets, reason: .agentsSettled)
        XCTAssertEqual(agents.count, 2)
        let body = try XCTUnwrap(JSONSerialization.jsonObject(with: agents[1].body) as? [String: Any])
        XCTAssertEqual(body["text"] as? String, "Agrypnos: local busy signals went idle after the wait.")
        XCTAssertTrue(NotifIdlePoster.requests(secrets: NotifSecrets(), reason: .timerExpired).isEmpty)
    }
}
