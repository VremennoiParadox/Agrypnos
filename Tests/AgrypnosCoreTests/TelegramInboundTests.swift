import XCTest
@testable import AgrypnosCore

final class TelegramInboundPreferenceTests: XCTestCase {
    func testInboundDefaultsOffSeparateFromOutbound() {
        XCTAssertFalse(UserPreferences.default.telegramInboundEnabled)
        XCTAssertFalse(UserPreferences().telegramInboundEnabled)
        XCTAssertFalse(TelegramInboundChrome.defaultEnabled)
        XCTAssertEqual(
            TelegramInboundChrome.defaultEnabled,
            UserPreferences.default.telegramInboundEnabled
        )
        XCTAssertFalse(UserPreferences.default.notifEnabled)

        var prefs = UserPreferences.default
        prefs.notifEnabled = true
        XCTAssertFalse(prefs.telegramInboundEnabled)
        prefs.telegramInboundEnabled = true
        XCTAssertTrue(prefs.notifEnabled)
        XCTAssertTrue(prefs.telegramInboundEnabled)
    }

    func testMissingInboundKeyDecodesFalseAndRoundTrips() throws {
        let json = """
        {"batteryFloorPercent":15,"duration":"indefinite","keyboardBacklightOff":true,"applyBrightnessFloor":true,"brightnessFloorPercent":15,"agentSettleGrace":120,"sessionFreshness":45,"lidOpenRampSeconds":2,"hotkey":{"keyCode":0,"option":true,"command":true,"shift":false,"control":false},"thermalAutoOff":true,"notifEnabled":true}
        """
        let decoded = try JSONDecoder().decode(UserPreferences.self, from: Data(json.utf8))
        XCTAssertTrue(decoded.notifEnabled)
        XCTAssertFalse(decoded.telegramInboundEnabled)

        var on = UserPreferences.default
        on.telegramInboundEnabled = true
        let encoded = try JSONEncoder().encode(on)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        XCTAssertEqual(object["telegramInboundEnabled"] as? Bool, true)
        XCTAssertEqual(object["notifEnabled"] as? Bool, false)
        let roundTripped = try JSONDecoder().decode(UserPreferences.self, from: encoded)
        XCTAssertTrue(roundTripped.telegramInboundEnabled)

        var engine = WatchEngine(preferences: .default)
        engine.userSetTelegramInboundEnabled(true)
        XCTAssertTrue(engine.preferences.telegramInboundEnabled)
        engine.userSetTelegramInboundEnabled(false)
        XCTAssertFalse(engine.preferences.telegramInboundEnabled)
    }
}

final class TelegramInboundPolicyTests: XCTestCase {
    let saved = "99"
    let token = "123:token"

    func testEmptySecretsOrInboundOffMeansNoPoll() {
        XCTAssertFalse(
            TelegramInboundPolicy.shouldPoll(enabled: false, botToken: token, chatId: saved)
        )
        XCTAssertFalse(
            TelegramInboundPolicy.shouldPoll(enabled: true, botToken: nil, chatId: saved)
        )
        XCTAssertFalse(
            TelegramInboundPolicy.shouldPoll(enabled: true, botToken: token, chatId: nil)
        )
        XCTAssertFalse(
            TelegramInboundPolicy.shouldPoll(enabled: true, botToken: "  ", chatId: saved)
        )
        XCTAssertFalse(
            TelegramInboundPolicy.shouldPoll(enabled: true, botToken: token, chatId: "  ")
        )
        XCTAssertFalse(
            TelegramInboundPolicy.shouldPoll(enabled: true, botToken: "", chatId: "")
        )
        XCTAssertTrue(
            TelegramInboundPolicy.shouldPoll(enabled: true, botToken: token, chatId: saved)
        )
        XCTAssertTrue(
            TelegramInboundPolicy.shouldPoll(enabled: true, botToken: " 123:token ", chatId: " 99 ")
        )
    }

    func testInboundOffIgnoresMatchingArm() {
        XCTAssertEqual(
            TelegramInboundPolicy.intent(
                enabled: false,
                botToken: token,
                savedChatId: saved,
                update: .command(chatId: saved, text: "arm")
            ),
            .ignore
        )
    }

    func testWrongChatIdIsIgnored() {
        XCTAssertEqual(
            TelegramInboundPolicy.intent(
                enabled: true,
                botToken: token,
                savedChatId: saved,
                update: .command(chatId: "100", text: "arm")
            ),
            .ignore
        )
        XCTAssertEqual(
            TelegramInboundPolicy.intent(
                enabled: true,
                botToken: token,
                savedChatId: saved,
                update: .command(chatId: "-99", text: "disarm")
            ),
            .ignore
        )
    }

