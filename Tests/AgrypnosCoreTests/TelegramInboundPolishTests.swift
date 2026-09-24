import XCTest
@testable import AgrypnosCore

final class TelegramInboundHelpParseTests: XCTestCase {
    func testParseAcceptsSlashHelpAndBareArmDisarmStatus() {
        XCTAssertEqual(TelegramInboundCommand.parse("/help"), .help)
        XCTAssertEqual(TelegramInboundCommand.parse("/Help"), .help)
        XCTAssertEqual(TelegramInboundCommand.parse("/help@MyBot"), .help)
        XCTAssertEqual(TelegramInboundCommand.parse("arm"), .arm)
        XCTAssertEqual(TelegramInboundCommand.parse("/arm"), .arm)
        XCTAssertEqual(TelegramInboundCommand.parse("disarm"), .disarm)
        XCTAssertEqual(TelegramInboundCommand.parse("/disarm"), .disarm)
        XCTAssertEqual(TelegramInboundCommand.parse("status"), .status)
        XCTAssertEqual(TelegramInboundCommand.parse("/status"), .status)
        XCTAssertNil(TelegramInboundCommand.parse("/start"))
        XCTAssertNil(TelegramInboundCommand.parse("help now"))
    }

    func testMatchingChatRoutesHelpWithoutArming() {
        XCTAssertEqual(
            TelegramInboundPolicy.intent(
                enabled: true,
                botToken: "123:token",
                savedChatId: "99",
                update: TelegramInboundUpdate(updateId: 1, chatId: "99", text: "/help")
            ),
            .help
        )
        XCTAssertNil(TelegramInboundIntent.help.shouldSetEngaged(currentlyEngaged: false))
        XCTAssertNil(TelegramInboundIntent.help.shouldSetEngaged(currentlyEngaged: true))
        var engine = WatchEngine(preferences: .default)
        let t0 = Date(timeIntervalSince1970: 10_000)
        XCTAssertTrue(engine.applyTelegramInbound(.help, now: t0).isEmpty)
        XCTAssertFalse(engine.engaged)
    }
}

final class TelegramInboundHelpCopyTests: XCTestCase {
    func testHelpReplyExplainsCommandsAsleepNoteAndLidGatedDisarm() {
        let help = TelegramInboundCopy.help
        XCTAssertEqual(TelegramInboundCopy.reply(intent: .help, engaged: false, duration: .indefinite), help)
        let lower = help.lowercased()
        XCTAssertTrue(help.contains("/arm"))
        XCTAssertTrue(help.contains("/disarm"))
        XCTAssertTrue(help.contains("/status"))
        XCTAssertTrue(help.contains("/help"))
        XCTAssertTrue(lower.contains("keep the watch"))
        XCTAssertTrue(lower.contains("asleep"))
        XCTAssertTrue(lower.contains("polling") || lower.contains("not polling"))
        XCTAssertTrue(lower.contains("lid"))
        XCTAssertTrue(lower.contains("open"))
        XCTAssertTrue(lower.contains("closed") || lower.contains("close"))
        XCTAssertTrue(lower.contains("sleep"))
        XCTAssertFalse(lower.contains("agent stopped"))
        XCTAssertFalse(lower.contains("job finished"))
        XCTAssertFalse(lower.contains("still thinking"))
        XCTAssertFalse(lower.contains("eta"))
        XCTAssertFalse(lower.contains("always sleep"))
        XCTAssertTrue(lower.contains("watch facts") || lower.contains("keep the watch, how long"))
    }

    func testMissedWhileAsleepCopyIsFactsOnly() {
        XCTAssertEqual(TelegramInboundCopy.missedWhileAsleep, "Missed while asleep.")
        let lower = TelegramInboundCopy.missedWhileAsleep.lowercased()
        XCTAssertTrue(lower.contains("missed"))
        XCTAssertTrue(lower.contains("asleep"))
        XCTAssertFalse(lower.contains("agent stopped"))
        XCTAssertFalse(lower.contains("job finished"))
        XCTAssertFalse(lower.contains("still thinking"))
        XCTAssertFalse(lower.contains("answered"))
        XCTAssertFalse(lower.contains("eta"))
    }
}

final class TelegramInboundWakeMissTests: XCTestCase {
    func testLeftoverDrainDoesNotApplyOrReply() {
        let cursor = TelegramInboundCursor(offset: 40, seeded: true).startingSession()
        XCTAssertEqual(cursor.drain, .leftover)
        XCTAssertFalse(cursor.shouldApplyCommands)
        XCTAssertEqual(
            TelegramInboundDispatch.effect(drain: cursor.drain, intent: .arm),
            .ignore
        )
        XCTAssertEqual(
            TelegramInboundDispatch.effect(drain: .leftover, intent: .disarm),
            .ignore
        )
        XCTAssertEqual(
            TelegramInboundDispatch.effect(drain: .leftover, intent: .help),
            .ignore
        )
    }

