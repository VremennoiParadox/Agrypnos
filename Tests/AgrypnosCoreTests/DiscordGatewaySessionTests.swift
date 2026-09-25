import XCTest
@testable import AgrypnosCore

final class DiscordInboundCursorCodecTests: XCTestCase {
    func testRoundTripsSessionSequenceWakeMissAndResumeURL() throws {
        let live = DiscordInboundCursor(
            sessionId: "sess-1",
            sequence: 41,
            seeded: true,
            wakeMiss: false,
            resumeGatewayURL: "wss://us-east.gateway.discord.gg"
        )
        let data = DiscordInboundCursorCodec.encode(live)
        let decoded = DiscordInboundCursorCodec.decode(data)
        XCTAssertEqual(decoded.sessionId, "sess-1")
        XCTAssertEqual(decoded.sequence, 41)
        XCTAssertTrue(decoded.seeded)
        XCTAssertFalse(decoded.wakeMiss)
        XCTAssertEqual(decoded.resumeGatewayURL, "wss://us-east.gateway.discord.gg")
        XCTAssertTrue(decoded.canResume)
        XCTAssertEqual(decoded.drain, .live)
    }

    func testNilOrJunkDataIsUnset() {
        XCTAssertEqual(DiscordInboundCursorCodec.decode(nil), .unset)
        XCTAssertEqual(DiscordInboundCursorCodec.decode(Data()), .unset)
        XCTAssertEqual(DiscordInboundCursorCodec.decode(Data("not-json".utf8)), .unset)
        let decodedUnset = DiscordInboundCursorCodec.decode(
            DiscordInboundCursorCodec.encode(.unset)
        )
        XCTAssertEqual(decodedUnset.sessionId, nil)
        XCTAssertFalse(decodedUnset.seeded)
    }

    func testWakeMissSurvivesEncodeWhenUnseeded() {
        let miss = DiscordInboundCursor(
            sessionId: "s",
            sequence: 9,
            seeded: false,
            wakeMiss: true,
            resumeGatewayURL: "wss://gateway.discord.gg"
        )
        let decoded = DiscordInboundCursorCodec.decode(DiscordInboundCursorCodec.encode(miss))
        XCTAssertEqual(decoded.drain, .wakeMiss)
        XCTAssertFalse(decoded.shouldApplyCommands)
        XCTAssertEqual(decoded.sessionId, "s")
        XCTAssertEqual(decoded.sequence, 9)
    }
}

final class DiscordGatewayURLFactoryTests: XCTestCase {
    func testPrefersResumeGatewayURLWhenCursorCanResume() throws {
        let bot = Data("{\"url\":\"wss://gateway.discord.gg\"}".utf8)
        let url = try XCTUnwrap(
            DiscordGatewayURLFactory.socketURL(
                gatewayBotData: bot,
                resumeGatewayURL: "wss://us-east.gateway.discord.gg",
                canResume: true
            )
        )
        XCTAssertEqual(url.scheme, "wss")
        XCTAssertEqual(url.host, "us-east.gateway.discord.gg")
        XCTAssertTrue(url.absoluteString.contains("v=10"))
        XCTAssertTrue(url.absoluteString.contains("encoding=json"))
        XCTAssertNil(url.port)
        XCTAssertFalse(url.absoluteString.contains("webhook"))
        XCTAssertFalse(url.absoluteString.contains("localhost"))
    }

    func testFallsBackToGatewayBotThenTransportWhenResumeMissing() throws {
        let bot = Data("{\"url\":\"wss://gateway.discord.gg\"}".utf8)
        let fromBot = try XCTUnwrap(
            DiscordGatewayURLFactory.socketURL(
                gatewayBotData: bot,
                resumeGatewayURL: nil,
                canResume: false
            )
        )
        XCTAssertEqual(fromBot.host, "gateway.discord.gg")
        XCTAssertTrue(fromBot.absoluteString.contains("v=10"))

        let fallback = DiscordGatewayURLFactory.socketURL(
            gatewayBotData: Data(),
            resumeGatewayURL: "https://evil.example",
            canResume: true
        )
        XCTAssertEqual(fallback, DiscordInboundTransport.gatewayURL)
        XCTAssertNil(DiscordInboundTransport.listenPort)
        XCTAssertNil(DiscordInboundTransport.interactionsEndpointURL)
    }