    func testEmptyTokenOrChatIdIgnoresEvenWhenEnabled() {
        XCTAssertEqual(
            TelegramInboundPolicy.intent(
                enabled: true,
                botToken: nil,
                savedChatId: saved,
                update: .command(chatId: saved, text: "arm")
            ),
            .ignore
        )
        XCTAssertEqual(
            TelegramInboundPolicy.intent(
                enabled: true,
                botToken: token,
                savedChatId: nil,
                update: .command(chatId: saved, text: "status")
            ),
            .ignore
        )
    }

    func testMatchingChatRoutesArmDisarmStatus() {
        XCTAssertEqual(intent("arm"), .arm)
        XCTAssertEqual(intent("/arm"), .arm)
        XCTAssertEqual(intent("/arm@AgrypnosBot"), .arm)
        XCTAssertEqual(intent(" ARM "), .arm)
        XCTAssertEqual(intent("disarm"), .disarm)
        XCTAssertEqual(intent("/disarm"), .disarm)
        XCTAssertEqual(intent("status"), .status)
        XCTAssertEqual(intent("/status"), .status)
        XCTAssertEqual(intent("nope"), .ignore)
        XCTAssertEqual(intent("please arm"), .ignore)
        XCTAssertEqual(intent(""), .ignore)
        XCTAssertEqual(
            TelegramInboundPolicy.intent(
                enabled: true,
                botToken: token,
                savedChatId: saved,
                update: TelegramInboundUpdate(updateId: 1, chatId: saved, text: nil)
            ),
            .ignore
        )
    }

    func testChatIdMatchAcceptsNumericEquivalence() {
        XCTAssertEqual(
            TelegramInboundPolicy.intent(
                enabled: true,
                botToken: token,
                savedChatId: "99",
                update: .command(chatId: "099", text: "status")
            ),
            .status
        )
        XCTAssertEqual(
            TelegramInboundPolicy.intent(
                enabled: true,
                botToken: token,
                savedChatId: "-100123",
                update: .command(chatId: "-100123", text: "arm")
            ),
            .arm
        )
    }

    private func intent(_ text: String) -> TelegramInboundIntent {
        TelegramInboundPolicy.intent(
            enabled: true,
            botToken: token,
            savedChatId: saved,
            update: .command(chatId: saved, text: text)
        )
    }
}

final class TelegramInboundCommandParseTests: XCTestCase {
    func testParseStripsSlashAndBotSuffix() {
        XCTAssertEqual(TelegramInboundCommand.parse("arm"), .arm)
        XCTAssertEqual(TelegramInboundCommand.parse("/Arm"), .arm)
        XCTAssertEqual(TelegramInboundCommand.parse("/arm@MyBot"), .arm)
        XCTAssertEqual(TelegramInboundCommand.parse("disarm"), .disarm)
        XCTAssertEqual(TelegramInboundCommand.parse("/disarm"), .disarm)
        XCTAssertEqual(TelegramInboundCommand.parse("status"), .status)
        XCTAssertEqual(TelegramInboundCommand.parse("/status@bot"), .status)
        XCTAssertNil(TelegramInboundCommand.parse("arm now"))
        XCTAssertNil(TelegramInboundCommand.parse("start"))
        XCTAssertNil(TelegramInboundCommand.parse("/start"))
        XCTAssertNil(TelegramInboundCommand.parse(""))
        XCTAssertNil(TelegramInboundCommand.parse("   "))
    }
}

final class TelegramInboundWatchEngineTests: XCTestCase {
    let t0 = Date(timeIntervalSince1970: 10_000)