    func testWakeMissDrainDoesNotArmOrDisarmAndRepliesMissed() {
        let live = TelegramInboundCursor(offset: 40, seeded: true)
        let cursor = live.startingWakeMiss()
        XCTAssertEqual(cursor.offset, 40)
        XCTAssertFalse(cursor.shouldApplyCommands)
        XCTAssertEqual(cursor.drain, .wakeMiss)
        XCTAssertEqual(cursor.pollTimeout, 0)

        XCTAssertEqual(
            TelegramInboundDispatch.effect(drain: .wakeMiss, intent: .arm),
            .missedWhileAsleep
        )
        XCTAssertEqual(
            TelegramInboundDispatch.effect(drain: .wakeMiss, intent: .disarm),
            .missedWhileAsleep
        )
        XCTAssertEqual(
            TelegramInboundDispatch.effect(drain: .wakeMiss, intent: .status),
            .missedWhileAsleep
        )
        XCTAssertEqual(
            TelegramInboundDispatch.effect(drain: .wakeMiss, intent: .help),
            .missedWhileAsleep
        )
        XCTAssertEqual(
            TelegramInboundDispatch.effect(drain: .wakeMiss, intent: .ignore),
            .ignore
        )

        var engine = WatchEngine(preferences: .default)
        let t0 = Date(timeIntervalSince1970: 10_000)
        XCTAssertEqual(TelegramInboundDispatch.effect(drain: cursor.drain, intent: .arm), .missedWhileAsleep)
        XCTAssertFalse(engine.engaged)
        _ = engine.userSetEngaged(true, now: t0)
        XCTAssertEqual(TelegramInboundDispatch.effect(drain: .wakeMiss, intent: .disarm), .missedWhileAsleep)
        XCTAssertTrue(engine.engaged)
    }

    func testStillSeededPollAfterSleepUsesStoredWakeMissNotFetchedLive() {
        let fetchedLive = TelegramInboundCursor(offset: 41, seeded: true)
        let storedWakeMiss = TelegramInboundCursor(offset: 40, seeded: true).startingWakeMiss()
        XCTAssertEqual(fetchedLive.drain, .live)
        XCTAssertEqual(storedWakeMiss.drain, .wakeMiss)
        XCTAssertEqual(
            TelegramInboundDrain.effective(stored: storedWakeMiss, fetched: fetchedLive),
            .wakeMiss
        )
        XCTAssertEqual(
            TelegramInboundDispatch.effect(
                drain: TelegramInboundDrain.effective(stored: storedWakeMiss, fetched: fetchedLive),
                intent: .arm
            ),
            .missedWhileAsleep
        )
        XCTAssertNotEqual(
            TelegramInboundDispatch.effect(drain: fetchedLive.drain, intent: .arm),
            .missedWhileAsleep
        )
    }

    func testWakeMissAckSeedsLiveAndClearsMiss() {
        let drained = TelegramInboundCursor(offset: 40, seeded: false, wakeMiss: true).acknowledging([
            TelegramInboundUpdate(updateId: 41, chatId: "99", text: "/arm"),
        ])
        XCTAssertTrue(drained.seeded)
        XCTAssertEqual(drained.drain, .live)
        XCTAssertTrue(drained.shouldApplyCommands)
        XCTAssertEqual(
            TelegramInboundDispatch.effect(drain: drained.drain, intent: .arm),
            .apply(.arm)
        )
    }

    func testLiveApplyStillRunsCommands() {
        XCTAssertEqual(
            TelegramInboundDispatch.effect(drain: .live, intent: .arm),
            .apply(.arm)
        )
        XCTAssertEqual(
            TelegramInboundDispatch.effect(drain: .live, intent: .help),
            .apply(.help)
        )
        XCTAssertEqual(
            TelegramInboundDispatch.effect(drain: .live, intent: .ignore),
            .ignore
        )
    }
}

final class TelegramInboundDisarmLidTests: XCTestCase {
    let t0 = Date(timeIntervalSince1970: 10_000)

    func testDisarmLidOpenClearsWatchAndDoesNotRequestSleep() {
        var engine = WatchEngine(preferences: .default)
        _ = engine.userSetEngaged(true, now: t0, lidClosed: false)
        XCTAssertTrue(engine.engaged)
        XCTAssertFalse(engine.lidClosed)

        let commands = engine.applyTelegramInbound(
            .disarm,
            now: t0.addingTimeInterval(1),
            lidCloseConfirmed: false
        )
        XCTAssertFalse(engine.engaged)
        XCTAssertEqual(commands, [.disengage(.user)])
        XCTAssertFalse(commands.contains(.requestSleep))
        XCTAssertFalse(TelegramInboundDisarm.shouldRequestSleep(lidCloseConfirmed: false))
    }

