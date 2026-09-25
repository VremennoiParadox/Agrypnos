import XCTest
@testable import AgrypnosCore

final class DiscordInboundPreferenceTests: XCTestCase {
    func testInboundDefaultsOffSeparateFromOutboundAndTelegram() {
        XCTAssertFalse(UserPreferences.default.discordInboundEnabled)
        XCTAssertFalse(UserPreferences().discordInboundEnabled)
        XCTAssertFalse(DiscordInboundChrome.defaultEnabled)
        XCTAssertEqual(
            DiscordInboundChrome.defaultEnabled,
            UserPreferences.default.discordInboundEnabled
        )
        XCTAssertFalse(UserPreferences.default.notifEnabled)
        XCTAssertFalse(UserPreferences.default.telegramInboundEnabled)

        var prefs = UserPreferences.default
        prefs.notifEnabled = true
        prefs.telegramInboundEnabled = true
        XCTAssertFalse(prefs.discordInboundEnabled)
        prefs.discordInboundEnabled = true
        XCTAssertTrue(prefs.notifEnabled)
        XCTAssertTrue(prefs.telegramInboundEnabled)
        XCTAssertTrue(prefs.discordInboundEnabled)
    }

    func testMissingInboundKeyDecodesFalseAndRoundTrips() throws {
        let json = """
        {"batteryFloorPercent":15,"duration":"indefinite","keyboardBacklightOff":true,"applyBrightnessFloor":true,"brightnessFloorPercent":15,"agentSettleGrace":120,"sessionFreshness":45,"lidOpenRampSeconds":2,"hotkey":{"keyCode":0,"option":true,"command":true,"shift":false,"control":false},"thermalAutoOff":true,"notifEnabled":true,"telegramInboundEnabled":true}
        """
        let decoded = try JSONDecoder().decode(UserPreferences.self, from: Data(json.utf8))
        XCTAssertTrue(decoded.notifEnabled)
        XCTAssertTrue(decoded.telegramInboundEnabled)
        XCTAssertFalse(decoded.discordInboundEnabled)

        var on = UserPreferences.default
        on.discordInboundEnabled = true
        let encoded = try JSONEncoder().encode(on)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        XCTAssertEqual(object["discordInboundEnabled"] as? Bool, true)
        XCTAssertEqual(object["notifEnabled"] as? Bool, false)
        XCTAssertEqual(object["telegramInboundEnabled"] as? Bool, false)
        let roundTripped = try JSONDecoder().decode(UserPreferences.self, from: encoded)
        XCTAssertTrue(roundTripped.discordInboundEnabled)

        var engine = WatchEngine(preferences: .default)
        engine.userSetDiscordInboundEnabled(true)
        XCTAssertTrue(engine.preferences.discordInboundEnabled)
        XCTAssertFalse(engine.preferences.telegramInboundEnabled)
        XCTAssertFalse(engine.preferences.notifEnabled)
        engine.userSetDiscordInboundEnabled(false)
        XCTAssertFalse(engine.preferences.discordInboundEnabled)
    }
}

final class DiscordInboundSecretsTests: XCTestCase {
    func testPayloadRoundTripsBotTokenAndChannelIdWithoutMixingWebhook() throws {
        let data = try XCTUnwrap(
            NotifSecretsPayload.encode(
                discordWebhookURL: "https://discord.com/api/webhooks/1/abc",
                telegramBotToken: "111:token",
                telegramChatId: "99",
                discordBotToken: "BotToken.example",
                discordChannelId: "123456789012345678"
            )
        )
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(object["discordWebhookURL"] as? String, "https://discord.com/api/webhooks/1/abc")
        XCTAssertEqual(object["discordBotToken"] as? String, "BotToken.example")
        XCTAssertEqual(object["discordChannelId"] as? String, "123456789012345678")
        XCTAssertEqual(object["telegramBotToken"] as? String, "111:token")

        let decoded = try XCTUnwrap(NotifSecretsPayload.decode(data))
        XCTAssertEqual(decoded.discordWebhookURL, "https://discord.com/api/webhooks/1/abc")
        XCTAssertEqual(decoded.discordBotToken, "BotToken.example")
        XCTAssertEqual(decoded.discordChannelId, "123456789012345678")
        XCTAssertNotEqual(decoded.discordBotToken, decoded.discordWebhookURL)
    }

    func testOldFileWithoutDiscordInboundKeysLeavesThemNil() throws {
        let data = try XCTUnwrap(
            NotifSecretsPayload.encode(
                discordWebhookURL: "https://discord.com/api/webhooks/1/abc",
                telegramBotToken: "111:token",
                telegramChatId: "99"
            )
        )
        let decoded = try XCTUnwrap(NotifSecretsPayload.decode(data))
        XCTAssertEqual(decoded.discordWebhookURL, "https://discord.com/api/webhooks/1/abc")
        XCTAssertNil(decoded.discordBotToken)
        XCTAssertNil(decoded.discordChannelId)
    }

