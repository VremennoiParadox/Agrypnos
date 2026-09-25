import XCTest
@testable import AgrypnosCore

final class DiscordInboundHelpCopyTests: XCTestCase {
    func testHelpReplyExplainsCommandsAsleepNoteLidGatedDisarmAndLiveBattery() {
        let help = DiscordInboundCopy.help
        XCTAssertEqual(
            DiscordInboundCopy.reply(intent: .help, engaged: false, duration: .indefinite),
            help
        )
        let lower = help.lowercased()
        XCTAssertTrue(help.contains("/arm"))
        XCTAssertTrue(help.contains("/disarm"))
        XCTAssertTrue(help.contains("/status"))
        XCTAssertTrue(help.contains("/help"))
        XCTAssertTrue(lower.contains("keep the watch"))
        XCTAssertTrue(lower.contains("asleep"))
        XCTAssertTrue(lower.contains("receiving updates"))
        XCTAssertFalse(lower.contains("polling"))
        XCTAssertTrue(lower.contains("lid"))
        XCTAssertTrue(lower.contains("open"))
        XCTAssertTrue(lower.contains("closed") || lower.contains("close"))
        XCTAssertTrue(lower.contains("sleep"))
        XCTAssertTrue(lower.contains("watch facts") || lower.contains("keep the watch, how long"))
        XCTAssertTrue(lower.contains("live battery"))
        XCTAssertTrue(lower.contains("when known"))
        XCTAssertFalse(lower.contains("agent stopped"))
        XCTAssertFalse(lower.contains("job finished"))
        XCTAssertFalse(lower.contains("still thinking"))
        XCTAssertFalse(lower.contains("eta"))
        XCTAssertFalse(lower.contains("always sleep"))
    }

    func testArmDisarmMissedAndStatusReuseTelegramFacts() {
        XCTAssertEqual(DiscordInboundCopy.armed, TelegramInboundCopy.armed)
        XCTAssertEqual(DiscordInboundCopy.disarmed, TelegramInboundCopy.disarmed)
        XCTAssertEqual(DiscordInboundCopy.missedWhileAsleep, TelegramInboundCopy.missedWhileAsleep)
        XCTAssertEqual(DiscordInboundCopy.armed, "Armed.")
        XCTAssertEqual(DiscordInboundCopy.disarmed, "Disarmed.")
        XCTAssertEqual(DiscordInboundCopy.missedWhileAsleep, "Missed while asleep.")
        XCTAssertEqual(
            DiscordInboundCopy.reply(intent: .arm, engaged: true, duration: .indefinite),
            "Armed."
        )
        XCTAssertEqual(
            DiscordInboundCopy.reply(intent: .disarm, engaged: false, duration: .indefinite),
            "Disarmed."
        )
        XCTAssertNil(DiscordInboundCopy.reply(intent: .ignore, engaged: false, duration: .indefinite))

        let snapshot = TelegramWatchStatus(
            engaged: true,
            duration: .indefinite,
            lidCloseConfirmed: false,
            includedAgentKinds: AgentIncludeChrome.defaultIncluded,
            sawBusyThisArm: nil,
            settlingAfterBusy: nil,
            lastWatchEnd: nil,
            batteryFloorPercent: 15,
            thermalAutoOff: true,
            lowPowerMode: nil,
            userForcedThisSession: true,
            liveBatteryPercent: 62,
            liveBatteryDischarging: true
        )
        let status = DiscordInboundCopy.reply(
            intent: .status,
            status: snapshot,
            now: Date(timeIntervalSince1970: 0)
        )
        XCTAssertEqual(
            status,
            TelegramInboundCopy.reply(
                intent: .status,
                status: snapshot,
                now: Date(timeIntervalSince1970: 0)
            )
        )
        XCTAssertTrue(try XCTUnwrap(status).contains("Battery 62% · discharging"))
        XCTAssertFalse(try XCTUnwrap(status).lowercased().contains("remaining"))
        XCTAssertFalse(try XCTUnwrap(status).lowercased().contains("eta"))
    }

