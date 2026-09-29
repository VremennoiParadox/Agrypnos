import XCTest
@testable import AgrypnosCore

final class DiscordQuestionTests: XCTestCase {
    func testComponentInteractionCarriesSenderChannelMessageAndCustomID() throws {
        for userField in [#""member":{"user":{"id":"42","bot":false}},"#, #""user":{"id":"42","bot":false},"#] {
            let wire = "{\"op\":0,\"t\":\"INTERACTION_CREATE\",\"s\":12,\"d\":{\"type\":3,\"id\":\"500\",\"token\":\"token\",\"channel_id\":\"9\",\"message\":{\"id\":\"18\"},\(userField)\"data\":{\"custom_id\":\"aq:opaque\"}}}"
            let frame = try XCTUnwrap(DiscordGatewayParser.frame(from: Data(wire.utf8)))
            guard case let .questionInteraction(click) = frame.event else { return XCTFail("component not routed") }
            XCTAssertEqual(click.senderID, "42")
            XCTAssertEqual(click.reference, QuestionMessageRef(destination: .discord, destinationID: "9", messageID: "18"))
            XCTAssertEqual(click.actionToken, "opaque")
            XCTAssertEqual(click.interactionID, "500")
            var session = DiscordGatewaySession(cursor: DiscordInboundCursor(sessionId: "s", sequence: 11, seeded: true))
            XCTAssertEqual(session.handle(frame), [.questionInteraction(click)])
            XCTAssertEqual(session.cursor.sequence, 12)
        }
    }

    func testSlashPreservedAndBotOrMalformedComponentRejected() throws {
        let slash = Data(#"{"op":0,"t":"INTERACTION_CREATE","s":2,"d":{"type":2,"id":"500","token":"token","channel_id":"9","data":{"name":"status"}}}"#.utf8)
        guard case .inbound = DiscordGatewayParser.frame(from: slash)?.event else { return XCTFail("slash lost") }
        for user in [#""user":{"id":"42","bot":true},"#, #""user":{"id":true},"#, ""] {
            let wire = "{\"op\":0,\"t\":\"INTERACTION_CREATE\",\"s\":3,\"d\":{\"type\":3,\"id\":\"500\",\"token\":\"token\",\"channel_id\":\"9\",\"message\":{\"id\":\"18\"},\(user)\"data\":{\"custom_id\":\"aq:token\"}}}"
            XCTAssertEqual(DiscordGatewayParser.frame(from: Data(wire.utf8))?.event, .other)
        }
    }

    func testMessageDisablesMentionsAndKeepsFullChoices() throws {
        var registry = QuestionRegistry()
        let batch = QuestionBatch(key: QuestionKey(provider: .cursor, instanceID: "i", sessionID: "s", requestID: "r"), questions: [AgentQuestion(id: "q", prompt: "Who <@42>?", options: (1...20).map { QuestionOption(id: "o\($0)", label: "Option \($0)", detail: "Full detail \($0)") })], receivedUptime: 0, deadlineUptime: 600)
        let ref = QuestionMessageRef(destination: .discord, destinationID: "9", messageID: "18")
        let handle = UUID(); XCTAssertTrue(registry.insert(batch, handle: handle)); XCTAssertTrue(registry.bindMessage(handle: handle, reference: ref))
        let view = try XCTUnwrap(registry.view(handle: handle, reference: ref))
        let req = try XCTUnwrap(DiscordQuestionMessage.edit(view: view, botToken: "fixture", reference: ref))
        let body = try XCTUnwrap(JSONSerialization.jsonObject(with: req.body) as? [String: Any])
        let content = try XCTUnwrap(body["content"] as? String)
        XCTAssertTrue(content.contains("Full detail 20"))
        XCTAssertTrue(content.contains("<@42>"))
        XCTAssertLessThanOrEqual(content.utf16.count, 2000)
        XCTAssertEqual((body["allowed_mentions"] as? [String: Any])?["parse"] as? [String], [])
        let rows = try XCTUnwrap(body["components"] as? [[String: Any]])
        XCTAssertLessThanOrEqual(rows.count, 5)
        for row in rows {
            let buttons = try XCTUnwrap(row["components"] as? [[String: Any]])
            XCTAssertLessThanOrEqual(buttons.count, 5)
            XCTAssertTrue(buttons.allSatisfy { (($0["custom_id"] as? String)?.count ?? 101) <= 100 })
        }
        let ack = try XCTUnwrap(DiscordQuestionMessage.deferInteraction(interactionID: "500", token: "tok"))
        XCTAssertEqual((try XCTUnwrap(JSONSerialization.jsonObject(with: ack.body) as? [String: Int]))["type"], 6)
    }

    func testMessageCreationRequiresProvenID() {
        XCTAssertEqual(DiscordQuestionResponse.parse(status: 200, body: Data(#"{"id":"18","channel_id":"9"}"#.utf8)), .sent(QuestionMessageRef(destination: .discord, destinationID: "9", messageID: "18")))
        XCTAssertEqual(DiscordQuestionResponse.parse(status: 200, body: Data(#"{"id":"18"}"#.utf8)), .unconfirmed)
        XCTAssertEqual(DiscordQuestionResponse.parse(status: nil, body: Data()), .unconfirmed)
        XCTAssertEqual(DiscordQuestionResponse.parse(status: 429, body: Data(#"{"retry_after":2}"#.utf8)), .rejected(retryAfter: 2))
    }
}