    func testEmptyDiscordInboundSecretsAreOmitted() throws {
        let data = try XCTUnwrap(
            NotifSecretsPayload.encode(
                discordWebhookURL: nil,
                telegramBotToken: nil,
                telegramChatId: nil,
                discordBotToken: "  ",
                discordChannelId: ""
            )
        )
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertNil(object["discordBotToken"])
        XCTAssertNil(object["discordChannelId"])
        let decoded = try XCTUnwrap(NotifSecretsPayload.decode(data))
        XCTAssertNil(decoded.discordBotToken)
        XCTAssertNil(decoded.discordChannelId)
    }

    func testWebhookOnlyJSONDoesNotBecomeInboundSecrets() throws {
        let data = try JSONSerialization.data(withJSONObject: [
            "discordWebhookURL": "https://discord.com/api/webhooks/1/abc",
        ])
        let decoded = try XCTUnwrap(NotifSecretsPayload.decode(data))
        XCTAssertEqual(decoded.discordWebhookURL, "https://discord.com/api/webhooks/1/abc")
        XCTAssertNil(decoded.discordBotToken)
        XCTAssertNil(decoded.discordChannelId)
        XCTAssertFalse(
            DiscordInboundPolicy.shouldReceive(
                enabled: true,
                botToken: decoded.discordBotToken,
                channelId: decoded.discordChannelId
            )
        )
    }
}

final class DiscordInboundPolicyTests: XCTestCase {
    let saved = "123456789012345678"
    let token = "BotToken.example"

    func testEmptySecretsOrInboundOffMeansNoReceive() {
        XCTAssertFalse(
            DiscordInboundPolicy.shouldReceive(enabled: false, botToken: token, channelId: saved)
        )
        XCTAssertFalse(
            DiscordInboundPolicy.shouldReceive(enabled: true, botToken: nil, channelId: saved)
        )
        XCTAssertFalse(
            DiscordInboundPolicy.shouldReceive(enabled: true, botToken: token, channelId: nil)
        )
        XCTAssertFalse(
            DiscordInboundPolicy.shouldReceive(enabled: true, botToken: "  ", channelId: saved)
        )
        XCTAssertFalse(
            DiscordInboundPolicy.shouldReceive(enabled: true, botToken: token, channelId: "  ")
        )
        XCTAssertFalse(
            DiscordInboundPolicy.shouldReceive(enabled: true, botToken: "", channelId: "")
        )
        XCTAssertTrue(
            DiscordInboundPolicy.shouldReceive(enabled: true, botToken: token, channelId: saved)
        )
        XCTAssertTrue(
            DiscordInboundPolicy.shouldReceive(
                enabled: true,
                botToken: " BotToken.example ",
                channelId: " 123456789012345678 "
            )
        )
    }

    func testWebhookURLDoesNotEnableInbound() {
        let webhook = "https://discord.com/api/webhooks/1/abc"
        XCTAssertFalse(
            DiscordInboundPolicy.shouldReceive(enabled: true, botToken: nil, channelId: saved)
        )
        XCTAssertEqual(
            DiscordInboundPolicy.intent(
                enabled: true,
                botToken: nil,
                savedChannelId: saved,
                update: .command(channelId: saved, text: "/arm")
            ),
            .ignore
        )
        XCTAssertEqual(
            NotifIdlePostPolicy.destinations(
                discordWebhookURL: webhook,
                telegramBotToken: nil,
                telegramChatId: nil
            ),
            [.discord]
        )
    }

    func testInboundOffIgnoresMatchingArm() {
        XCTAssertEqual(
            DiscordInboundPolicy.intent(
                enabled: false,
                botToken: token,
                savedChannelId: saved,
                update: .command(channelId: saved, text: "arm")
            ),
            .ignore
        )
    }

    func testWrongChannelIdIsIgnored() {
        XCTAssertEqual(
            DiscordInboundPolicy.intent(
                enabled: true,
                botToken: token,
                savedChannelId: saved,
                update: .command(channelId: "100", text: "arm")
            ),
            .ignore
        )
    }