    func testRejectsNonGatewayHosts() {
        XCTAssertNil(DiscordGatewayURLFactory.resumeURL(from: "wss://example.com"))
        XCTAssertNil(DiscordGatewayURLFactory.resumeURL(from: "https://gateway.discord.gg"))
        XCTAssertNil(DiscordGatewayURLFactory.resumeURL(from: "  "))
        XCTAssertNil(DiscordInboundRequestFactory.interactionsEndpointRegistration())
        XCTAssertNil(DiscordInboundRequestFactory.channelMessages(botToken: "x", channelId: "1"))
    }
}

final class DiscordGatewaySessionTests: XCTestCase {
    func testHelloWithoutResumeSendsIdentify() {
        var session = DiscordGatewaySession(cursor: .unset)
        XCTAssertEqual(session.handle(hello(41250)), [.sendIdentify])
        XCTAssertEqual(session.heartbeatIntervalMs, 41250)
        XCTAssertFalse(session.cursor.canResume)
    }

    func testHelloWithResumeSendsResume() {
        let cursor = DiscordInboundCursor(sessionId: "s", sequence: 8, seeded: true)
        var session = DiscordGatewaySession(cursor: cursor)
        XCTAssertEqual(session.handle(hello(20000)), [.sendResume])
        XCTAssertTrue(session.cursor.canResume)
    }

    func testOpcodeOneSendsHeartbeat() {
        var session = DiscordGatewaySession(cursor: .unset)
        XCTAssertEqual(session.handle(DiscordGatewayFrame(op: 1, sequence: nil, event: .heartbeat)), [.sendHeartbeat])
    }

    func testReadyAcknowledgesAndRegistersCommands() {
        var session = DiscordGatewaySession(cursor: .unset)
        _ = session.handle(hello(10000))
        let effects = session.handle(
            DiscordGatewayFrame(
                op: 0,
                sequence: 1,
                event: .ready(
                    sessionId: "sess",
                    applicationId: "99",
                    resumeGatewayURL: "wss://us-east.gateway.discord.gg"
                )
            )
        )
        XCTAssertEqual(effects, [.registerCommands(applicationId: "99")])
        XCTAssertTrue(session.cursor.seeded)
        XCTAssertEqual(session.cursor.sessionId, "sess")
        XCTAssertEqual(session.cursor.sequence, 1)
        XCTAssertEqual(session.cursor.resumeGatewayURL, "wss://us-east.gateway.discord.gg")
        XCTAssertEqual(session.cursor.drain, .live)
        XCTAssertTrue(session.cursor.shouldApplyCommands)
    }

    func testRecordingDuringResumeReplayDoesNotSeedUntilResumed() {
        let wake = DiscordInboundCursor(sessionId: "s", sequence: 40, seeded: true).startingWakeMiss()
        var session = DiscordGatewaySession(cursor: wake)
        XCTAssertEqual(session.cursor.drain, .wakeMiss)
        let inbound = DiscordInboundUpdate(channelId: "1", text: "/arm")
        let effects = session.handle(
            DiscordGatewayFrame(op: 0, sequence: 41, event: .inbound(inbound))
        )
        XCTAssertEqual(effects, [.inbound(inbound)])
        XCTAssertFalse(session.cursor.shouldApplyCommands)
        XCTAssertEqual(session.cursor.sequence, 41)
        XCTAssertEqual(session.cursor.drain, .wakeMiss)
        XCTAssertEqual(
            TelegramInboundDispatch.effect(drain: session.cursor.drain, intent: .arm),
            .missedWhileAsleep
        )

        let resumed = session.handle(
            DiscordGatewayFrame(op: 0, sequence: 42, event: .resumed)
        )
        XCTAssertTrue(resumed.isEmpty)
        XCTAssertTrue(session.cursor.seeded)
        XCTAssertEqual(session.cursor.drain, .live)
        XCTAssertEqual(session.cursor.sequence, 42)
    }

