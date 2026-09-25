import XCTest
@testable import AgrypnosCore

final class DiscordInboundTransportTests: XCTestCase {
    func testReceiveOnMacUsesGatewayNotListenPortOrInteractionsURL() {
        XCTAssertNil(DiscordInboundTransport.listenPort)
        XCTAssertNil(DiscordInboundTransport.interactionsEndpointURL)
        XCTAssertFalse(DiscordInboundTransport.usesIncomingWebhook)
        XCTAssertFalse(DiscordInboundTransport.scrapeChannelHistoryOnWake)
        let url = DiscordInboundTransport.gatewayURL
        XCTAssertEqual(url.scheme, "wss")
        XCTAssertEqual(url.host, "gateway.discord.gg")
        XCTAssertTrue(url.absoluteString.contains("v=10"))
        XCTAssertFalse(url.absoluteString.contains("webhook"))
        XCTAssertFalse(url.absoluteString.contains("localhost"))
        XCTAssertNil(url.port)
    }

    func testIdentifyAndResumeAreOutboundGatewayPayloads() throws {
        let identify = try XCTUnwrap(
            DiscordGatewayPayload.identify(botToken: "BotToken.example")
        )
        XCTAssertEqual(identify["op"] as? Int, 2)
        let identifyData = try XCTUnwrap(identify["d"] as? [String: Any])
        XCTAssertEqual(identifyData["token"] as? String, "BotToken.example")
        XCTAssertEqual(identifyData["intents"] as? Int, DiscordGatewayPayload.identifyIntents)
        XCTAssertEqual(DiscordGatewayPayload.identifyIntents, 4609)
        XCTAssertNil(identify["url"])
        XCTAssertNil(
            DiscordGatewayPayload.identify(botToken: "  ")
        )

        let resume = try XCTUnwrap(
            DiscordGatewayPayload.resume(botToken: "BotToken.example", sessionId: "abc", sequence: 7)
        )
        XCTAssertEqual(resume["op"] as? Int, 6)
        let resumeData = try XCTUnwrap(resume["d"] as? [String: Any])
        XCTAssertEqual(resumeData["token"] as? String, "BotToken.example")
        XCTAssertEqual(resumeData["session_id"] as? String, "abc")
        XCTAssertEqual(resumeData["seq"] as? Int, 7)
        XCTAssertNil(DiscordGatewayPayload.resume(botToken: "x", sessionId: nil, sequence: 1))
        XCTAssertNil(DiscordGatewayPayload.resume(botToken: "x", sessionId: "s", sequence: nil))

        let heartbeat = try XCTUnwrap(DiscordGatewayPayload.heartbeat(sequence: 9))
        XCTAssertEqual(heartbeat["op"] as? Int, 1)
        XCTAssertEqual(heartbeat["d"] as? Int, 9)
        let first = try XCTUnwrap(DiscordGatewayPayload.heartbeat(sequence: nil))
        XCTAssertEqual(first["op"] as? Int, 1)
        XCTAssertTrue(first["d"] is NSNull)
    }
}

