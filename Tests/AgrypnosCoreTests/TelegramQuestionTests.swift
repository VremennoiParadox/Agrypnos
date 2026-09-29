import XCTest
@testable import AgrypnosCore

final class TelegramQuestionTests: XCTestCase {
    func testCallbackCarriesExactSenderChatMessageAndNeverBecomesCommand() throws {
        let data = Data(#"{"ok":true,"result":[{"update_id":7,"callback_query":{"id":"click","from":{"id":42},"message":{"message_id":18,"chat":{"id":-9},"text":"/disarm"},"data":"aq:opaque"}},{"update_id":8,"message":{"chat":{"id":-9},"text":"/status"}}]}"#.utf8)
        let updates = TelegramGetUpdatesParser.parse(data)
        XCTAssertEqual(updates.count, 2)
        let callback = try XCTUnwrap(updates[0].callback)
        XCTAssertEqual(callback.id, "click")
        XCTAssertEqual(callback.senderID, "42")
        XCTAssertEqual(callback.reference, QuestionMessageRef(destination: .telegram, destinationID: "-9", messageID: "18"))
        XCTAssertEqual(callback.actionToken, "opaque")
        XCTAssertEqual(TelegramInboundPolicy.intent(enabled: true, botToken: "fixture", savedChatId: "-9", update: updates[0]), .ignore)
        XCTAssertEqual(TelegramInboundPolicy.intent(enabled: true, botToken: "fixture", savedChatId: "-9", update: updates[1]), .status)
        XCTAssertEqual(TelegramInboundOffset.next(current: 0, updates: updates), 9)
    }

    func testMalformedCallbackStillConsumesOffsetAndCannotDisarm() throws {
        for sender in ["null", "true", "1.5", #""42""#] {
            let data = Data("{\"ok\":true,\"result\":[{\"update_id\":10,\"message\":{\"chat\":{\"id\":9},\"text\":\"/disarm\"},\"callback_query\":{\"id\":\"x\",\"from\":{\"id\":\(sender)},\"message\":{\"message_id\":1,\"chat\":{\"id\":9}},\"data\":\"aq:token\"}}]}".utf8)
            let update = try XCTUnwrap(TelegramGetUpdatesParser.parse(data).first)
            XCTAssertTrue(update.isCallback)
            XCTAssertNil(update.callback)
            XCTAssertEqual(TelegramInboundPolicy.intent(enabled: true, botToken: "fixture", savedChatId: "9", update: update), .ignore)
            XCTAssertEqual(TelegramInboundOffset.next(current: 0, updates: [update]), 11)
        }
    }

    func testPanelsKeepFullTextAndOnlyOfferSubmitAfterReview() throws {
        let batch = questionBatch()
        var registry = QuestionRegistry()
        let handle = UUID(), reference = QuestionMessageRef(destination: .telegram, destinationID: "9", messageID: "1")
        XCTAssertTrue(registry.insert(batch, handle: handle))
        XCTAssertTrue(registry.bindMessage(handle: handle, reference: reference))
        let view = try XCTUnwrap(registry.view(handle: handle, reference: reference))
        let request = try XCTUnwrap(TelegramQuestionMessage.requests(view: view, botToken: "fixture", chatID: "9").first)
        let body = try XCTUnwrap(JSONSerialization.jsonObject(with: request.body) as? [String: Any])
        let text = try XCTUnwrap(body["text"] as? String)
        XCTAssertTrue(text.contains("Choose <one>"))
        XCTAssertTrue(text.contains("Complete **description**"))
        XCTAssertNil(body["parse_mode"])
        let rows = try XCTUnwrap((body["reply_markup"] as? [String: Any])?["inline_keyboard"] as? [[[String: String]]])
        XCTAssertFalse(rows.flatMap { $0 }.contains { $0["text"] == "Send answers" })
        XCTAssertTrue(rows.flatMap { $0 }.allSatisfy { ($0["callback_data"]?.utf8.count ?? 999) <= 64 })
        for action in [QuestionAction.choose(questionID: "q", optionID: "a"), .next] {
            let current = try XCTUnwrap(registry.view(handle: handle, reference: reference))
            let token = try XCTUnwrap(current.controls.first { $0.action == action }?.token)
            _ = registry.handle(QuestionCallback(reference: reference, senderID: "42", actionToken: token, generation: 0), authorizedUserID: "42", now: 1)
        }
        let review = try XCTUnwrap(registry.view(handle: handle, reference: reference))
        let reviewRequest = try XCTUnwrap(TelegramQuestionMessage.requests(view: review, botToken: "fixture", chatID: "9").first)
        XCTAssertTrue(String(decoding: reviewRequest.body, as: UTF8.self).contains("Send answers"))
    }

    func testSendRequiresProvenMessageIdentityAndRateLimitIsExplicit() {
        XCTAssertEqual(TelegramQuestionResponse.parse(status: 200, body: Data(#"{"ok":true,"result":{"message_id":18,"chat":{"id":9}}}"#.utf8)), .sent(QuestionMessageRef(destination: .telegram, destinationID: "9", messageID: "18")))
        for body in [#"{"ok":true}"#, #"{"ok":true,"result":{"message_id":true,"chat":{"id":9}}}"#, "garbage"] {
            XCTAssertEqual(TelegramQuestionResponse.parse(status: 200, body: Data(body.utf8)), .unconfirmed)
        }
        XCTAssertEqual(TelegramQuestionResponse.parse(status: nil, body: Data()), .unconfirmed)
        XCTAssertEqual(TelegramQuestionResponse.parse(status: 429, body: Data(#"{"ok":false,"parameters":{"retry_after":3}}"#.utf8)), .rejected(retryAfter: 3))
        XCTAssertEqual(TelegramQuestionResponse.parse(status: 200, body: Data(#"{"ok":false}"#.utf8)), .rejected(retryAfter: nil))
    }

    func testOptInMigrationAndAuthorizedUsersStaySeparateFromPreferences() throws {
        var prefs = UserPreferences.default
        XCTAssertFalse(prefs.forwardAgentQuestions)
        var old = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(prefs)) as? [String: Any])
        old.removeValue(forKey: "forwardAgentQuestions")
        XCTAssertFalse(try JSONDecoder().decode(UserPreferences.self, from: JSONSerialization.data(withJSONObject: old)).forwardAgentQuestions)
        prefs.forwardAgentQuestions = true
        XCTAssertTrue(try JSONDecoder().decode(UserPreferences.self, from: JSONEncoder().encode(prefs)).forwardAgentQuestions)
        let secrets = NotifSecretsPayload(discordWebhookURL: "https://example.test", telegramBotToken: "fixture", telegramChatId: "9", discordBotToken: "discord", discordChannelId: "10", telegramQuestionUserId: "42", discordQuestionUserId: "43")
        XCTAssertEqual(NotifSecretsPayload.decode(try XCTUnwrap(NotifSecretsPayload.encode(secrets))), secrets)
        XCTAssertNil(NotifSecretsPayload.decode(Data("{}".utf8))?.telegramQuestionUserId)
    }

    private func questionBatch() -> QuestionBatch {
        QuestionBatch(key: QuestionKey(provider: .cursor, instanceID: "app", sessionID: "thread", requestID: "req"), questions: [AgentQuestion(id: "q", prompt: "Choose <one>", options: [QuestionOption(id: "a", label: "Alpha", detail: "Complete **description**"), QuestionOption(id: "b", label: "Beta")])], receivedUptime: 0, deadlineUptime: 600)
    }
}
