import XCTest
import AgrypnosCore
@testable import AgrypnosMac

@MainActor
final class QuestionRelayCoordinatorTests: XCTestCase {
    func testUnrenderableLaterDiscordPanelStaysLocalBeforeOfferingControls() async {
        let fixture = QuestionRelayFixture()
        fixture.use(.discord)
        let later = AgentQuestion(id: "later", prompt: String(repeating: "[]()", count: 300),
            options: [QuestionOption(id: "a", label: "Alpha")])
        fixture.batch = QuestionBatch(key: fixture.batch.key, questions: fixture.batch.questions + [later],
            receivedUptime: 0, deadlineUptime: 600)
        var registry = QuestionRegistry()
        XCTAssertTrue(registry.insert(fixture.batch, handle: UUID()))
        XCTAssertFalse(fixture.receive())
        await fixture.yieldTasks()
        XCTAssertTrue(fixture.requests.isEmpty)
        XCTAssertTrue(fixture.relay.pendingDeadlines.isEmpty)
        XCTAssertTrue(fixture.events.isEmpty)
    }
    func testCancellationCoalescesOverAnInFlightFailedEditOnBothBots() async throws {
        for destination in [QuestionDestination.telegram, .discord] {
            let fixture = QuestionRelayFixture()
            fixture.use(destination)
            XCTAssertTrue(fixture.receive())
            await fixture.waitForEdits(1)
            fixture.holdNextEdit = true
            try fixture.click("1", on: destination)
            await fixture.waitForEdits(2)
            fixture.relay.cancel(key: fixture.batch.key)
            fixture.editing?.resume(returning: fixture.rateLimit(destination, seconds: 2))
            fixture.editing = nil
            await fixture.waitForEdits(3)
            let final = try XCTUnwrap(fixture.requests.last { fixture.isEdit($0) })
            let body = try XCTUnwrap(JSONSerialization.jsonObject(with: final.body) as? [String: Any])
            XCTAssertTrue(((body["text"] ?? body["content"]) as? String)?.contains("no longer available remotely") == true)
            XCTAssertTrue(fixture.retryDelays.isEmpty)
            XCTAssertTrue(fixture.submissions.isEmpty)
        }
    }

    func testPermanentEditFailureClosesControlsAndReturnsLocalOnBothBots() async {
        for destination in [QuestionDestination.telegram, .discord] {
            let fixture = QuestionRelayFixture()
            fixture.use(destination)
            fixture.editResponses = [QuestionHTTPResponse(statusCode: 403, body: Data())]
            XCTAssertTrue(fixture.receive())
            await fixture.yieldTasks()
            XCTAssertEqual(fixture.localReturns, 1)
            XCTAssertTrue(fixture.relay.pendingDeadlines.isEmpty)
            XCTAssertTrue(fixture.retryDelays.isEmpty)
            XCTAssertTrue(fixture.submissions.isEmpty)
        }
    }

    func testFailedInitialEditRecoversOnBothBotsWithoutExtendingDeadline() async throws {
        for destination in [QuestionDestination.telegram, .discord] {
            let fixture = QuestionRelayFixture()
            fixture.use(destination)
            fixture.editResponses = [fixture.rateLimit(destination, seconds: 2),
                QuestionHTTPResponse(statusCode: nil, body: Data())]
            XCTAssertTrue(fixture.receive())
            await fixture.waitForEdits(3)
            XCTAssertEqual(fixture.retryDelays, [2, 2])
            XCTAssertEqual(fixture.relay.pendingDeadlines[fixture.batch.key], 600)
            try fixture.click("1", on: destination)
            await fixture.waitForEdits(4)
            try fixture.click("Review / next", on: destination)
            await fixture.waitForEdits(5)
            try fixture.click("Send answers", on: destination)
            await fixture.waitForSubmissions(1)
            fixture.delivery?.resume(returning: .accepted); fixture.delivery = nil
            await fixture.yieldTasks()
            XCTAssertEqual(fixture.submissions.count, 1)
        }
    }

    func testFailedSelectionEditRetriesTheSameControlsOnBothBots() async throws {
        for destination in [QuestionDestination.telegram, .discord] {
            let fixture = QuestionRelayFixture()
            fixture.use(destination)
            XCTAssertTrue(fixture.receive())
            await fixture.waitForEdits(1)
            fixture.editResponses = [QuestionHTTPResponse(statusCode: nil, body: Data())]
            try fixture.click("1", on: destination)
            await fixture.waitForEdits(3)
            let edits = fixture.requests.filter { fixture.isEdit($0) }
            XCTAssertEqual(edits[1].body, edits[2].body)
            try fixture.click("Review / next", on: destination)
            await fixture.waitForEdits(4)
            try fixture.click("Send answers", on: destination)
            await fixture.waitForSubmissions(1)
            fixture.delivery?.resume(returning: .accepted); fixture.delivery = nil
        }
    }