    func testInboundCopyBansJobFinishedAndStillThinking() {
        let blob = [
            DiscordInboundCopy.armed,
            DiscordInboundCopy.disarmed,
            DiscordInboundCopy.missedWhileAsleep,
            DiscordInboundCopy.help,
            DiscordInboundCopy.commandsHelp,
        ].joined(separator: "\n").lowercased()
        for banned in [
            "agent stopped",
            "job finished",
            "still thinking",
            "agent finished",
            "we notify your phone",
            "eta",
        ] {
            XCTAssertFalse(blob.contains(banned), "banned phrase in Discord inbound copy: \(banned)")
        }
        XCTAssertEqual(
            DiscordInboundCopy.commandsHelp,
            "Commands on your Discord bot: /arm, /disarm, /status, /help."
        )
    }
}

final class DiscordInboundWakeMissTests: XCTestCase {
    func testLeftoverDrainDoesNotApplyOrReply() {
        let cursor = DiscordInboundCursor(sessionId: "s", sequence: 40, seeded: true).startingSession()
        XCTAssertEqual(cursor.drain, .leftover)
        XCTAssertFalse(cursor.shouldApplyCommands)
        XCTAssertEqual(
            TelegramInboundDispatch.effect(drain: cursor.drain, intent: .arm),
            .ignore
        )
    }

    func testWakeMissDrainDoesNotArmAndRepliesMissedIfQueued() {
        let live = DiscordInboundCursor(sessionId: "s", sequence: 40, seeded: true)
        let cursor = live.startingWakeMiss()
        XCTAssertEqual(cursor.sessionId, "s")
        XCTAssertEqual(cursor.sequence, 40)
        XCTAssertFalse(cursor.shouldApplyCommands)
        XCTAssertEqual(cursor.drain, .wakeMiss)
        XCTAssertEqual(
            TelegramInboundDispatch.effect(drain: .wakeMiss, intent: .arm),
            .missedWhileAsleep
        )
        XCTAssertEqual(
            TelegramInboundDispatch.effect(drain: .wakeMiss, intent: .disarm),
            .missedWhileAsleep
        )
        XCTAssertEqual(
            TelegramInboundDispatch.effect(drain: .wakeMiss, intent: .ignore),
            .ignore
        )

        var engine = WatchEngine(preferences: .default)
        XCTAssertFalse(engine.engaged)
        XCTAssertEqual(
            TelegramInboundDispatch.effect(drain: cursor.drain, intent: .arm),
            .missedWhileAsleep
        )
        XCTAssertFalse(engine.engaged)
    }

    func testStillSeededResumeAfterSleepUsesStoredWakeMiss() {
        let fetchedLive = DiscordInboundCursor(sessionId: "s", sequence: 41, seeded: true)
        let storedWakeMiss = DiscordInboundCursor(sessionId: "s", sequence: 40, seeded: true)
            .startingWakeMiss()
        XCTAssertEqual(fetchedLive.drain, .live)
        XCTAssertEqual(storedWakeMiss.drain, .wakeMiss)
        XCTAssertEqual(
            TelegramInboundDrain.effective(storedDrain: storedWakeMiss.drain, fetchedDrain: fetchedLive.drain),
            .wakeMiss
        )
    }

    func testWakeMissAckSeedsLive() {
        let drained = DiscordInboundCursor(
            sessionId: "s",
            sequence: 40,
            seeded: false,
            wakeMiss: true
        ).acknowledging(sequence: 41, sessionId: "s")
        XCTAssertTrue(drained.seeded)
        XCTAssertEqual(drained.drain, .live)
        XCTAssertEqual(drained.sequence, 41)
        XCTAssertEqual(
            TelegramInboundDispatch.effect(drain: drained.drain, intent: .arm),
            .apply(.arm)
        )
    }

    func testEmptyWakeResumeDoesNotInventMissedCommands() {
        let cursor = DiscordInboundCursor.unset.startingWakeMiss()
        XCTAssertEqual(cursor.drain, .wakeMiss)
        XCTAssertEqual(
            TelegramInboundDispatch.effect(drain: cursor.drain, intent: .ignore),
            .ignore
        )
        XCTAssertFalse(DiscordInboundTransport.scrapeChannelHistoryOnWake)
        XCTAssertNil(DiscordInboundRequestFactory.channelMessages(botToken: "x", channelId: "1"))
    }
}

final class DiscordInboundDisarmLidTests: XCTestCase {
    let t0 = Date(timeIntervalSince1970: 10_000)

