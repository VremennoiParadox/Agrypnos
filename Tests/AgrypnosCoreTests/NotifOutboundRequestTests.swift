import XCTest
@testable import AgrypnosCore

final class NotifOutboundRequestTests: XCTestCase {
    func testTelegramRequestPostsChatAndText() throws {
        let request = try XCTUnwrap(
            NotifOutboundRequestFactory.telegram(
                botToken: "123:token",
                chatId: "-1001",
                text: AgrypnosCopy.notifIdleBody
            )
        )
        XCTAssertEqual(
            request.url.absoluteString,
            "https://api.telegram.org/bot123:token/sendMessage"
        )
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.headers["Content-Type"], "application/json")
        let object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: request.body) as? [String: Any]
        )
        XCTAssertEqual(object["text"] as? String, AgrypnosCopy.notifIdleBody)
        XCTAssertEqual((object["chat_id"] as? NSNumber)?.int64Value, -1001)
        XCTAssertNil(object["chat_id"] as? String)
        let large = try XCTUnwrap(
            NotifOutboundRequestFactory.telegram(
                botToken: "111:AA" + String(repeating: "A", count: 35),
                chatId: "5728126329",
                text: "x"
            )
        )
        XCTAssertEqual(large.url.host, "api.telegram.org")
        XCTAssertTrue(large.url.path.hasPrefix("/bot111:"))
        XCTAssertTrue(large.url.path.hasSuffix("/sendMessage"))
        let largeObject = try XCTUnwrap(
            JSONSerialization.jsonObject(with: large.body) as? [String: Any]
        )
        XCTAssertEqual((largeObject["chat_id"] as? NSNumber)?.int64Value, 5_728_126_329)
        XCTAssertNil(
            NotifOutboundRequestFactory.telegram(botToken: "", chatId: "1", text: "x")
        )
        XCTAssertNil(
            NotifOutboundRequestFactory.telegram(botToken: "123:token", chatId: "  ", text: "x")
        )
    }
}

final class NotifOutboundPostChromeTests: XCTestCase {
    func testDiscordAccepts2xxAndRejectsHTTPErrors() {
        XCTAssertEqual(
            NotifOutboundPostChrome.outcome(channel: .discord, statusCode: 204, body: Data()),
            .accepted
        )
        XCTAssertEqual(
            NotifOutboundPostChrome.outcome(channel: .discord, statusCode: 401, body: Data()),
            .rejected
        )
        XCTAssertEqual(
            NotifOutboundPostChrome.outcome(channel: .discord, statusCode: nil, body: Data()),
            .unreachable
        )
    }

    func testTelegramRequiresOkTrue() throws {
        let ok = try JSONSerialization.data(withJSONObject: ["ok": true])
        let notOk = try JSONSerialization.data(withJSONObject: ["ok": false, "description": "Bad Request"])
        XCTAssertEqual(
            NotifOutboundPostChrome.outcome(channel: .telegram, statusCode: 200, body: ok),
            .accepted
        )
        XCTAssertEqual(
            NotifOutboundPostChrome.outcome(channel: .telegram, statusCode: 200, body: notOk),
            .rejected
        )
        XCTAssertEqual(
            NotifOutboundPostChrome.outcome(channel: .telegram, statusCode: 400, body: notOk),
            .rejected
        )
        XCTAssertEqual(
            AgrypnosCopy.notifTelegramPostFailed,
            "Couldn't message your Telegram bot."
        )
        XCTAssertEqual(
            AgrypnosCopy.notifDiscordPostFailed,
            "Couldn't POST to your webhook."
        )
        XCTAssertEqual(
            AgrypnosCopy.notifTelegramChatInvalid,
            "That is not a Telegram chat id. Nothing was saved."
        )
        XCTAssertNil(NotifOutboundPostChrome.notifyCopy(channel: .discord, outcome: .accepted))
        XCTAssertEqual(
            NotifOutboundPostChrome.notifyCopy(channel: .discord, outcome: .rejected),
            AgrypnosCopy.notifDiscordPostFailed
        )
        XCTAssertEqual(
            NotifOutboundPostChrome.notifyCopy(channel: .telegram, outcome: .unreachable),
            AgrypnosCopy.notifTelegramPostFailed
        )
        XCTAssertEqual(
            NotifOutboundPostChrome.notifyCopy(
                channel: .telegram,
                outcome: .rejected,
                detail: "Unauthorized"
            ),
            "Couldn't message your Telegram bot. Unauthorized"
        )
        XCTAssertEqual(
            NotifOutboundPostChrome.telegramDetail(
                body: try JSONSerialization.data(withJSONObject: ["ok": false, "description": "Unauthorized"])
            ),
            "Unauthorized"
        )
        XCTAssertEqual(
            NotifOutboundPostChrome.channel(for: URL(string: "https://api.telegram.org/bot1/sendMessage")!),
            .telegram
        )
        XCTAssertEqual(
            NotifOutboundPostChrome.channel(for: URL(string: "https://discord.com/api/webhooks/1/abc")!),
            .discord
        )
    }
}