    func testLeftoverInboundDoesNotApply() {
        var session = DiscordGatewaySession(cursor: DiscordInboundCursor.unset.startingSession())
        let inbound = DiscordInboundUpdate(channelId: "1", text: "/disarm")
        _ = session.handle(DiscordGatewayFrame(op: 0, sequence: 1, event: .inbound(inbound)))
        XCTAssertEqual(session.cursor.drain, .leftover)
        XCTAssertEqual(
            TelegramInboundDispatch.effect(drain: session.cursor.drain, intent: .disarm),
            .ignore
        )
    }

    func testInvalidSessionClearsOrKeepsResume() {
        let live = DiscordInboundCursor(sessionId: "s", sequence: 8, seeded: true)
        var drop = DiscordGatewaySession(cursor: live)
        XCTAssertEqual(
            drop.handle(DiscordGatewayFrame(op: 9, sequence: nil, event: .invalidSession(resumable: false))),
            [.sendIdentify]
        )
        XCTAssertFalse(drop.cursor.canResume)
        XCTAssertNil(drop.cursor.sessionId)

        var keep = DiscordGatewaySession(cursor: live)
        XCTAssertEqual(
            keep.handle(DiscordGatewayFrame(op: 9, sequence: nil, event: .invalidSession(resumable: true))),
            [.sendResume]
        )
        XCTAssertTrue(keep.cursor.canResume)
    }

    func testReconnectAsksTheClientToReconnect() {
        let live = DiscordInboundCursor(sessionId: "s", sequence: 8, seeded: true)
        var session = DiscordGatewaySession(cursor: live)
        XCTAssertEqual(
            session.handle(DiscordGatewayFrame(op: 7, sequence: nil, event: .reconnect)),
            [.reconnect(resume: true)]
        )
        var fresh = DiscordGatewaySession(cursor: .unset)
        XCTAssertEqual(
            fresh.handle(DiscordGatewayFrame(op: 7, sequence: nil, event: .reconnect)),
            [.reconnect(resume: false)]
        )
    }

    func testIdentifyResumeHeartbeatPayloadsStayCoreOwned() throws {
        let identify = try XCTUnwrap(DiscordGatewayPayload.identify(botToken: "BotToken.example"))
        XCTAssertEqual(identify["op"] as? Int, 2)
        let resume = try XCTUnwrap(
            DiscordGatewayPayload.resume(botToken: "BotToken.example", sessionId: "s", sequence: 3)
        )
        XCTAssertEqual(resume["op"] as? Int, 6)
        let beat = try XCTUnwrap(DiscordGatewayPayload.heartbeat(sequence: 3))
        XCTAssertEqual(beat["op"] as? Int, 1)
        XCTAssertEqual(
            DiscordGatewaySession.payload(
                .sendIdentify,
                botToken: "BotToken.example",
                cursor: .unset
            )?["op"] as? Int,
            2
        )
        XCTAssertEqual(
            DiscordGatewaySession.payload(
                .sendResume,
                botToken: "BotToken.example",
                cursor: DiscordInboundCursor(sessionId: "s", sequence: 3, seeded: true)
            )?["op"] as? Int,
            6
        )
        XCTAssertEqual(
            DiscordGatewaySession.payload(
                .sendHeartbeat,
                botToken: "x",
                cursor: DiscordInboundCursor(sessionId: "s", sequence: 3, seeded: true)
            )?["op"] as? Int,
            1
        )
    }

    private func hello(_ ms: Int) -> DiscordGatewayFrame {
        DiscordGatewayFrame(op: 10, sequence: nil, event: .hello(heartbeatIntervalMs: ms))
    }
}