    func testArmAndDisarmCallWatchEngineAndStayIdempotent() {
        var engine = WatchEngine(preferences: .default)
        XCTAssertFalse(engine.engaged)

        let arm = engine.applyTelegramInbound(.arm, now: t0)
        XCTAssertTrue(engine.engaged)
        XCTAssertTrue(arm.contains(.engage))
        XCTAssertFalse(arm.contains(.applyBrightnessFloor))
        XCTAssertFalse(arm.contains(.requestKeyboardBacklightOff))
        XCTAssertEqual(engine.preferences.duration, .indefinite)

        let again = engine.applyTelegramInbound(.arm, now: t0.addingTimeInterval(1))
        XCTAssertTrue(engine.engaged)
        XCTAssertTrue(again.isEmpty)
        XCTAssertTrue(engine.postedThisUserArm == false)

        let disarm = engine.applyTelegramInbound(.disarm, now: t0.addingTimeInterval(2))
        XCTAssertFalse(engine.engaged)
        XCTAssertEqual(disarm, [.disengage(.user)])
        XCTAssertEqual(engine.preferences.duration, .indefinite)

        let idle = engine.applyTelegramInbound(.disarm, now: t0.addingTimeInterval(3))
        XCTAssertFalse(engine.engaged)
        XCTAssertTrue(idle.isEmpty)
    }

    func testTelegramArmDoesNotFloorOnOneClosedLidSample() {
        var engine = WatchEngine(preferences: .default)
        let arm = engine.applyTelegramInbound(.arm, now: t0)
        XCTAssertTrue(engine.engaged)
        XCTAssertFalse(arm.contains(.applyBrightnessFloor))
        XCTAssertFalse(arm.contains(.requestKeyboardBacklightOff))
        XCTAssertTrue(engine.observeLid(closed: true, now: t0).isEmpty)
        XCTAssertFalse(engine.lidClosed)
        XCTAssertFalse(engine.lidHygieneApplied)
    }

    func testStatusDoesNotMutateTheWatch() {
        var engine = WatchEngine(preferences: .default)
        _ = engine.userSetEngaged(true, now: t0)
        let commands = engine.applyTelegramInbound(.status, now: t0.addingTimeInterval(1))
        XCTAssertTrue(commands.isEmpty)
        XCTAssertTrue(engine.engaged)
        XCTAssertEqual(engine.preferences.duration, .indefinite)
    }

    func testIgnoreDoesNotMutateTheWatch() {
        var engine = WatchEngine(preferences: .default)
        XCTAssertTrue(engine.applyTelegramInbound(.ignore, now: t0).isEmpty)
        XCTAssertFalse(engine.engaged)
    }

    func testOffsetAdvancesForIgnoredUpdates() {
        let updates = [
            TelegramInboundUpdate(updateId: 10, chatId: "1", text: "arm"),
            TelegramInboundUpdate(updateId: 12, chatId: "1", text: "nope"),
        ]
        XCTAssertEqual(TelegramInboundOffset.next(current: 1, updates: updates), 13)
        XCTAssertEqual(TelegramInboundOffset.next(current: 40, updates: updates), 40)
        XCTAssertEqual(TelegramInboundOffset.next(current: 7, updates: []), 7)
    }

    func testUnseededCursorAcksBacklogWithoutApplyingCommands() {
        let updates = [TelegramInboundUpdate(updateId: 10, chatId: "99", text: "arm")]
        XCTAssertFalse(TelegramInboundCursor.unset.shouldApplyCommands)
        let next = TelegramInboundCursor.unset.acknowledging(updates)
        XCTAssertTrue(next.seeded)
        XCTAssertEqual(next.offset, 11)
        XCTAssertTrue(next.shouldApplyCommands)
    }

    func testEmptyAcceptedPollSeedsSoLaterUpdatesAreNew() {
        let next = TelegramInboundCursor.unset.acknowledging([])
        XCTAssertTrue(next.seeded)
        XCTAssertEqual(next.offset, 0)
        XCTAssertTrue(next.shouldApplyCommands)
    }

    func testNewPollSessionKeepsOffsetAndSkipsQueuedCommands() {
        let saved = TelegramInboundCursor(offset: 40, seeded: true)
        let session = saved.startingSession()
        XCTAssertEqual(session.offset, 40)
        XCTAssertFalse(session.shouldApplyCommands)
        let drained = session.acknowledging([
            TelegramInboundUpdate(updateId: 41, chatId: "99", text: "arm"),
        ])
        XCTAssertTrue(drained.seeded)
        XCTAssertEqual(drained.offset, 42)
        XCTAssertTrue(drained.shouldApplyCommands)
    }

    func testUnseededPollIsImmediateSoLiveCommandsAreNotSwallowed() {
        XCTAssertEqual(TelegramInboundCursor.unset.pollTimeout, 0)
        XCTAssertEqual(TelegramInboundCursor(offset: 40, seeded: true).startingSession().pollTimeout, 0)
        XCTAssertEqual(TelegramInboundCursor(offset: 40, seeded: true).pollTimeout, 25)
        XCTAssertEqual(TelegramInboundPoll.drainSeconds, 0)
        XCTAssertEqual(TelegramInboundPoll.longPollSeconds, 25)
    }

