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
        XCTAssertTrue(fixture.messages.contains("Couldn't verify SleepDisabled was cleared."))
        XCTAssertFalse(fixture.messages.contains { $0.contains("Keep awake is unchanged.") })
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
        XCTAssertTrue(fixture.runtime.engine.holdingForIdlePost)
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

    func testTimedDurationEditRenewsPendingTimerPost() async throws {
        let fixture = RuntimeFixture()
        let start = arm(fixture)
        fixture.runtime.engine.preferences.notifEnabled = true
        expire(fixture, start: start)
        await fixture.waitForPost()
        let changedAt = Date()
        fixture.runtime.setDuration(.threeHours)
        let renewedDeadline = fixture.runtime.engine.timerEnd
        fixture.completePost()
        await fixture.waitForCompletion()
        let deadline = try XCTUnwrap(renewedDeadline)
        XCTAssertEqual(deadline.timeIntervalSince(changedAt), 10_800, accuracy: 1)
        XCTAssertTrue(fixture.runtime.engaged)
        XCTAssertTrue(fixture.kernelHeld)
        XCTAssertEqual(fixture.runtime.engine.timerEnd, deadline)
        XCTAssertEqual(fixture.sleepRequests, 0)
    }

    func testUntimedDurationEditsRenewPendingTimerPost() async {
        for option in [DurationOption.indefinite, .untilAgentsSettle] {
            let fixture = RuntimeFixture()
            let start = arm(fixture)
            fixture.runtime.engine.preferences.notifEnabled = true
            expire(fixture, start: start)
            await fixture.waitForPost()
            fixture.runtime.setDuration(option)
            fixture.completePost()
            await fixture.waitForCompletion()
            XCTAssertTrue(fixture.runtime.engaged)
            XCTAssertTrue(fixture.kernelHeld)
            XCTAssertEqual(fixture.runtime.preferences.duration, option)
            XCTAssertNil(fixture.runtime.engine.timerEnd)
            XCTAssertEqual(fixture.sleepRequests, 0)
        }
    }

    func testTelegramArmRenewsPendingTimerPost() async throws {
        let fixture = RuntimeFixture()
        let start = arm(fixture)
        fixture.runtime.engine.preferences.notifEnabled = true
        expire(fixture, start: start)
        await fixture.waitForPost()
        fixture.runtime.applyTelegramArm(token: nil, chatId: nil)
        let renewedDeadline = fixture.runtime.engine.timerEnd
        fixture.completePost()
        await fixture.waitForCompletion()
        let deadline = try XCTUnwrap(renewedDeadline)
        XCTAssertTrue(fixture.runtime.engaged)
        XCTAssertTrue(fixture.kernelHeld)
        XCTAssertEqual(fixture.runtime.engine.timerEnd, deadline)
        XCTAssertEqual(fixture.sleepRequests, 0)
    }

    func testDiscordArmRenewsPendingTimerPost() async throws {
        let fixture = RuntimeFixture()
        let start = arm(fixture)
        fixture.runtime.engine.preferences.notifEnabled = true
        expire(fixture, start: start)
        await fixture.waitForPost()
        XCTAssertEqual(fixture.runtime.applyDiscordArm(), DiscordInboundCopy.armed)
        let renewedDeadline = fixture.runtime.engine.timerEnd
        fixture.completePost()
        await fixture.waitForCompletion()
        let deadline = try XCTUnwrap(renewedDeadline)
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

    func testTimerOutboundUsesExpiryMessageAndAgentsKeepsIdleMessage() async throws {
        let secrets = NotifSecrets(
            telegramBotToken: "123:test",
            telegramChatId: "42",
            discordBotToken: "bot",
            discordChannelId: "123"
        )
        let openRequests = NotifIdlePoster.requests(secrets: secrets, reason: .timerExpired, willSleep: false)
        XCTAssertEqual(openRequests.count, 2)
        try assertDiscordChannelMessage(openRequests)
        for request in openRequests {
            let body = try XCTUnwrap(JSONSerialization.jsonObject(with: request.body) as? [String: Any])
            XCTAssertEqual((body["text"] ?? body["content"]) as? String, "Agrypnos: your Keep awake timer ended.")
        }

        let closedRequests = NotifIdlePoster.requests(secrets: secrets, reason: .timerExpired, willSleep: true)
        XCTAssertEqual(closedRequests.count, 2)
        try assertDiscordChannelMessage(closedRequests)
        XCTAssertEqual(
            try discordContent(closedRequests),
            "Agrypnos: your Keep awake timer ended. Asking the Mac to sleep."
        )
        XCTAssertEqual(
            try telegramText(closedRequests),
            "Agrypnos: your Keep awake timer ended."
        )

        let agents = NotifIdlePoster.requests(secrets: secrets, reason: .agentsSettled, willSleep: false)
        XCTAssertEqual(agents.count, 2)
        XCTAssertEqual(try telegramText(agents), "Agrypnos: the wait after agent signals stop ended.")
        XCTAssertTrue(
            NotifIdlePoster.requests(secrets: NotifSecrets(), reason: .timerExpired, willSleep: false).isEmpty
        )

        let openLid = RuntimeFixture()
        openLid.lidClosed = false
        let openStart = arm(openLid)
        openLid.runtime.engine.preferences.notifEnabled = true
        expire(openLid, start: openStart)
        await openLid.waitForPost()
        XCTAssertEqual(openLid.discordBodies, ["Agrypnos: your Keep awake timer ended."])
        XCTAssertEqual(openLid.postWillSleep, [false])
        openLid.completePost()
        await openLid.waitForCompletion()
        XCTAssertEqual(openLid.sleepRequests, 0)

        let closedLid = RuntimeFixture()
        let closedStart = arm(closedLid)
        closedLid.runtime.engine.preferences.notifEnabled = true
        expire(closedLid, start: closedStart)
        await closedLid.waitForPost()
        XCTAssertEqual(
            closedLid.discordBodies,
            ["Agrypnos: your Keep awake timer ended. Asking the Mac to sleep."]
        )
        XCTAssertEqual(closedLid.postWillSleep, [true])
        closedLid.completePost()
        await closedLid.waitForCompletion()
        XCTAssertEqual(closedLid.sleepRequests, 1)
    }

    func testUserOffPostsDiscordSleepSentenceOnlyWhenLidIsConfirmedClosed() async throws {
        let secrets = NotifSecrets(
            telegramBotToken: "123:test",
            telegramChatId: "42",
            discordBotToken: "bot",
            discordChannelId: "123"
        )
        let userOff = NotifIdlePoster.requests(secrets: secrets, reason: .user, willSleep: true)
        try assertDiscordChannelMessage(userOff)
        XCTAssertEqual(userOff.count, 1)
        XCTAssertEqual(
            try discordContent(userOff),
            "Agrypnos: Keep awake is off. Asking the Mac to sleep."
        )

        let closed = RuntimeFixture()
        closed.notifSecrets = secrets
        armConfirmedClosed(closed)
        closed.runtime.engine.preferences.notifEnabled = true
        XCTAssertNotNil(closed.runtime.setEngaged(false))
        await closed.waitForPost()
        XCTAssertEqual(
            closed.discordBodies,
            ["Agrypnos: Keep awake is off. Asking the Mac to sleep."]
        )
        XCTAssertFalse(closed.runtime.engine.engaged)
        XCTAssertTrue(closed.kernelHeld)
        XCTAssertEqual(closed.sleepRequests, 0)
        closed.completePost()
        await closed.waitForCompletion()
        XCTAssertEqual(closed.sleepRequests, 1)

        let open = RuntimeFixture()
        open.notifSecrets = secrets
        open.lidClosed = false
        _ = arm(open)
        open.runtime.engine.preferences.notifEnabled = true
        XCTAssertNotNil(open.runtime.setEngaged(false))
        await open.waitForCompletion()
        XCTAssertTrue(open.discordBodies.isEmpty)
        XCTAssertEqual(open.sleepRequests, 0)
        XCTAssertNil(open.postContinuation)
    }

    func testUserOffDoesNotSleepOnUnconfirmedRecloseDuringPost() async {
        let secrets = NotifSecrets(discordBotToken: "bot", discordChannelId: "123")
        let fixture = RuntimeFixture()
        fixture.notifSecrets = secrets
        armConfirmedClosed(fixture)
        fixture.runtime.engine.preferences.notifEnabled = true
        XCTAssertNotNil(fixture.runtime.setEngaged(false))
        await fixture.waitForPost()
        XCTAssertFalse(fixture.runtime.engine.engaged)
        XCTAssertTrue(fixture.kernelHeld)
        fixture.lidClosed = false
        fixture.runtime.pollLid()
        fixture.lidClosed = true
        XCTAssertFalse(fixture.runtime.engine.lidCloseConfirmed)
        fixture.completePost()
        await fixture.waitForCompletion()
        XCTAssertEqual(fixture.sleepRequests, 0)
    }

    func testUserOffWaitFailedKernelClearDoesNotClaimWatchUnchanged() async {
        let secrets = NotifSecrets(discordBotToken: "bot", discordChannelId: "123")
        let fixture = RuntimeFixture()
        fixture.notifSecrets = secrets
        armConfirmedClosed(fixture)
        fixture.runtime.engine.preferences.notifEnabled = true
        XCTAssertNotNil(fixture.runtime.setEngaged(false))
        await fixture.waitForPost()
        XCTAssertFalse(fixture.runtime.engine.engaged)
        fixture.kernelWriteSucceeds = false
        fixture.completePost()
        await fixture.waitForCompletion()
        XCTAssertTrue(fixture.runtime.engine.engaged)
        XCTAssertTrue(fixture.kernelHeld)
        XCTAssertEqual(fixture.sleepRequests, 0)
        XCTAssertEqual(fixture.messages, ["Couldn't verify SleepDisabled was cleared."])
        XCTAssertFalse(fixture.messages.contains { $0.contains("Keep awake is unchanged.") })
    }

    func armConfirmedClosed(_ fixture: RuntimeFixture) {
        fixture.lidClosed = true
        fixture.runtime.engine.preferences.notifEnabled = true
        fixture.runtime.engine.preferences.duration = .indefinite
        let start = Date()
        _ = fixture.runtime.engine.userSetEngaged(true, now: start, lidClosed: false)
        _ = fixture.runtime.engine.observeLid(closed: true, now: start)
        _ = fixture.runtime.engine.observeLid(
            closed: true,
            now: start.addingTimeInterval(LidCloseConfirm.pulseInterval)
        )
        XCTAssertTrue(fixture.runtime.engine.lidCloseConfirmed)
        fixture.kernelHeld = true
    }

    func assertDiscordChannelMessage(_ requests: [NotifOutboundRequest]) throws {
        let discord = try XCTUnwrap(requests.first { $0.url.path.contains("/channels/") })
        XCTAssertEqual(discord.url.path, "/api/v10/channels/123/messages")
        XCTAssertFalse(discord.url.path.contains("/api/webhooks/"))
        XCTAssertFalse(discord.url.path.contains("webhooks"))
    }

    func discordContent(_ requests: [NotifOutboundRequest]) throws -> String {
        let discord = try XCTUnwrap(requests.first { $0.url.path.contains("/channels/") })
        let body = try XCTUnwrap(JSONSerialization.jsonObject(with: discord.body) as? [String: Any])
        return try XCTUnwrap(body["content"] as? String)
    }

    func telegramText(_ requests: [NotifOutboundRequest]) throws -> String {
        let telegram = try XCTUnwrap(requests.first { $0.url.path.contains("/bot") })
        let body = try XCTUnwrap(JSONSerialization.jsonObject(with: telegram.body) as? [String: Any])
        return try XCTUnwrap(body["text"] as? String)
    }
}
