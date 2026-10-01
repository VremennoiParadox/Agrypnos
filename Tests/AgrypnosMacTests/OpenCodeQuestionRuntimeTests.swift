import Foundation
import XCTest
import AgrypnosCore
@testable import AgrypnosMac

@MainActor
final class OpenCodeQuestionRuntimeTests: XCTestCase {
    func testMoreThan32SequentialAnswersDoNotExhaustCapacityOrReplay() async throws {
        let fixture = OpenCodeRuntimeFixture()
        fixture.runtime.syncQuestionSources()
        for number in 0..<35 {
            let event = Data(String(decoding: fixture.asked, as: UTF8.self)
                .replacingOccurrences(of: "que_123", with: "que_Sequence\(number)").utf8)
            let edits = fixture.editCount
            try fixture.source.ingest(event)
            await fixture.waitForEdits(edits + 1)
            XCTAssertEqual(fixture.runtime.questionRelay.pendingDeadlines.count, 1)
            try fixture.click("2")
            await fixture.waitForEdits(edits + 2)
            try fixture.click("Review / next")
            await fixture.waitForEdits(edits + 3)
            try fixture.click("Send answers")
            await fixture.waitForNativeReplies(number + 1)
            await fixture.waitForAcceptedMessages(number + 1)
            await fixture.yieldTasks()
            let creates = fixture.botRequests.filter { $0.url.path.hasSuffix("/sendMessage") }.count
            let resolved = #"{"directory":"/project","payload":{"type":"question.replied","properties":{"sessionID":"ses_456","requestID":"que_123"}}}"#
                .replacingOccurrences(of: "que_123", with: "que_Sequence\(number)")
            try fixture.source.ingest(Data(resolved.utf8))
            try fixture.source.reconcilePending(Data("[]".utf8))
            try fixture.source.ingest(event)
            await fixture.yieldTasks()
            XCTAssertEqual(fixture.botRequests.filter { $0.url.path.hasSuffix("/sendMessage") }.count, creates)
        }
        XCTAssertEqual(fixture.nativeReplies.count, 35)
        fixture.stop()
    }

    func testOriginalOpenCodeEventByteStreamReachesTheRuntimeRelay() async throws {
        let fixture = OpenCodeRuntimeFixture()
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [RuntimeOpenCodeStream.self]
        fixture.streamSession = URLSession(configuration: configuration)
        let message = expectation(description: "question forwarded from SSE")
        fixture.onBotCreate = { message.fulfill() }
        fixture.runtime.syncQuestionSources()
        await fulfillment(of: [message], timeout: 2)
        await fixture.waitForEdits(1)
        XCTAssertEqual(fixture.runtime.openCodeQuestionState, .connected)
        XCTAssertEqual(fixture.runtime.questionRelay.pendingDeadlines.count, 1)
        let paths = fixture.nativeRequests.compactMap { $0.url?.path }
        XCTAssertEqual(paths, ["/global/health", "/question"])
        fixture.stop()
    }

    func testManualOffInvalidatesPhoneControlsAndPreservesForwardingForFutureQuestions() async throws {
        let fixture = OpenCodeRuntimeFixture()
        fixture.runtime.syncQuestionSources()
        try fixture.source.ingest(fixture.asked)
        await fixture.waitForEdits(1)
        let old = try fixture.callback("2")
        let original = try fixture.source
        XCTAssertNotNil(fixture.runtime.disarmWatch())
        XCTAssertFalse(original === fixture.runtime.openCodeQuestionSource)
        fixture.runtime.questionRelay.handleTelegram(old, drain: .live)
        await fixture.yieldTasks()
        XCTAssertTrue(fixture.nativeReplies.isEmpty)
        XCTAssertTrue(fixture.runtime.preferences.forwardAgentQuestions)
        XCTAssertTrue(fixture.runtime.questionRelay.pendingDeadlines.isEmpty)
        fixture.stop()
    }