    func testDisarmLidOpenClearsWatchAndDoesNotRequestSleep() {
        var engine = WatchEngine(preferences: .default)
        _ = engine.userSetEngaged(true, now: t0, lidClosed: false)
        let commands = engine.applyInbound(
            .disarm,
            now: t0.addingTimeInterval(1),
            lidCloseConfirmed: false
        )
        XCTAssertFalse(engine.engaged)
        XCTAssertEqual(commands, [.disengage(.user)])
        XCTAssertFalse(commands.contains(.requestSleep))
        XCTAssertFalse(TelegramInboundDisarm.shouldRequestSleep(lidCloseConfirmed: false))
    }

    func testDisarmConfirmedClosedClearsHoldAndRequestsSleep() {
        var engine = WatchEngine(preferences: .default)
        _ = engine.userSetEngaged(true, now: t0, lidClosed: false)
        XCTAssertTrue(engine.observeLid(closed: true, now: t0).isEmpty)
        XCTAssertEqual(
            engine.observeLid(closed: true, now: t0.addingTimeInterval(LidCloseConfirm.pulseInterval)),
            [.assertSleepDisabled, .applyBrightnessFloor, .requestKeyboardBacklightOff]
        )
        XCTAssertTrue(engine.lidCloseConfirmed)

        let commands = engine.applyInbound(
            .disarm,
            now: t0.addingTimeInterval(1),
            lidCloseConfirmed: true
        )
        XCTAssertFalse(engine.engaged)
        XCTAssertTrue(commands.contains(.disengage(.user)))
        XCTAssertTrue(commands.contains(.requestSleep))
        XCTAssertTrue(TelegramInboundDisarm.shouldRequestSleep(lidCloseConfirmed: true))
    }

    func testDisarmConfirmedClosedStillSleepsWhenWatchAlreadyOff() {
        var engine = WatchEngine(preferences: .default)
        let commands = engine.applyInbound(.disarm, now: t0, lidCloseConfirmed: true)
        XCTAssertFalse(engine.engaged)
        XCTAssertEqual(commands, [.requestSleep])
    }

    func testUnconfirmedCloseDoesNotSleep() {
        var engine = WatchEngine(preferences: .default)
        _ = engine.userSetEngaged(true, now: t0, lidClosed: false)
        XCTAssertTrue(engine.observeLid(closed: true, now: t0).isEmpty)
        let commands = engine.applyInbound(
            .disarm,
            now: t0.addingTimeInterval(0.1),
            lidCloseConfirmed: engine.lidCloseConfirmed
        )
        XCTAssertFalse(commands.contains(.requestSleep))
    }
}

final class DiscordApplicationCommandFactoryTests: XCTestCase {
    func testBulkOverwriteRegistersSlashMenuOnUserBot() throws {
        let request = try XCTUnwrap(
            DiscordInboundRequestFactory.bulkOverwriteCommands(
                botToken: "BotToken.example",
                applicationId: "99"
            )
        )
        XCTAssertEqual(request.httpMethod, "PUT")
        XCTAssertEqual(request.url.scheme, "https")
        XCTAssertEqual(request.url.host, "discord.com")
        XCTAssertEqual(request.url.path, "/api/v10/applications/99/commands")
        XCTAssertFalse(request.url.path.contains("webhooks"))
        XCTAssertEqual(request.headers["Authorization"], "Bot BotToken.example")
        XCTAssertEqual(request.headers["Content-Type"], "application/json")

        let commands = try XCTUnwrap(JSONSerialization.jsonObject(with: request.body) as? [[String: Any]])
        let names = commands.compactMap { $0["name"] as? String }
        XCTAssertEqual(names, ["arm", "disarm", "status", "help"])
        XCTAssertEqual(DiscordBotCommandMenu.commands.map(\.command), names)
        XCTAssertEqual(DiscordBotCommandMenu.commands.map(\.command), TelegramBotCommandMenu.commands.map(\.command))
        for command in commands {
            XCTAssertEqual(command["type"] as? Int, 1)
            let description = try XCTUnwrap(command["description"] as? String)
            XCTAssertFalse(description.isEmpty)
            XCTAssertLessThanOrEqual(description.count, 100)
            let lower = description.lowercased()
            XCTAssertFalse(lower.contains("agent stopped"))
            XCTAssertFalse(lower.contains("job finished"))
            XCTAssertFalse(lower.contains("still thinking"))
            XCTAssertFalse(lower.contains("eta"))
            XCTAssertFalse(lower.contains("always sleep"))
        }
        XCTAssertNil(
            DiscordInboundRequestFactory.bulkOverwriteCommands(botToken: "", applicationId: "99")
        )
        XCTAssertNil(
            DiscordInboundRequestFactory.bulkOverwriteCommands(botToken: "x", applicationId: "  ")
        )
    }