    func testDisarmUnconfirmedCloseDoesNotRequestSleep() {
        var engine = WatchEngine(preferences: .default)
        _ = engine.userSetEngaged(true, now: t0, lidClosed: false)
        XCTAssertTrue(engine.observeLid(closed: true, now: t0).isEmpty)
        XCTAssertFalse(engine.lidClosed)

        let commands = engine.applyTelegramInbound(
            .disarm,
            now: t0.addingTimeInterval(0.1),
            lidCloseConfirmed: engine.lidClosed
        )
        XCTAssertFalse(engine.engaged)
        XCTAssertFalse(commands.contains(.requestSleep))
    }

    func testDisarmConfirmedClosedClearsHoldAndRequestsSleep() {
        var engine = WatchEngine(preferences: .default)
        _ = engine.userSetEngaged(true, now: t0, lidClosed: false)
        XCTAssertTrue(engine.observeLid(closed: true, now: t0).isEmpty)
        XCTAssertEqual(
            engine.observeLid(closed: true, now: t0.addingTimeInterval(LidCloseConfirm.pulseInterval)),
            [.assertSleepDisabled, .applyBrightnessFloor, .requestKeyboardBacklightOff]
        )
        XCTAssertTrue(engine.lidClosed)

        let commands = engine.applyTelegramInbound(
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
        XCTAssertFalse(engine.engaged)
        let commands = engine.applyTelegramInbound(
            .disarm,
            now: t0,
            lidCloseConfirmed: true
        )
        XCTAssertFalse(engine.engaged)
        XCTAssertEqual(commands, [.requestSleep])
        XCTAssertFalse(commands.contains(.disengage(.user)))
    }

    func testPopoverStyleUserDisarmStillDoesNotSleep() {
        var engine = WatchEngine(preferences: .default)
        _ = engine.userSetEngaged(true, now: t0, lidClosed: true)
        XCTAssertEqual(
            engine.userSetEngaged(false, now: t0.addingTimeInterval(1), lidClosed: true),
            [.disengage(.user)]
        )
    }

    func testAfterDisengageLidOpenDoesNotLeaveSleepGateTrue() {
        var engine = WatchEngine(preferences: .default)
        _ = engine.userSetEngaged(true, now: t0, lidClosed: false)
        XCTAssertTrue(engine.observeLid(closed: true, now: t0).isEmpty)
        _ = engine.observeLid(closed: true, now: t0.addingTimeInterval(LidCloseConfirm.pulseInterval))
        XCTAssertTrue(engine.lidClosed)
        XCTAssertTrue(engine.lidCloseConfirmed)

        _ = engine.userSetEngaged(false, now: t0.addingTimeInterval(1), lidClosed: engine.lidClosed)
        XCTAssertFalse(engine.engaged)
        XCTAssertFalse(engine.lidCloseConfirmed)

        XCTAssertTrue(engine.observeLid(closed: false, now: t0.addingTimeInterval(2)).isEmpty)
        XCTAssertFalse(engine.lidClosed)
        XCTAssertFalse(engine.lidCloseConfirmed)
        XCTAssertFalse(TelegramInboundDisarm.shouldRequestSleep(lidCloseConfirmed: engine.lidCloseConfirmed))
        XCTAssertFalse(
            engine.applyTelegramInbound(
                .disarm,
                now: t0.addingTimeInterval(3),
                lidCloseConfirmed: engine.lidCloseConfirmed
            ).contains(.requestSleep)
        )
    }
}

final class TelegramSetMyCommandsFactoryTests: XCTestCase {
    func testSetMyCommandsRegistersSlashMenuForUserBot() throws {
        let request = try XCTUnwrap(
            NotifOutboundRequestFactory.telegramSetMyCommands(botToken: "123:token")
        )
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.url.scheme, "https")
        XCTAssertEqual(request.url.host, "api.telegram.org")
        XCTAssertTrue(request.url.path.hasPrefix("/bot"))
        XCTAssertTrue(request.url.path.hasSuffix("/setMyCommands"))
        XCTAssertEqual(request.headers["Content-Type"], "application/json")

        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: request.body) as? [String: Any])
        let commands = try XCTUnwrap(object["commands"] as? [[String: Any]])
        let names = commands.compactMap { $0["command"] as? String }
        XCTAssertEqual(names, ["arm", "disarm", "status", "help"])
        XCTAssertEqual(TelegramBotCommandMenu.commands.map(\.command), names)
        for command in TelegramBotCommandMenu.commands {
            XCTAssertFalse(command.command.hasPrefix("/"))
            XCTAssertFalse(command.description.isEmpty)
            XCTAssertLessThanOrEqual(command.description.count, 256)
            let lower = command.description.lowercased()
            XCTAssertFalse(lower.contains("agent stopped"))
            XCTAssertFalse(lower.contains("job finished"))
            XCTAssertFalse(lower.contains("still thinking"))
            XCTAssertFalse(lower.contains("eta"))
            XCTAssertFalse(lower.contains("always sleep"))
        }
        XCTAssertNil(NotifOutboundRequestFactory.telegramSetMyCommands(botToken: ""))
        XCTAssertNil(NotifOutboundRequestFactory.telegramSetMyCommands(botToken: "  "))
    }
}