final class DiscordGatewayParserTests: XCTestCase {
    func testParsesHelloReadyMessageAndSlashInteraction() throws {
        let hello = try frame(["op": 10, "d": ["heartbeat_interval": 41250]])
        XCTAssertEqual(hello.sequence, nil)
        XCTAssertEqual(hello.event, .hello(heartbeatIntervalMs: 41250))

        let ready = try frame([
            "op": 0,
            "s": 1,
            "t": "READY",
            "d": [
                "session_id": "sess",
                "resume_gateway_url": "wss://us-east.gateway.discord.gg",
                "application": ["id": "99"],
            ],
        ])
        XCTAssertEqual(ready.sequence, 1)
        XCTAssertEqual(ready.event, .ready(sessionId: "sess", applicationId: "99", resumeGatewayURL: "wss://us-east.gateway.discord.gg"))

        let message = try frame([
            "op": 0,
            "s": 2,
            "t": "MESSAGE_CREATE",
            "d": [
                "channel_id": "123456789012345678",
                "content": "/arm",
                "author": ["bot": false],
            ],
        ])
        XCTAssertEqual(message.sequence, 2)
        guard case .inbound(let update) = message.event else {
            return XCTFail("expected inbound message")
        }
        XCTAssertEqual(update.channelId, "123456789012345678")
        XCTAssertEqual(update.text, "/arm")
        XCTAssertNil(update.interactionId)
        XCTAssertEqual(update.source, .message)

        let slash = try frame([
            "op": 0,
            "s": 3,
            "t": "INTERACTION_CREATE",
            "d": [
                "id": "i1",
                "token": "itok",
                "type": 2,
                "channel_id": "123456789012345678",
                "data": ["name": "status", "type": 1],
            ],
        ])
        guard case .inbound(let slashUpdate) = slash.event else {
            return XCTFail("expected inbound slash")
        }
        XCTAssertEqual(slashUpdate.channelId, "123456789012345678")
        XCTAssertEqual(slashUpdate.text, "status")
        XCTAssertEqual(slashUpdate.interactionId, "i1")
        XCTAssertEqual(slashUpdate.interactionToken, "itok")
        XCTAssertEqual(slashUpdate.source, .slash)

        let numeric = try frame([
            "op": 0,
            "s": 8,
            "t": "MESSAGE_CREATE",
            "d": [
                "channel_id": 99,
                "content": "help",
                "author": ["bot": false],
            ],
        ])
        guard case .inbound(let numericUpdate) = numeric.event else {
            return XCTFail("expected inbound numeric channel")
        }
        XCTAssertEqual(numericUpdate.channelId, "99")
        XCTAssertEqual(numericUpdate.text, "help")
    }

    func testIgnoresBotsWebhookMessagesSlashEchoAndNonCommandInteractions() throws {
        let bot = try frame([
            "op": 0,
            "s": 4,
            "t": "MESSAGE_CREATE",
            "d": [
                "channel_id": "1",
                "content": "/arm",
                "author": ["bot": true],
            ],
        ])
        XCTAssertEqual(bot.event, .other)

        let webhook = try frame([
            "op": 0,
            "s": 5,
            "t": "MESSAGE_CREATE",
            "d": [
                "channel_id": "1",
                "content": "/arm",
                "webhook_id": "99",
                "author": ["bot": false],
            ],
        ])
        XCTAssertEqual(webhook.event, .other)

        let echo = try frame([
            "op": 0,
            "s": 6,
            "t": "MESSAGE_CREATE",
            "d": [
                "channel_id": "1",
                "content": "/arm",
                "author": ["bot": false],
                "interaction": ["id": "i1", "name": "arm"],
            ],
        ])
        XCTAssertEqual(echo.event, .other)

        let metadata = try frame([
            "op": 0,
            "s": 9,
            "t": "MESSAGE_CREATE",
            "d": [
                "channel_id": "1",
                "content": "/arm",
                "author": ["bot": false],
                "interaction_metadata": ["id": "i1", "name": "arm"],
            ],
        ])
        XCTAssertEqual(metadata.event, .other)

        let button = try frame([
            "op": 0,
            "s": 7,
            "t": "INTERACTION_CREATE",
            "d": [
                "id": "i2",
                "token": "t",
                "type": 3,
                "channel_id": "1",
                "data": ["name": "arm"],
            ],
        ])
        XCTAssertEqual(button.event, .other)
    }

    func testParsesReconnectInvalidSessionAndHeartbeatAck() throws {
        XCTAssertEqual(try frame(["op": 7]).event, .reconnect)
        XCTAssertEqual(try frame(["op": 9, "d": false]).event, .invalidSession(resumable: false))
        XCTAssertEqual(try frame(["op": 9, "d": true]).event, .invalidSession(resumable: true))
        XCTAssertEqual(try frame(["op": 11]).event, .heartbeatAck)
        XCTAssertEqual(try frame(["op": 1, "d": 8]).event, .heartbeat)
        XCTAssertEqual(try frame(["op": 0, "s": 9, "t": "RESUMED"]).event, .resumed)
        XCTAssertNil(DiscordGatewayParser.frame(from: Data()))
        XCTAssertNil(DiscordGatewayParser.frame(from: Data("not-json".utf8)))
    }

    func testIdentifyOmitsPrivilegedMessageContent() {
        XCTAssertEqual(DiscordGatewayPayload.identifyIntents, 4609)
        XCTAssertEqual(DiscordGatewayPayload.identifyIntents & (1 << 15), 0)
    }