    func testCurrentApplicationUsesBotAuthorizationNotWebhook() throws {
        let request = try XCTUnwrap(
            DiscordInboundRequestFactory.currentApplication(botToken: "BotToken.example")
        )
        XCTAssertEqual(request.httpMethod, "GET")
        XCTAssertEqual(request.url.host, "discord.com")
        XCTAssertEqual(request.url.path, "/api/v10/applications/@me")
        XCTAssertFalse(request.url.path.contains("webhooks"))
        XCTAssertEqual(request.headers["Authorization"], "Bot BotToken.example")
        XCTAssertEqual(
            DiscordApplicationParser.id(from: Data("{\"id\":\"99\"}".utf8)),
            "99"
        )
        XCTAssertNil(DiscordApplicationParser.id(from: Data()))
        XCTAssertNil(DiscordInboundRequestFactory.currentApplication(botToken: "  "))
    }

    func testChannelMessageAndInteractionCallbackAreHttpsToDiscordAPI() throws {
        let message = try XCTUnwrap(
            DiscordInboundRequestFactory.channelMessage(
                botToken: "BotToken.example",
                channelId: "123",
                content: DiscordInboundCopy.armed
            )
        )
        XCTAssertEqual(message.httpMethod, "POST")
        XCTAssertEqual(message.url.path, "/api/v10/channels/123/messages")
        XCTAssertFalse(message.url.path.contains("webhooks"))
        let messageBody = try XCTUnwrap(JSONSerialization.jsonObject(with: message.body) as? [String: Any])
        XCTAssertEqual(messageBody["content"] as? String, "Armed.")

        let callback = try XCTUnwrap(
            DiscordInboundRequestFactory.interactionCallback(
                interactionId: "11",
                interactionToken: "tok",
                content: DiscordInboundCopy.help
            )
        )
        XCTAssertEqual(callback.httpMethod, "POST")
        XCTAssertEqual(callback.url.path, "/api/v10/interactions/11/tok/callback")
        XCTAssertFalse(callback.url.path.contains("webhooks"))
        let callbackBody = try XCTUnwrap(
            JSONSerialization.jsonObject(with: callback.body) as? [String: Any]
        )
        XCTAssertEqual(callbackBody["type"] as? Int, 4)
        let data = try XCTUnwrap(callbackBody["data"] as? [String: Any])
        XCTAssertEqual(data["content"] as? String, DiscordInboundCopy.help)
        XCTAssertNil(
            DiscordInboundRequestFactory.channelMessage(botToken: "", channelId: "1", content: "x")
        )

        let deferral = try XCTUnwrap(
            DiscordInboundRequestFactory.interactionDefer(
                interactionId: "11",
                interactionToken: "tok"
            )
        )
        XCTAssertEqual(deferral.httpMethod, "POST")
        XCTAssertEqual(deferral.url.path, "/api/v10/interactions/11/tok/callback")
        XCTAssertFalse(deferral.url.path.contains("webhooks"))
        let deferBody = try XCTUnwrap(JSONSerialization.jsonObject(with: deferral.body) as? [String: Any])
        XCTAssertEqual(deferBody["type"] as? Int, 5)

        let edit = try XCTUnwrap(
            DiscordInboundRequestFactory.interactionEditOriginal(
                applicationId: "99",
                interactionToken: "tok",
                content: DiscordInboundCopy.armed
            )
        )
        XCTAssertEqual(edit.httpMethod, "PATCH")
        XCTAssertEqual(edit.url.host, "discord.com")
        XCTAssertEqual(edit.url.path, "/api/v10/webhooks/99/tok/messages/@original")
        XCTAssertNil(edit.headers["Authorization"])
        XCTAssertTrue(edit.url.path.hasSuffix("/messages/@original"))
        XCTAssertNil(
            DiscordInboundRequestFactory.interactionEditOriginal(
                applicationId: "not-snowflake",
                interactionToken: "tok",
                content: "x"
            )
        )
        XCTAssertNil(
            DiscordInboundRequestFactory.api(
                botToken: nil,
                method: "POST",
                path: "/api/v10/webhooks/1/abc",
                body: Data()
            )
        )
    }
}
