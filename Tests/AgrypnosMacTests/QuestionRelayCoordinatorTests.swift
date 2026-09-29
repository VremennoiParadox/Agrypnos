import XCTest
import AgrypnosCore
@testable import AgrypnosMac

@MainActor
final class QuestionRelayCoordinatorTests: XCTestCase {
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
        early.now = 30
        early.relay.expireDueQuestions()
        await early.yieldTasks()
        XCTAssertFalse(early.events.contains { if case .expired = $0 { return true }; return false })
        XCTAssertTrue(early.events.contains { if case .cleared = $0 { return true }; return false })
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
    var events: [QuestionRelayEvent] = []
    var holdCreate = false
    var reply = QuestionHTTPResponse(statusCode: 200, body: Data(#"{"ok":true,"result":{"message_id":18,"chat":{"id":9}}}"#.utf8))
    var batch = QuestionBatch(key: QuestionKey(provider: .cursor, instanceID: "app", sessionID: "thread", requestID: "r"), questions: [AgentQuestion(id: "q", prompt: "Which?", options: [QuestionOption(id: "a", label: "Alpha"), QuestionOption(id: "b", label: "Beta")], multiple: true)], receivedUptime: 0, deadlineUptime: 600)
    lazy var relay = QuestionRelayCoordinator(settings: { [unowned self] in settings },
        transport: { [unowned self] request in
            requests.append(request)
            if request.url.path.hasSuffix("/sendMessage") {
                if holdCreate { return await withCheckedContinuation { creation = $0 } }
                return reply
            }
            return QuestionHTTPResponse(statusCode: 200, body: Data(#"{"ok":true}"#.utf8))
        }, uptime: { [unowned self] in now }, onChange: { [unowned self] in events.append($0) })

    var createCount: Int { requests.filter { $0.url.path.hasSuffix("/sendMessage") }.count }
    var editCount: Int { requests.filter { $0.url.path.hasSuffix("/editMessageText") }.count }
    var messages: [String] { requests.compactMap { (try? JSONSerialization.jsonObject(with: $0.body) as? [String: Any])?["text"] as? String } }
    func receive() -> Bool {
        relay.receive(batch, submit: { [unowned self] answer in
            submissions.append(answer)
            return await withCheckedContinuation { delivery = $0 }
        }, returnLocal: { [unowned self] in localReturns += 1 })
    }
    func callback(_ label: String) throws -> TelegramQuestionCallback {
        let request = try XCTUnwrap(requests.last { $0.url.path.hasSuffix("/editMessageText") })
        let body = try XCTUnwrap(JSONSerialization.jsonObject(with: request.body) as? [String: Any])
        let rows = try XCTUnwrap((body["reply_markup"] as? [String: Any])?["inline_keyboard"] as? [[[String: String]]])
        let data = try XCTUnwrap(rows.flatMap { $0 }.first { $0["text"] == label }?["callback_data"])
        return TelegramQuestionCallback(id: UUID().uuidString, senderID: "42", reference: QuestionMessageRef(destination: .telegram, destinationID: "9", messageID: "18"), actionToken: String(data.dropFirst(3)))
    }
    func click(_ label: String) throws { relay.handleTelegram(try callback(label), drain: .live) }
    func yieldTasks() async { for _ in 0..<100 { await Task.yield() } }
    func waitForEdits(_ count: Int) async { for _ in 0..<200 where editCount < count { await Task.yield() }; XCTAssertGreaterThanOrEqual(editCount, count) }
    func waitForSubmissions(_ count: Int) async { for _ in 0..<200 where submissions.count < count { await Task.yield() }; XCTAssertEqual(submissions.count, count) }
}