    func testInvalidSessionClearsResumeWhenNotResumable() {
        let live = DiscordInboundCursor(sessionId: "s", sequence: 8, seeded: true)
        let dropped = live.invalidatingSession(resumable: false)
        XCTAssertNil(dropped.sessionId)
        XCTAssertNil(dropped.sequence)
        XCTAssertFalse(dropped.canResume)
        XCTAssertFalse(DiscordInboundTransport.scrapeChannelHistoryOnWake)

        let keep = live.invalidatingSession(resumable: true)
        XCTAssertEqual(keep.sessionId, "s")
        XCTAssertEqual(keep.sequence, 8)
        XCTAssertTrue(keep.canResume)
    }

    func testUnseededReadyAcknowledgesWithoutApplying() {
        XCTAssertFalse(DiscordInboundCursor.unset.shouldApplyCommands)
        let next = DiscordInboundCursor.unset.acknowledging(
            sequence: 1,
            sessionId: "sess",
            resumeGatewayURL: "wss://us-east.gateway.discord.gg"
        )
        XCTAssertTrue(next.seeded)
        XCTAssertEqual(next.sessionId, "sess")
        XCTAssertEqual(next.sequence, 1)
        XCTAssertEqual(next.resumeGatewayURL, "wss://us-east.gateway.discord.gg")
        XCTAssertTrue(next.canResume)
        XCTAssertTrue(next.shouldApplyCommands)
    }

    func testRecordingSequenceDoesNotSeedDuringResumeReplay() {
        var cursor = DiscordInboundCursor(sessionId: "s", sequence: 40, seeded: true).startingWakeMiss()
        XCTAssertEqual(cursor.drain, .wakeMiss)
        cursor = cursor.recording(sequence: 41)
        XCTAssertFalse(cursor.shouldApplyCommands)
        XCTAssertEqual(cursor.sequence, 41)
        XCTAssertEqual(cursor.drain, .wakeMiss)
        XCTAssertEqual(
            TelegramInboundDispatch.effect(drain: cursor.drain, intent: .arm),
            .missedWhileAsleep
        )
        var engine = WatchEngine(preferences: .default)
        let t0 = Date(timeIntervalSince1970: 1)
        XCTAssertEqual(
            TelegramInboundDispatch.effect(drain: cursor.drain, intent: .arm),
            .missedWhileAsleep
        )
        XCTAssertTrue(engine.applyInbound(.ignore, now: t0).isEmpty)
        XCTAssertFalse(engine.engaged)

        cursor = cursor.recording(sequence: 42)
        cursor = cursor.acknowledging(sequence: 42)
        XCTAssertEqual(cursor.drain, .live)
        XCTAssertTrue(cursor.shouldApplyCommands)
        XCTAssertEqual(
            TelegramInboundDispatch.effect(drain: cursor.drain, intent: .arm),
            .apply(.arm)
        )
    }

    private func frame(_ object: [String: Any]) throws -> DiscordGatewayFrame {
        let data = try JSONSerialization.data(withJSONObject: object)
        return try XCTUnwrap(DiscordGatewayParser.frame(from: data))
    }
}

final class DiscordInboundNoListenPortTests: XCTestCase {
    func testRequestFactoryNeverOpensALocalCallback() throws {
        let app = try XCTUnwrap(DiscordInboundRequestFactory.currentApplication(botToken: "t"))
        XCTAssertNotEqual(app.url.host, "127.0.0.1")
        XCTAssertNotEqual(app.url.scheme, "http")
        XCTAssertNil(DiscordInboundRequestFactory.interactionsEndpointRegistration())
        XCTAssertNil(DiscordInboundRequestFactory.channelMessages(botToken: "t", channelId: "1"))
        let gatewayBot = try XCTUnwrap(DiscordInboundRequestFactory.gatewayBot(botToken: "t"))
        XCTAssertEqual(gatewayBot.httpMethod, "GET")
        XCTAssertEqual(gatewayBot.url.host, "discord.com")
        XCTAssertEqual(gatewayBot.url.path, "/api/v10/gateway/bot")
        XCTAssertFalse(gatewayBot.url.path.contains("webhooks"))
        XCTAssertEqual(
            DiscordGatewayBotParser.url(from: Data("{\"url\":\"wss://gateway.discord.gg\"}".utf8))?.host,
            "gateway.discord.gg"
        )
        XCTAssertNil(DiscordGatewayBotParser.url(from: Data()))
    }
}