    func testNativeAnswerAfterRemoteExpiryClearsDeferredWatchEnd() async throws {
        let fixture = OpenCodeRuntimeFixture()
        _ = fixture.runtime.engine.userSetEngaged(true, now: Date(), lidClosed: false)
        fixture.runtime.syncQuestionSources()
        try fixture.source.ingest(fixture.asked)
        XCTAssertEqual(fixture.runtime.questionDeadlines.count, 1)
        fixture.now = 600
        fixture.runtime.questionRelay.expireDueQuestions()
        _ = fixture.runtime.questionWaitDecision(agents: AgentSnapshot(reports: []), observeAgents: false)
        XCTAssertEqual(fixture.runtime.questionUnansweredKeys.count, 1)
        await fixture.yieldTasks()
        try fixture.source.ingest(Data(#"{"directory":"/project","payload":{"type":"question.replied","properties":{"sessionID":"ses_456","requestID":"que_123"}}}"#.utf8))
        XCTAssertTrue(fixture.runtime.questionUnansweredKeys.isEmpty)
        XCTAssertTrue(fixture.runtime.questionDeadlines.isEmpty)
        XCTAssertTrue(fixture.nativeReplies.isEmpty)
        fixture.stop()
    }

    func testLocalAnswerWhileDisconnectedClearsExpiredWatchDecisionAtReconciliation() async throws {
        let fixture = OpenCodeRuntimeFixture()
        _ = fixture.runtime.engine.userSetEngaged(true, now: Date(), lidClosed: false)
        fixture.runtime.syncQuestionSources()
        try fixture.source.ingest(fixture.asked)
        fixture.now = 600
        fixture.runtime.questionRelay.expireDueQuestions()
        _ = fixture.runtime.questionWaitDecision(agents: AgentSnapshot(reports: []), observeAgents: false)
        await fixture.yieldTasks()
        XCTAssertEqual(fixture.runtime.questionUnansweredKeys.count, 1)
        try fixture.source.connectionLost()
        try fixture.source.reconcilePending(Data("[]".utf8))
        XCTAssertTrue(fixture.runtime.questionUnansweredKeys.isEmpty)
        XCTAssertTrue(fixture.runtime.questionDeadlines.isEmpty)
        XCTAssertNotEqual(fixture.runtime.questionWaitDecision(agents: AgentSnapshot(reports: []), observeAgents: true).0.action, .endUnanswered)
        XCTAssertTrue(fixture.nativeReplies.isEmpty)
        fixture.stop()
    }

    func testReconnectReissuesVerifiedQuestionWithItsOriginalDeadline() async throws {
        let fixture = OpenCodeRuntimeFixture()
        fixture.runtime.syncQuestionSources()
        try fixture.source.ingest(fixture.asked)
        await fixture.waitForEdits(1)
        let key = try XCTUnwrap(fixture.runtime.questionRelay.pendingDeadlines.keys.first)
        let oldClick = try fixture.callback("2")
        try fixture.source.connectionLost()
        fixture.now = 200
        let envelope = try XCTUnwrap(JSONSerialization.jsonObject(with: fixture.asked) as? [String: Any])
        let payload = try XCTUnwrap(envelope["payload"] as? [String: Any])
        try fixture.source.reconcilePending(JSONSerialization.data(withJSONObject: [try XCTUnwrap(payload["properties"])]))
        await fixture.waitForEdits(3)
        XCTAssertEqual(fixture.runtime.questionRelay.pendingDeadlines[key], 600)
        fixture.runtime.questionRelay.handleTelegram(oldClick, drain: .live)
        await fixture.yieldTasks()
        XCTAssertTrue(fixture.nativeReplies.isEmpty)
        try fixture.click("2")
        await fixture.waitForEdits(4)
        try fixture.click("Review / next")
        await fixture.waitForEdits(5)
        try fixture.click("Send answers")
        await fixture.waitForNativeReplies(1)
        fixture.stop()
    }

    func testDiscordControlsSubmitToTheSameNativeRequest() async throws {
        let fixture = OpenCodeRuntimeFixture()
        fixture.secrets.telegramQuestionUserId = nil
        fixture.secrets.discordBotToken = "fixture-discord"
        fixture.secrets.discordChannelId = "10"
        fixture.secrets.discordQuestionUserId = "43"
        fixture.runtime.engine.preferences.discordInboundEnabled = true
        fixture.runtime.syncQuestionSources()
        try fixture.source.ingest(fixture.asked)
        await fixture.waitForDiscordEdits(1)
        try fixture.discordClick("2")
        await fixture.waitForDiscordEdits(2)
        try fixture.discordClick("Review / next")
        await fixture.waitForDiscordEdits(3)
        try fixture.discordClick("Send answers")
        await fixture.waitForNativeReplies(1)
        let body = try XCTUnwrap(fixture.nativeReplies.first?.httpBody)
        XCTAssertEqual((try JSONSerialization.jsonObject(with: body) as? [String: Any])?["answers"] as? [[String]], [["B"]])
        XCTAssertFalse(fixture.runtime.engaged)
        fixture.stop()
    }

    func testNativeEventThroughRuntimeBotControlsSubmitsOriginalAnswerOnceWithoutArming() async throws {
        let fixture = OpenCodeRuntimeFixture()
        fixture.runtime.syncQuestionSources()
        try fixture.source.ingest(fixture.asked)
        await fixture.waitForEdits(1)
        XCTAssertFalse(fixture.runtime.engaged)
        XCTAssertTrue(fixture.runtime.questionDeadlines.isEmpty)
        try fixture.click("2")
        await fixture.waitForEdits(2)
        try fixture.click("Review / next")
        await fixture.waitForEdits(3)
        let send = try fixture.callback("Send answers")
        fixture.runtime.questionRelay.handleTelegram(send, drain: .live)
        fixture.runtime.questionRelay.handleTelegram(send, drain: .live)
        await fixture.waitForNativeReplies(1)
        let request = try XCTUnwrap(fixture.nativeReplies.first)
        XCTAssertEqual(request.url?.path, "/question/que_123/reply")
        XCTAssertEqual(request.httpMethod, "POST")
        let body = try XCTUnwrap(request.httpBody)
        XCTAssertEqual((try JSONSerialization.jsonObject(with: body) as? [String: Any])?["answers"] as? [[String]], [["B"]])
        XCTAssertFalse(fixture.runtime.engaged)
        fixture.stop()
    }

    func testSettingsRequireOptInSelectedOpenCodeAndAnAuthorizedInboundDestination() {
        let fixture = OpenCodeRuntimeFixture()
        fixture.runtime.engine.preferences.forwardAgentQuestions = false
        fixture.runtime.syncQuestionSources()
        XCTAssertNil(fixture.runtime.openCodeQuestionSource)
        fixture.runtime.engine.preferences.forwardAgentQuestions = true
        fixture.runtime.engine.preferences.includedAgentKinds = [.cursor]
        fixture.runtime.syncQuestionSources()
        XCTAssertNil(fixture.runtime.openCodeQuestionSource)
        fixture.runtime.engine.preferences.includedAgentKinds = [.openCode]
        fixture.secrets.telegramQuestionUserId = nil
        fixture.runtime.syncQuestionSources()
        XCTAssertNil(fixture.runtime.openCodeQuestionSource)
        fixture.secrets.telegramQuestionUserId = "42"
        fixture.runtime.syncQuestionSources()
        XCTAssertNotNil(fixture.runtime.openCodeQuestionSource)
        fixture.stop()
    }

    func testUnchangedSettingsKeepPendingControlsAndOriginalSource() async throws {
        let fixture = OpenCodeRuntimeFixture()
        fixture.runtime.syncQuestionSources()
        let original = try fixture.source
        original.ingest(fixture.asked)
        await fixture.waitForEdits(1)
        fixture.runtime.setForwardAgentQuestions(true)
        fixture.runtime.syncQuestionSources()
        XCTAssertTrue(original === fixture.runtime.openCodeQuestionSource)
        XCTAssertEqual(fixture.runtime.questionRelay.pendingDeadlines.count, 1)
        fixture.stop()
    }

    func testChangedDestinationInvalidatesOldControlsBeforeReconnecting() async throws {
        let fixture = OpenCodeRuntimeFixture()
        fixture.runtime.syncQuestionSources()
        let original = try fixture.source
        original.ingest(fixture.asked)
        await fixture.waitForEdits(1)
        let oldClick = try fixture.callback("2")
        fixture.secrets.telegramQuestionUserId = "99"
        fixture.runtime.syncQuestionSources()
        XCTAssertFalse(original === fixture.runtime.openCodeQuestionSource)
        XCTAssertTrue(fixture.runtime.questionRelay.pendingDeadlines.isEmpty)
        fixture.runtime.questionRelay.handleTelegram(oldClick, drain: .live)
        await fixture.yieldTasks()
        XCTAssertTrue(fixture.nativeReplies.isEmpty)
        fixture.stop()
    }

    func testReturningOnMacAndSleepNeverRejectTheNativeQuestion() async throws {
        let fixture = OpenCodeRuntimeFixture()
        fixture.runtime.syncQuestionSources()
        try fixture.source.ingest(fixture.asked)
        await fixture.waitForEdits(1)
        try fixture.click("Answer on Mac")
        await fixture.yieldTasks()
        XCTAssertTrue(fixture.runtime.questionRelay.pendingDeadlines.isEmpty)
        XCTAssertTrue(fixture.nativeReplies.isEmpty)
        fixture.runtime.noteMacWillSleep()
        XCTAssertNil(fixture.runtime.openCodeQuestionSource)
        fixture.runtime.syncQuestionSources()
        XCTAssertNil(fixture.runtime.openCodeQuestionSource)
        fixture.stop()
    }

    func testInvalidConnectionMakesNoNetworkRequest() async {
        let fixture = OpenCodeRuntimeFixture()
        fixture.secrets.openCodeQuestions?.endpoint = "http://example.com:4096"
        fixture.runtime.syncQuestionSources()
        await fixture.yieldTasks()
        XCTAssertNil(fixture.runtime.openCodeQuestionSource)
        XCTAssertTrue(fixture.nativeRequests.isEmpty)
        XCTAssertTrue(fixture.botRequests.isEmpty)
        fixture.stop()
    }
}

@MainActor
private final class OpenCodeRuntimeFixture {
    var now: TimeInterval = 0
    var streamSession: URLSession?
    var onBotCreate: (() -> Void)?
    var nextTelegramMessageID = 18
    var secrets = NotifSecrets(telegramBotToken: "fixture", telegramChatId: "9",
        telegramQuestionUserId: "42", openCodeQuestions:
            OpenCodeQuestionSettings(endpoint: "http://127.0.0.1:4096", directory: "/project"))
    var nativeRequests: [URLRequest] = []
    var botRequests: [NotifOutboundRequest] = []
    let defaults = UserDefaults(suiteName: "agrypnos-opencode-" + UUID().uuidString)!
    let asked = Data(#"{"directory":"/project","payload":{"type":"question.asked","properties":{"id":"que_123","sessionID":"ses_456","questions":[{"question":"Which letter?","options":[{"label":"A","description":"First"},{"label":"B","description":"Second"}]}]}}}"#.utf8)
    lazy var runtime: WatchRuntime = {
        let runtime = WatchRuntime(store: PreferencesStore(defaults: defaults),
            readLid: { false }, readKernel: { .clear }, setKernel: { _ in .ok },
            runCommand: { _, _ in XCTFail("Question forwarding must not run power commands"); return (0, "", "") },
            notify: { _ in }, readNotifSecrets: { [weak self] in self?.secrets ?? NotifSecrets() },
            questionTransport: { [weak self] request in
                self?.botRequests.append(request)
                if request.url.path.hasSuffix("/sendMessage") {
                    self?.onBotCreate?()
                    let id = self?.nextTelegramMessageID ?? 18
                    self?.nextTelegramMessageID += 1
                    return QuestionHTTPResponse(statusCode: 200,
                        body: Data("{\"ok\":true,\"result\":{\"message_id\":\(id),\"chat\":{\"id\":9}}}".utf8))
                }
                if request.httpMethod == "POST", request.url.path.hasSuffix("/messages") {
                    return QuestionHTTPResponse(statusCode: 200, body: Data(#"{"id":"19","channel_id":"10"}"#.utf8))
                }
                return QuestionHTTPResponse(statusCode: 200, body: Data(#"{"ok":true}"#.utf8))
            }, openCodeQuestionExchange: { [weak self] request in
                self?.nativeRequests.append(request)
                // Hold health I/O until stop; these tests drive captured events directly.
                // A failed health response would correctly invalidate those controls.
                if self?.streamSession != nil {
                    return QuestionHTTPResponse(statusCode: 200, body: request.url?.path == "/global/health"
                        ? Data(#"{"healthy":true,"version":"1.18.32"}"#.utf8) : Data("[]".utf8))
                }
                if request.httpMethod != "POST" { try? await Task.sleep(nanoseconds: 60_000_000_000) }
                return QuestionHTTPResponse(statusCode: request.httpMethod == "POST" ? 200 : nil,
                    body: request.httpMethod == "POST" ? Data("true".utf8) : Data())
            }, openCodeQuestionStreamSession: streamSession)
        runtime.questionUptime = { [weak self] in self?.now ?? 0 }
        runtime.engine.preferences.forwardAgentQuestions = true
        runtime.engine.preferences.telegramInboundEnabled = true
        runtime.engine.preferences.includedAgentKinds = [.openCode]
        return runtime
    }()

    var source: OpenCodeQuestionSource { get throws { try XCTUnwrap(runtime.openCodeQuestionSource) } }
    var nativeReplies: [URLRequest] { nativeRequests.filter { $0.httpMethod == "POST" } }
    var editCount: Int { botRequests.filter { $0.url.path.hasSuffix("/editMessageText") }.count }
    var discordEditCount: Int { botRequests.filter { $0.httpMethod == "PATCH" }.count }

    func discordClick(_ label: String) throws {
        let request = try XCTUnwrap(botRequests.last { $0.httpMethod == "PATCH" })
        let body = try XCTUnwrap(JSONSerialization.jsonObject(with: request.body) as? [String: Any])
        let rows = try XCTUnwrap(body["components"] as? [[String: Any]])
        let token = try XCTUnwrap(rows.compactMap { $0["components"] as? [[String: Any]] }.flatMap { $0 }
            .first { $0["label"] as? String == label }?["custom_id"] as? String)
        let wire: [String: Any] = ["type": 3, "id": String(1000 + botRequests.count), "token": "fixture-interaction",
            "channel_id": "10", "message": ["id": "19"], "user": ["id": "43", "bot": false], "data": ["custom_id": token]]
        runtime.questionRelay.handleDiscord(try XCTUnwrap(DiscordQuestionInteraction.parse(wire)), drain: .live)
    }

    func callback(_ label: String) throws -> TelegramQuestionCallback {
        let request = try XCTUnwrap(botRequests.last { $0.url.path.hasSuffix("/editMessageText") })
        let body = try XCTUnwrap(JSONSerialization.jsonObject(with: request.body) as? [String: Any])
        let rows = try XCTUnwrap((body["reply_markup"] as? [String: Any])?["inline_keyboard"] as? [[[String: String]]])
        let token = try XCTUnwrap(rows.flatMap { $0 }.first { $0["text"] == label }?["callback_data"])
        let messageID = try XCTUnwrap(body["message_id"] as? NSNumber).stringValue
        return TelegramQuestionCallback(id: UUID().uuidString, senderID: "42",
            reference: QuestionMessageRef(destination: .telegram, destinationID: "9", messageID: messageID),
            actionToken: String(token.dropFirst(3)))
    }

    func click(_ label: String) throws { runtime.questionRelay.handleTelegram(try callback(label), drain: .live) }
    func yieldTasks() async { for _ in 0..<200 { await Task.yield() } }
    func waitForEdits(_ count: Int) async {
        for _ in 0..<500 where editCount < count { await Task.yield() }
        XCTAssertGreaterThanOrEqual(editCount, count)
    }
    func waitForAcceptedMessages(_ count: Int) async {
        func acceptedCount() -> Int {
            botRequests.filter { request in
                let body = try? JSONSerialization.jsonObject(with: request.body) as? [String: Any]
                return (body?["text"] as? String)?.contains("agent accepted the answers") == true
            }.count
        }
        for _ in 0..<500 where acceptedCount() < count { await Task.yield() }
        XCTAssertEqual(acceptedCount(), count)
    }
    func waitForNativeReplies(_ count: Int) async {
        for _ in 0..<500 where nativeReplies.count < count { await Task.yield() }
        XCTAssertEqual(nativeReplies.count, count)
    }
    func waitForDiscordEdits(_ count: Int) async {
        for _ in 0..<500 where discordEditCount < count { await Task.yield() }
        XCTAssertGreaterThanOrEqual(discordEditCount, count)
    }
    func stop() { runtime.stopQuestionSources(); runtime.questionRelay.invalidateAll() }
}

private final class RuntimeOpenCodeStream: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        client?.urlProtocol(self, didReceive: HTTPURLResponse(url: request.url!, statusCode: 200,
            httpVersion: "HTTP/1.1", headerFields: ["Content-Type": "text/event-stream"])!, cacheStoragePolicy: .notAllowed)
        let event = #"data: {"directory":"/project","payload":{"type":"question.asked","properties":{"id":"que_123","sessionID":"ses_456","questions":[{"question":"Which letter?","options":[{"label":"A","description":"First"},{"label":"B","description":"Second"}]}]}}}"#
        client?.urlProtocol(self, didLoad: Data((event + "\n\n").utf8))
        // Remain connected until the owner cancels, just like the native SSE server.
    }
    override func stopLoading() {}
}