    func testStaleGenerationAndTokenChangeDoNotApply() {
        XCTAssertTrue(TelegramInboundGeneration.allowsApply(current: 3, captured: 3))
        XCTAssertFalse(TelegramInboundGeneration.allowsApply(current: 4, captured: 3))
        XCTAssertTrue(
            TelegramInboundPolicy.sameBot(fetchedToken: "123:token", currentToken: "123:token")
        )
        XCTAssertFalse(
            TelegramInboundPolicy.sameBot(fetchedToken: "123:old", currentToken: "123:new")
        )
        XCTAssertFalse(
            TelegramInboundPolicy.sameBot(fetchedToken: "123:token", currentToken: nil)
        )
    }

    func testShouldSetEngagedIsTheSharedArmDisarmDecision() {
        XCTAssertEqual(TelegramInboundIntent.arm.shouldSetEngaged(currentlyEngaged: false), true)
        XCTAssertNil(TelegramInboundIntent.arm.shouldSetEngaged(currentlyEngaged: true))
        XCTAssertEqual(TelegramInboundIntent.disarm.shouldSetEngaged(currentlyEngaged: true), false)
        XCTAssertNil(TelegramInboundIntent.disarm.shouldSetEngaged(currentlyEngaged: false))
        XCTAssertNil(TelegramInboundIntent.status.shouldSetEngaged(currentlyEngaged: true))
        XCTAssertNil(TelegramInboundIntent.ignore.shouldSetEngaged(currentlyEngaged: false))
    }
}

final class TelegramInboundCopyTests: XCTestCase {
    func testRepliesArePlainFacts() {
        XCTAssertEqual(TelegramInboundCopy.armed, "Armed.")
        XCTAssertEqual(TelegramInboundCopy.disarmed, "Disarmed.")
        XCTAssertEqual(TelegramInboundCopy.keepOn, "Keep the watch is on.")
        XCTAssertEqual(TelegramInboundCopy.keepOff, "Keep the watch is off.")
        XCTAssertEqual(
            TelegramInboundCopy.reply(intent: .arm, engaged: true, duration: .indefinite),
            "Armed."
        )
        XCTAssertEqual(
            TelegramInboundCopy.reply(intent: .disarm, engaged: false, duration: .indefinite),
            "Disarmed."
        )
        XCTAssertEqual(
            TelegramInboundCopy.reply(intent: .status, engaged: true, duration: .indefinite),
            "Keep the watch is on. How long is ∞."
        )
        XCTAssertEqual(
            TelegramInboundCopy.reply(intent: .status, engaged: true, duration: .untilAgentsSettle),
            "Keep the watch is on. How long is Agents."
        )
        XCTAssertEqual(
            TelegramInboundCopy.reply(intent: .status, engaged: true, duration: .oneHour),
            "Keep the watch is on. How long is 1h."
        )
        XCTAssertEqual(
            TelegramInboundCopy.reply(intent: .status, engaged: true, duration: .customMinutes(33)),
            "Keep the watch is on. How long is 33m."
        )
        XCTAssertEqual(
            TelegramInboundCopy.reply(intent: .status, engaged: false, duration: .untilAgentsSettle),
            "Keep the watch is off."
        )
        XCTAssertNil(TelegramInboundCopy.reply(intent: .ignore, engaged: false, duration: .indefinite))
        XCTAssertEqual(
            TelegramInboundCopy.commandsHelp,
            "Commands on your Telegram bot: arm, disarm, status."
        )
        XCTAssertFalse(TelegramInboundCopy.status(engaged: true, duration: .oneHour).contains("left"))
        XCTAssertFalse(TelegramInboundCopy.status(engaged: true, duration: .oneHour).contains("remaining"))
    }