    func testEditRetryPastOriginalDeadlineReturnsLocalOnBothBots() async {
        for destination in [QuestionDestination.telegram, .discord] {
            let fixture = QuestionRelayFixture()
            fixture.use(destination)
            fixture.now = 599
            fixture.editResponses = [fixture.rateLimit(destination, seconds: 2)]
            XCTAssertTrue(fixture.receive())
            await fixture.yieldTasks()
            XCTAssertTrue(fixture.retryDelays.isEmpty)
            XCTAssertEqual(fixture.localReturns, 1)
            XCTAssertTrue(fixture.relay.pendingDeadlines.isEmpty)
            XCTAssertTrue(fixture.submissions.isEmpty)
        }
    }

    func testNativeCancellationEditsBothMessagesToUnavailable() async {
        let fixture = QuestionRelayFixture()
        fixture.settings.discord = DiscordQuestionDestination(token: "discord", channelID: "10", userID: "43")
        XCTAssertTrue(fixture.receive())
        await fixture.waitForEdits(2)
        fixture.relay.cancel(key: fixture.batch.key)
        await fixture.waitForEdits(4)
        for request in fixture.requests.suffix(2) {
            let body = try? JSONSerialization.jsonObject(with: request.body) as? [String: Any]
            let text = (body?["text"] ?? body?["content"]) as? String
            XCTAssertTrue(text?.contains("no longer available remotely") == true)
        }
        XCTAssertTrue(fixture.relay.pendingDeadlines.isEmpty)
    }

    func testReviewSubmitReservesBeforeAwaitAndAckDoesNotProveDelivery() async throws {
        let fixture = QuestionRelayFixture()
        XCTAssertTrue(fixture.receive())
        await fixture.waitForEdits(1)
        try fixture.click("1")
        await fixture.waitForEdits(2)
        try fixture.click("Review / next")
        await fixture.waitForEdits(3)
        let send = try fixture.callback("Send answers")
        fixture.relay.handleTelegram(send, drain: .live)
        fixture.relay.handleTelegram(send, drain: .live)
        XCTAssertTrue(fixture.relay.pendingDeadlines.isEmpty)
        await fixture.waitForSubmissions(1)
        XCTAssertEqual(fixture.submissions.count, 1)
        XCTAssertTrue(fixture.messages.contains { $0.contains("Sending answers") })
        XCTAssertFalse(fixture.messages.contains { $0.contains("agent accepted") })
        fixture.delivery?.resume(returning: .unconfirmed)
        fixture.delivery = nil
        await fixture.waitForEdits(5)
        XCTAssertTrue(fixture.messages.contains { $0.contains("delivery is unconfirmed") })
        fixture.now = 601
        fixture.relay.expireDueQuestions()
        XCTAssertFalse(fixture.events.contains { if case .expired = $0 { return true }; return false })
    }

    func testUnauthorizedAndWakeMissClicksCannotSelectOrSubmit() async throws {
        let fixture = QuestionRelayFixture()
        XCTAssertTrue(fixture.receive())
        await fixture.waitForEdits(1)
        let click = try fixture.callback("1")
        let outsider = TelegramQuestionCallback(id: "outsider", senderID: "99", reference: click.reference, actionToken: click.actionToken)
        fixture.relay.handleTelegram(outsider, drain: .live)
        fixture.relay.handleTelegram(click, drain: .wakeMiss)
        await fixture.yieldTasks()
        XCTAssertEqual(fixture.editCount, 1)
        XCTAssertTrue(fixture.submissions.isEmpty)
    }

    func testLocalCancellationDuringNativeSendRejectsLateCompletion() async throws {
        let fixture = QuestionRelayFixture()
        XCTAssertTrue(fixture.receive())
        await fixture.waitForEdits(1)
        try fixture.click("1"); await fixture.waitForEdits(2)
        try fixture.click("Review / next"); await fixture.waitForEdits(3)
        try fixture.click("Send answers"); await fixture.waitForSubmissions(1)
        fixture.relay.cancel(key: fixture.batch.key)
        fixture.delivery?.resume(returning: .accepted); fixture.delivery = nil
        await fixture.yieldTasks()
        XCTAssertFalse(fixture.messages.contains { $0.contains("agent accepted") })
    }