    func testMatchingChannelRoutesArmDisarmStatusHelp() {
        XCTAssertEqual(intent("arm"), .arm)
        XCTAssertEqual(intent("/arm"), .arm)
        XCTAssertEqual(intent(" ARM "), .arm)
        XCTAssertEqual(intent("disarm"), .disarm)
        XCTAssertEqual(intent("/disarm"), .disarm)
        XCTAssertEqual(intent("status"), .status)
        XCTAssertEqual(intent("/status"), .status)
        XCTAssertEqual(intent("/help"), .help)
        XCTAssertEqual(intent("help"), .help)
        XCTAssertEqual(intent("nope"), .ignore)
        XCTAssertEqual(intent("please arm"), .ignore)
        XCTAssertEqual(intent(""), .ignore)
        XCTAssertEqual(
            DiscordInboundPolicy.intent(
                enabled: true,
                botToken: token,
                savedChannelId: saved,
                update: DiscordInboundUpdate(channelId: saved, text: nil)
            ),
            .ignore
        )
    }

    func testChannelIdMatchAcceptsNumericEquivalence() {
        XCTAssertEqual(
            DiscordInboundPolicy.intent(
                enabled: true,
                botToken: token,
                savedChannelId: "99",
                update: .command(channelId: "099", text: "status")
            ),
            .status
        )
    }

    func testSameBotRequiresPresentMatchingToken() {
        XCTAssertTrue(
            DiscordInboundPolicy.sameBot(fetchedToken: token, currentToken: token)
        )
        XCTAssertTrue(
            DiscordInboundPolicy.sameBot(fetchedToken: " \(token) ", currentToken: token)
        )
        XCTAssertFalse(
            DiscordInboundPolicy.sameBot(fetchedToken: "old", currentToken: "new")
        )
        XCTAssertFalse(
            DiscordInboundPolicy.sameBot(fetchedToken: token, currentToken: nil)
        )
        XCTAssertFalse(
            DiscordInboundPolicy.sameBot(fetchedToken: "  ", currentToken: "  ")
        )
    }

    private func intent(_ text: String) -> TelegramInboundIntent {
        DiscordInboundPolicy.intent(
            enabled: true,
            botToken: token,
            savedChannelId: saved,
            update: .command(channelId: saved, text: text)
        )
    }
}

final class DiscordInboundWatchEngineTests: XCTestCase {
    let t0 = Date(timeIntervalSince1970: 10_000)

    func testApplyInboundIsTheSameWatchEnginePathAsTelegram() {
        var telegram = WatchEngine(preferences: .default)
        var discord = WatchEngine(preferences: .default)
        let armT = telegram.applyTelegramInbound(.arm, now: t0)
        let armD = discord.applyInbound(.arm, now: t0)
        XCTAssertEqual(armT, armD)
        XCTAssertEqual(telegram, discord)
        XCTAssertTrue(discord.engaged)
        XCTAssertFalse(armD.contains(.applyBrightnessFloor))
        XCTAssertFalse(armD.contains(.requestKeyboardBacklightOff))

        let again = discord.applyInbound(.arm, now: t0.addingTimeInterval(1))
        XCTAssertTrue(again.isEmpty)

        let disarmT = telegram.applyTelegramInbound(.disarm, now: t0.addingTimeInterval(2))
        let disarmD = discord.applyInbound(.disarm, now: t0.addingTimeInterval(2))
        XCTAssertEqual(disarmT, disarmD)
        XCTAssertEqual(telegram, discord)
        XCTAssertFalse(discord.engaged)
        XCTAssertEqual(disarmD, [.disengage(.user)])
    }

    func testStatusAndHelpDoNotMutateTheWatch() {
        var engine = WatchEngine(preferences: .default)
        _ = engine.userSetEngaged(true, now: t0)
        XCTAssertTrue(engine.applyInbound(.status, now: t0.addingTimeInterval(1)).isEmpty)
        XCTAssertTrue(engine.applyInbound(.help, now: t0.addingTimeInterval(2)).isEmpty)
        XCTAssertTrue(engine.applyInbound(.ignore, now: t0.addingTimeInterval(3)).isEmpty)
        XCTAssertTrue(engine.engaged)
        XCTAssertEqual(engine.preferences.duration, .indefinite)
    }

    func testShouldSetEngagedIsShared() {
        XCTAssertEqual(TelegramInboundIntent.arm.shouldSetEngaged(currentlyEngaged: false), true)
        XCTAssertNil(TelegramInboundIntent.arm.shouldSetEngaged(currentlyEngaged: true))
        XCTAssertEqual(TelegramInboundIntent.disarm.shouldSetEngaged(currentlyEngaged: true), false)
        XCTAssertNil(TelegramInboundIntent.help.shouldSetEngaged(currentlyEngaged: true))
    }
}

private extension DiscordInboundUpdate {
    static func command(channelId: String, text: String) -> DiscordInboundUpdate {
        DiscordInboundUpdate(channelId: channelId, text: text)
    }
}
