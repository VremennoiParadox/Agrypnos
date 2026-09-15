import XCTest
@testable import AgrypnosCore

final class DiscordWebhookURLTests: XCTestCase {
    func testAcceptsHTTPSDiscordIncomingWebhookHostAndPath() {
        let accepted = [
            "https://discord.com/api/webhooks/1/abc",
            "https://discordapp.com/api/webhooks/123456789012345678/token_with-dash",
            "https://canary.discord.com/api/webhooks/1/abc",
            "https://ptb.discord.com/api/webhooks/1/abc",
            "https://discord.com/api/webhooks/1/abc/",
            "https://discord.com/api/webhooks/1/abc?wait=true",
            "  https://discord.com/api/webhooks/99/Tok.en-1_2  ",
        ]
        for raw in accepted {
            XCTAssertNotNil(DiscordWebhookURL.parse(raw), "should accept \(raw)")
            XCTAssertNotNil(
                NotifOutboundRequestFactory.discord(webhookURL: raw, content: "x"),
                "factory should accept \(raw)"
            )
        }
    }

    func testRejectsHTTPWrongHostWrongPathAndMissingIdOrToken() {
        let rejected = [
            "",
            "  ",
            "http://discord.com/api/webhooks/1/abc",
            "https://",
            "https://example.com/api/webhooks/1/abc",
            "https://evil.com/api/webhooks/1/abc",
            "https://discord.com.evil.com/api/webhooks/1/abc",
            "https://notdiscord.com/api/webhooks/1/abc",
            "https://discord.com/api/webhooks",
            "https://discord.com/api/webhooks/",
            "https://discord.com/api/webhooks/1",
            "https://discord.com/api/webhooks/1/",
            "https://discord.com/api/webhooks//abc",
            "https://discord.com/api/v10/webhooks/1/abc",
            "https://discord.com/api/webhooks/1/abc/github",
            "https://discord.com/oauth2/authorize",
            "https://httpbin.org/post",
            "ftp://discord.com/api/webhooks/1/abc",
        ]
        for raw in rejected {
            XCTAssertNil(DiscordWebhookURL.parse(raw), "should reject \(raw)")
            XCTAssertNil(
                NotifOutboundRequestFactory.discord(webhookURL: raw, content: "x"),
                "factory should reject \(raw)"
            )
        }
    }
}

final class NotifOutboundRequestTests: XCTestCase {
    func testDiscordRequestPostsJSONContent() throws {
        let url = "https://discord.com/api/webhooks/1/abc"
        let request = try XCTUnwrap(
            NotifOutboundRequestFactory.discord(webhookURL: url, content: AgrypnosCopy.notifIdleBody)
        )
        XCTAssertEqual(request.url.absoluteString, url)
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.headers["Content-Type"], "application/json")
        let object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: request.body) as? [String: Any]
        )
        XCTAssertEqual(object["content"] as? String, AgrypnosCopy.notifIdleBody)
        XCTAssertNil(NotifOutboundRequestFactory.discord(webhookURL: "", content: "x"))
        XCTAssertNil(NotifOutboundRequestFactory.discord(webhookURL: "  ", content: "x"))
        XCTAssertNil(
            NotifOutboundRequestFactory.discord(
                webhookURL: "http://discord.com/api/webhooks/1/abc",
                content: "x"
            )
        )
        XCTAssertNil(NotifOutboundRequestFactory.discord(webhookURL: "https://", content: "x"))
    }

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
        XCTAssertEqual(object["chat_id"] as? String, "-1001")
        XCTAssertEqual(object["text"] as? String, AgrypnosCopy.notifIdleBody)
        XCTAssertNil(
            NotifOutboundRequestFactory.telegram(botToken: "", chatId: "1", text: "x")
        )
        XCTAssertNil(
            NotifOutboundRequestFactory.telegram(botToken: "123:token", chatId: "  ", text: "x")
        )
    }
}