    func testAmbiguousMessageCreationReturnsLocalWithoutBlindRetry() async {
        let fixture = QuestionRelayFixture()
        fixture.reply = QuestionHTTPResponse(statusCode: 200, body: Data(#"{"ok":true}"#.utf8))
        XCTAssertTrue(fixture.receive())
        await fixture.yieldTasks()
        XCTAssertEqual(fixture.createCount, 1)
        XCTAssertEqual(fixture.localReturns, 1)
        XCTAssertTrue(fixture.relay.pendingDeadlines.isEmpty)
        XCTAssertFalse(fixture.receive())
    }

    func testInvalidationBeforeMessageResponseCannotReviveControls() async {
        let fixture = QuestionRelayFixture()
        fixture.holdCreate = true
        XCTAssertTrue(fixture.receive())
        await fixture.yieldTasks()
        XCTAssertNotNil(fixture.creation)
        fixture.relay.invalidateAll()
        fixture.creation?.resume(returning: fixture.reply); fixture.creation = nil
        await fixture.yieldTasks()
        XCTAssertEqual(fixture.editCount, 0)
        XCTAssertEqual(fixture.localReturns, 1)
        XCTAssertTrue(fixture.relay.pendingDeadlines.isEmpty)
    }

    func testTimeoutOnceAndNativeExpiryDoesNotBecomeUnansweredTenMinutes() async {
        let fixture = QuestionRelayFixture()
        XCTAssertTrue(fixture.receive())
        fixture.now = 600
        fixture.relay.expireDueQuestions()
        fixture.relay.expireDueQuestions()
        await fixture.yieldTasks()
        XCTAssertEqual(fixture.localReturns, 1)
        XCTAssertEqual(fixture.events.filter { if case .expired = $0 { return true }; return false }.count, 1)
        let early = QuestionRelayFixture()
        early.batch = QuestionBatch(key: early.batch.key, questions: early.batch.questions, receivedUptime: 0, deadlineUptime: 30)
        XCTAssertTrue(early.receive())
        XCTAssertTrue(early.events.contains { if case let .observed(_, deadline) = $0 { return deadline == 600 }; return false })
        early.now = 30
        early.relay.expireDueQuestions()
        await early.yieldTasks()
        XCTAssertFalse(early.events.contains { if case .expired = $0 { return true }; return false })
        XCTAssertTrue(early.events.contains { if case .cleared = $0 { return true }; return false })
    }

    func testFirstCompleteAnswerWinsAcrossTelegramAndDiscord() async throws {
        let fixture = QuestionRelayFixture()
        fixture.settings.discord = DiscordQuestionDestination(token: "discord", channelID: "10", userID: "43")
        XCTAssertTrue(fixture.receive())
        await fixture.waitForEdits(2)
        XCTAssertNotNil(fixture.discordCallback("1"))
        fixture.relay.handleDiscord(try XCTUnwrap(fixture.discordCallback("1")), drain: .live)
        await fixture.waitForEdits(4)
        fixture.relay.handleDiscord(try XCTUnwrap(fixture.discordCallback("Review / next")), drain: .live)
        await fixture.waitForEdits(6)
        let discordSend = try XCTUnwrap(fixture.discordCallback("Send answers"))
        try fixture.click("1")
        await fixture.waitForEdits(8)
        try fixture.click("Review / next")
        await fixture.waitForEdits(10)
        try fixture.click("Send answers")
        await fixture.waitForSubmissions(1)
        fixture.relay.handleDiscord(discordSend, drain: .live)
        await fixture.yieldTasks()
        XCTAssertEqual(fixture.submissions.count, 1)
        fixture.delivery?.resume(returning: .accepted); fixture.delivery = nil
    }

    func testDisabledAndMissingOwnerNeverForward() async {
        let fixture = QuestionRelayFixture()
        fixture.settings.enabled = false
        XCTAssertFalse(fixture.receive())
        fixture.settings.enabled = true
        fixture.settings.telegram = nil
        XCTAssertFalse(fixture.receive())
        await fixture.yieldTasks()
        XCTAssertEqual(fixture.createCount, 0)
    }

    func testInvalidationDuringNativeSubmissionNeverReturnsLocalToo() async throws {
        let fixture = QuestionRelayFixture()
        XCTAssertTrue(fixture.receive())
        await fixture.waitForEdits(1)
        try fixture.click("1"); await fixture.waitForEdits(2)
        try fixture.click("Review / next"); await fixture.waitForEdits(3)
        try fixture.click("Send answers"); await fixture.waitForSubmissions(1)
        fixture.relay.invalidateAll()
        await fixture.yieldTasks()
        XCTAssertEqual(fixture.localReturns, 0)
        fixture.delivery?.resume(returning: .unconfirmed); fixture.delivery = nil
    }

    func testChangedProjectLabelReturnsOriginalQuestionLocally() async {
        let fixture = QuestionRelayFixture()
        XCTAssertTrue(fixture.receive())
        fixture.batch = QuestionBatch(key: fixture.batch.key, projectLabel: "Changed",
            questions: fixture.batch.questions, receivedUptime: 0, deadlineUptime: 600)
        XCTAssertFalse(fixture.receive())
        await fixture.yieldTasks()
        XCTAssertEqual(fixture.localReturns, 1)
        XCTAssertTrue(fixture.relay.pendingDeadlines.isEmpty)
        XCTAssertTrue(fixture.events.contains { if case .cleared = $0 { return true }; return false })
    }

    func testDuplicateShorterNativeDeadlineExpiresLocallyWithoutTenMinuteEvent() async {
        let fixture = QuestionRelayFixture()
        XCTAssertTrue(fixture.receive())
        fixture.batch = QuestionBatch(key: fixture.batch.key, questions: fixture.batch.questions,
            receivedUptime: 0, deadlineUptime: 30)
        XCTAssertFalse(fixture.receive())
        XCTAssertEqual(fixture.relay.pendingDeadlines[fixture.batch.key], 30)
        fixture.now = 30
        fixture.relay.expireDueQuestions()
        await fixture.yieldTasks()
        XCTAssertEqual(fixture.localReturns, 1)
        XCTAssertFalse(fixture.events.contains { if case .expired = $0 { return true }; return false })
    }

    func testAlreadyDueNativeDeadlineUpdateClearsOldButtonsImmediately() async {
        let fixture = QuestionRelayFixture()
        XCTAssertTrue(fixture.receive())
        fixture.now = 31
        fixture.batch = QuestionBatch(key: fixture.batch.key, questions: fixture.batch.questions,
            receivedUptime: 0, deadlineUptime: 30)
        XCTAssertFalse(fixture.receive())
        await fixture.yieldTasks()
        XCTAssertTrue(fixture.relay.pendingDeadlines.isEmpty)
        XCTAssertEqual(fixture.localReturns, 1)
        XCTAssertFalse(fixture.events.contains { if case .expired = $0 { return true }; return false })
    }
}

@MainActor
private final class QuestionRelayFixture {
    var now: TimeInterval = 0
    var settings = QuestionRelaySettings(enabled: true, includedKinds: [.cursor], telegram: TelegramQuestionDestination(token: "fixture", chatID: "9", userID: "42"))
    var requests: [NotifOutboundRequest] = []
    var submissions: [QuestionAnswer] = []
    var delivery: CheckedContinuation<QuestionDelivery, Never>?
    var creation: CheckedContinuation<QuestionHTTPResponse, Never>?
    var localReturns = 0
    var interactionCounter = 500
    var events: [QuestionRelayEvent] = []
    var holdCreate = false
    var holdNextEdit = false
    var editing: CheckedContinuation<QuestionHTTPResponse, Never>?
    var editResponses: [QuestionHTTPResponse] = []
    var retryDelays: [TimeInterval] = []
    var reply = QuestionHTTPResponse(statusCode: 200, body: Data(#"{"ok":true,"result":{"message_id":18,"chat":{"id":9}}}"#.utf8))
    var batch = QuestionBatch(key: QuestionKey(provider: .cursor, instanceID: "app", sessionID: "thread", requestID: "r"), questions: [AgentQuestion(id: "q", prompt: "Which?", options: [QuestionOption(id: "a", label: "Alpha"), QuestionOption(id: "b", label: "Beta")], multiple: true)], receivedUptime: 0, deadlineUptime: 600)
    lazy var relay = QuestionRelayCoordinator(settings: { [weak self] in self?.settings ?? QuestionRelaySettings(enabled: false, includedKinds: [], telegram: nil) },
        transport: { [weak self] request in
            guard let self else { return QuestionHTTPResponse(statusCode: nil, body: Data()) }
            requests.append(request)
            if isEdit(request), holdNextEdit {
                holdNextEdit = false
                return await withCheckedContinuation { self.editing = $0 }
            }
            if isEdit(request), !editResponses.isEmpty { return editResponses.removeFirst() }
            if request.url.path.hasSuffix("/sendMessage") {
                if holdCreate { return await withCheckedContinuation { self.creation = $0 } }
                return reply
            }
            if request.httpMethod == "POST", request.url.path.hasSuffix("/messages") {
                return QuestionHTTPResponse(statusCode: 200, body: Data(#"{"id":"19","channel_id":"10"}"#.utf8))
            }
            return QuestionHTTPResponse(statusCode: 200, body: Data(#"{"ok":true}"#.utf8))
        }, uptime: { [weak self] in self?.now ?? 0 },
        retryWait: { [weak self] seconds in self?.retryDelays.append(seconds); await Task.yield() },
        onChange: { [weak self] in self?.events.append($0) })

    func isEdit(_ request: NotifOutboundRequest) -> Bool {
        request.url.path.hasSuffix("/editMessageText") || request.httpMethod == "PATCH"
    }
    func rateLimit(_ destination: QuestionDestination, seconds: Int) -> QuestionHTTPResponse {
        QuestionHTTPResponse(statusCode: 429, body: Data((destination == .telegram
            ? "{\"ok\":false,\"parameters\":{\"retry_after\":\(seconds)}}"
            : "{\"retry_after\":\(seconds)}").utf8))
    }
    func use(_ destination: QuestionDestination) {
        if destination == .discord {
            settings.telegram = nil
            settings.discord = DiscordQuestionDestination(token: "discord", channelID: "10", userID: "43")
        }
    }
    func click(_ label: String, on destination: QuestionDestination) throws {
        if destination == .telegram { try click(label) }
        else { relay.handleDiscord(try XCTUnwrap(discordCallback(label)), drain: .live) }
    }

    var createCount: Int { requests.filter { $0.url.path.hasSuffix("/sendMessage") }.count }
    var editCount: Int { requests.filter { $0.url.path.hasSuffix("/editMessageText") || ($0.httpMethod == "PATCH" && $0.url.path.hasSuffix("/messages/19")) }.count }
    var messages: [String] { requests.compactMap { (try? JSONSerialization.jsonObject(with: $0.body) as? [String: Any])?["text"] as? String } }
    func receive() -> Bool {
        relay.receive(batch, submit: { [weak self] answer in
            guard let self else { return .unconfirmed }
            submissions.append(answer)
            return await withCheckedContinuation { self.delivery = $0 }
        }, returnLocal: { [weak self] in self?.localReturns += 1 })
    }
    func callback(_ label: String) throws -> TelegramQuestionCallback {
        let request = try XCTUnwrap(requests.last { $0.url.path.hasSuffix("/editMessageText") })
        let body = try XCTUnwrap(JSONSerialization.jsonObject(with: request.body) as? [String: Any])
        let rows = try XCTUnwrap((body["reply_markup"] as? [String: Any])?["inline_keyboard"] as? [[[String: String]]])
        let data = try XCTUnwrap(rows.flatMap { $0 }.first { $0["text"] == label }?["callback_data"])
        return TelegramQuestionCallback(id: UUID().uuidString, senderID: "42", reference: QuestionMessageRef(destination: .telegram, destinationID: "9", messageID: "18"), actionToken: String(data.dropFirst(3)))
    }
    func click(_ label: String) throws { relay.handleTelegram(try callback(label), drain: .live) }
    func discordCallback(_ label: String) -> DiscordQuestionInteraction? {
        guard let request = requests.last(where: { $0.httpMethod == "PATCH" && $0.url.path.hasSuffix("/messages/19") }),
              let body = try? JSONSerialization.jsonObject(with: request.body) as? [String: Any],
              let rows = body["components"] as? [[String: Any]],
              let token = rows.compactMap({ $0["components"] as? [[String: Any]] }).flatMap({ $0 })
                  .first(where: { $0["label"] as? String == label })?["custom_id"] as? String
        else { return nil }
        interactionCounter += 1
        let wire: [String: Any] = ["type": 3, "id": String(interactionCounter), "token": "interaction", "channel_id": "10", "message": ["id": "19"], "user": ["id": "43", "bot": false], "data": ["custom_id": token]]
        return DiscordQuestionInteraction.parse(wire)
    }

    func yieldTasks() async { for _ in 0..<100 { await Task.yield() } }
    func waitForEdits(_ count: Int) async { for _ in 0..<200 where editCount < count { await Task.yield() }; XCTAssertGreaterThanOrEqual(editCount, count) }
    func waitForSubmissions(_ count: Int) async { for _ in 0..<200 where submissions.count < count { await Task.yield() }; XCTAssertEqual(submissions.count, count) }
}