    func testInboundCopyBansJobFinishedAndStillThinking() {
        let blob = [
            TelegramInboundCopy.armed,
            TelegramInboundCopy.disarmed,
            TelegramInboundCopy.keepOn,
            TelegramInboundCopy.keepOff,
            TelegramInboundCopy.armFailed,
            TelegramInboundCopy.disarmFailed,
            TelegramInboundCopy.commandsHelp,
            TelegramInboundCopy.status(engaged: true, duration: .indefinite),
            TelegramInboundCopy.status(engaged: true, duration: .untilAgentsSettle),
            TelegramInboundCopy.status(engaged: true, duration: .oneHour),
            TelegramInboundCopy.status(engaged: true, duration: .threeHours),
            TelegramInboundCopy.status(engaged: true, duration: .customMinutes(33)),
            TelegramInboundCopy.status(engaged: false, duration: .untilAgentsSettle),
        ].joined(separator: "\n").lowercased()
        for banned in [
            "agent stopped",
            "job finished",
            "still thinking",
            "agent finished",
            "we notify your phone",
            "eta",
        ] {
            XCTAssertFalse(blob.contains(banned), "banned phrase in inbound copy: \(banned)")
        }
    }
}

final class TelegramInboundGetUpdatesParserTests: XCTestCase {
    func testParsesMessageChatAndText() throws {
        let data = try JSONSerialization.data(withJSONObject: [
            "ok": true,
            "result": [
                [
                    "update_id": 50,
                    "message": [
                        "chat": ["id": 99],
                        "text": "/arm",
                    ],
                ],
                [
                    "update_id": 51,
                    "message": [
                        "chat": ["id": -1001],
                        "text": "status",
                    ],
                ],
                [
                    "update_id": 52,
                    "message": [
                        "chat": ["id": 99],
                    ],
                ],
            ],
        ])
        let updates = TelegramGetUpdatesParser.parse(data)
        XCTAssertEqual(updates.count, 3)
        XCTAssertEqual(updates[0].updateId, 50)
        XCTAssertEqual(updates[0].chatId, "99")
        XCTAssertEqual(updates[0].text, "/arm")
        XCTAssertEqual(updates[1].chatId, "-1001")
        XCTAssertEqual(updates[1].text, "status")
        XCTAssertEqual(updates[2].updateId, 52)
        XCTAssertNil(updates[2].text)
    }

    func testRejectsFailedAndMalformedPayloads() {
        XCTAssertEqual(
            TelegramGetUpdatesParser.parse(Data("{\"ok\":false}".utf8)),
            []
        )
        XCTAssertEqual(TelegramGetUpdatesParser.parse(Data()), [])
        XCTAssertEqual(TelegramGetUpdatesParser.parse(Data("not-json".utf8)), [])
        XCTAssertTrue(
            TelegramGetUpdatesParser.accepted(Data("{\"ok\":true,\"result\":[]}".utf8))
        )
        XCTAssertFalse(TelegramGetUpdatesParser.accepted(Data("{\"ok\":false}".utf8)))
        XCTAssertFalse(TelegramGetUpdatesParser.accepted(Data()))
        XCTAssertFalse(TelegramGetUpdatesParser.accepted(Data("not-json".utf8)))
    }
}

final class TelegramInboundGetUpdatesRequestTests: XCTestCase {
    func testGetUpdatesUsesTelegramHostAndOffset() throws {
        let request = try XCTUnwrap(
            NotifOutboundRequestFactory.telegramGetUpdates(
                botToken: "123:token",
                offset: 8,
                timeout: 25
            )
        )
        XCTAssertEqual(request.httpMethod, "GET")
        XCTAssertEqual(request.url.scheme, "https")
        XCTAssertEqual(request.url.host, "api.telegram.org")
        XCTAssertTrue(request.url.path.hasPrefix("/bot"))
        XCTAssertTrue(request.url.path.hasSuffix("/getUpdates"))
        let items = URLComponents(url: request.url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        XCTAssertEqual(items.first(where: { $0.name == "offset" })?.value, "8")
        XCTAssertEqual(items.first(where: { $0.name == "timeout" })?.value, "25")
        let drain = try XCTUnwrap(
            NotifOutboundRequestFactory.telegramGetUpdates(
                botToken: "123:token",
                offset: 8,
                timeout: 0
            )
        )
        let drainItems = URLComponents(url: drain.url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        XCTAssertEqual(drainItems.first(where: { $0.name == "timeout" })?.value, "0")
        XCTAssertNil(
            NotifOutboundRequestFactory.telegramGetUpdates(botToken: "", offset: 1, timeout: 0)
        )
        XCTAssertNil(
            NotifOutboundRequestFactory.telegramGetUpdates(botToken: "  ", offset: 1, timeout: 0)
        )
    }
}

private extension TelegramInboundUpdate {
    static func command(chatId: String, text: String) -> TelegramInboundUpdate {
        TelegramInboundUpdate(updateId: 1, chatId: chatId, text: text)
    }
}
