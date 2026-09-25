import XCTest
@testable import AgrypnosCore

final class DiscordInboundPopoverChromeTests: XCTestCase {
    func testNotifPlacesDiscordInboundAfterWebhookAndBeforeTelegram() {
        XCTAssertEqual(
            PopoverSection.notif.cards,
            [
                .notifEnable,
                .notifDiscord,
                .notifDiscordInbound,
                .notifTelegram,
                .notifTelegramInbound,
                .notifSetup,
                .notifClear,
            ]
        )
        XCTAssertEqual(PopoverSection.notif.cards.count, 7)
        XCTAssertFalse(PopoverSection.watch.cards.contains(.notifDiscordInbound))
        XCTAssertFalse(PopoverSection.power.cards.contains(.notifDiscordInbound))
        XCTAssertFalse(PopoverSection.agents.cards.contains(.notifDiscordInbound))
        XCTAssertFalse(PopoverSection.general.cards.contains(.notifDiscordInbound))
    }

    func testInboundDefaultsOffAndStaysSeparateFromWebhookOutbound() {
        XCTAssertFalse(DiscordInboundChrome.defaultEnabled)
        XCTAssertFalse(UserPreferences.default.discordInboundEnabled)
        XCTAssertFalse(UserPreferences().discordInboundEnabled)
        XCTAssertNotEqual(AgrypnosCopy.notifDiscordInbound, AgrypnosCopy.notifEnabled)
        XCTAssertNotEqual(AgrypnosCopy.notifDiscordInbound, AgrypnosCopy.notifDiscord)
        XCTAssertFalse(UserPreferences.default.notifEnabled)
        XCTAssertFalse(UserPreferences.default.telegramInboundEnabled)

        var prefs = UserPreferences.default
        prefs.notifEnabled = true
        XCTAssertFalse(prefs.discordInboundEnabled)
        prefs.discordInboundEnabled = true
        XCTAssertTrue(prefs.notifEnabled)
        XCTAssertTrue(prefs.discordInboundEnabled)
        XCTAssertFalse(prefs.telegramInboundEnabled)

        var engine = WatchEngine(preferences: .default)
        engine.userSetDiscordInboundEnabled(true)
        XCTAssertTrue(engine.preferences.discordInboundEnabled)
        XCTAssertFalse(engine.preferences.notifEnabled)
        XCTAssertFalse(engine.preferences.telegramInboundEnabled)
        engine.userSetDiscordInboundEnabled(false)
        XCTAssertFalse(engine.preferences.discordInboundEnabled)
    }

    func testInboundCopyListsSlashCommandsReceivingUpdatesLidGatedDisarmAndLiveBattery() {
        XCTAssertEqual(AgrypnosCopy.notifDiscordInbound, "Discord inbound")
        XCTAssertEqual(
            AgrypnosCopy.notifDiscordInboundHelp,
            "Commands on your Discord bot: /arm, /disarm, /status, /help. If the bot isn’t replying, the Mac is likely asleep / Agrypnos isn’t receiving updates. /disarm with the lid open turns Keep the watch off and does not sleep the Mac. With the lid confirmed closed it turns Keep the watch off and sends the Mac to sleep. /status returns Keep the watch, How long, lid, Agents facts when relevant, last watch end, and safety prefs. /status includes live battery when known: Battery N% · discharging or on AC; omit if unknown."
        )
        let help = AgrypnosCopy.notifDiscordInboundHelp
        let lower = help.lowercased()
        XCTAssertTrue(help.contains("/arm"))
        XCTAssertTrue(help.contains("/disarm"))
        XCTAssertTrue(help.contains("/status"))
        XCTAssertTrue(help.contains("/help"))
        XCTAssertTrue(help.contains(
            "/status returns Keep the watch, How long, lid, Agents facts when relevant, last watch end, and safety prefs."
        ))
        XCTAssertTrue(lower.contains("live battery"))
        XCTAssertTrue(lower.contains("when known"))
        XCTAssertTrue(help.contains("Battery N%"))
        XCTAssertTrue(help.contains("discharging"))
        XCTAssertTrue(help.contains("on AC"))
        XCTAssertTrue(lower.contains("omit if unknown"))
        XCTAssertTrue(lower.contains("your discord bot"))
        XCTAssertTrue(lower.contains("likely asleep"))
        XCTAssertTrue(lower.contains("receiving updates"))
        XCTAssertFalse(lower.contains("polling"))
        XCTAssertTrue(lower.contains("lid open"))
        XCTAssertTrue(lower.contains("does not sleep the mac") || lower.contains("doesn’t sleep the mac"))
        XCTAssertTrue(lower.contains("confirmed closed"))
        XCTAssertTrue(lower.contains("sends the mac to sleep"))
        XCTAssertFalse(lower.contains("listen port"))
        XCTAssertFalse(lower.contains("interactions endpoint"))
        XCTAssertFalse(lower.contains("remaining"))
        XCTAssertFalse(lower.contains("still thinking"))
        XCTAssertFalse(lower.contains("job finished"))
        XCTAssertEqual(DiscordInboundCopy.commandsHelp, "Commands on your Discord bot: /arm, /disarm, /status, /help.")
        XCTAssertTrue(DiscordInboundCopy.help.contains("receiving updates"))
        XCTAssertFalse(DiscordInboundCopy.help.lowercased().contains("polling"))
        XCTAssertEqual(
            CopyWrap.lineCount(help, columns: PopoverCopyLayout.innerColumns),
            PopoverCopyLayout.notifDiscordInboundHelpMaxLines
        )
        XCTAssertEqual(PopoverCopyLayout.notifDiscordInboundHelpMaxLines, 16)
        XCTAssertGreaterThan(
            CopyWrap.lineCount(help, columns: PopoverCopyLayout.innerColumns),
            PopoverCopyLayout.helpMaxLines
        )
        XCTAssertEqual(
            CopyWrap.lineCount(
                AgrypnosCopy.notifDiscordInbound,
                columns: PopoverCopyLayout.innerColumns
            ),
            1
        )
    }

    func testInboundChromeIsToggleTokenChannelAndHelpSeparateFromWebhook() {
        let layout = PopoverStackLayout.make(section: .notif)
        XCTAssertNotNil(layout.notifDiscordInbound)
        XCTAssertEqual(
            layout.notifDiscordInbound?.y,
            layout.notifDiscord!.maxY + PopoverStackLayout.cardGap
        )
        XCTAssertEqual(
            layout.notifTelegram?.y,
            layout.notifDiscordInbound!.maxY + PopoverStackLayout.cardGap
        )
        XCTAssertEqual(
            layout.notifDiscordInbound!.height,
            PopoverStackLayout.inset
                + PopoverStackLayout.titleRowHeight
                + PopoverCopyLayout.notifDiscordInboundHelpHeightPoints
                + 2 * PopoverStackLayout.secretFieldRowHeight
                + PopoverStackLayout.switchRowHeight
                + PopoverStackLayout.inset
        )
        XCTAssertEqual(
            PopoverStackLayout.notifDiscordInboundTokenY,
            PopoverStackLayout.prefHelpY + PopoverCopyLayout.notifDiscordInboundHelpHeightPoints
        )
        XCTAssertEqual(
            PopoverStackLayout.notifDiscordInboundChannelY,
            PopoverStackLayout.notifDiscordInboundTokenY + PopoverStackLayout.secretFieldRowHeight
        )
        XCTAssertEqual(
            PopoverStackLayout.notifDiscordInboundSwitchY,
            PopoverStackLayout.notifDiscordInboundChannelY + PopoverStackLayout.secretFieldRowHeight
        )
        XCTAssertEqual(
            layout.stackedCards.map(\.y),
            compactYs(
                layout.notifEnable,
                layout.notifDiscord,
                layout.notifDiscordInbound,
                layout.notifTelegram,
                layout.notifTelegramInbound,
                layout.notifSetup,
                layout.notifClear
            )
        )
        XCTAssertEqual(layout.stackedCards.count, 7)
        XCTAssertNil(layout.watch)
        XCTAssertEqual(layout.contentHeight, layout.notifClear!.maxY + PopoverStackLayout.pad)
        XCTAssertEqual(
            layout.popoverHeight,
            min(layout.contentHeight, PopoverStackLayout.maxVisibleHeight)
        )
        XCTAssertEqual(layout.needsScroll, layout.contentHeight > layout.popoverHeight)
        XCTAssertGreaterThan(
            layout.notifDiscordInbound!.height,
            layout.notifDiscord!.height
        )
    }

    func testWebhookCardStaysOutboundOnly() {
        XCTAssertEqual(AgrypnosCopy.notifDiscord, "Discord webhook URL")
        XCTAssertTrue(AgrypnosCopy.notifDiscordHelp.lowercased().contains("your webhook"))
        XCTAssertFalse(AgrypnosCopy.notifDiscord.lowercased().contains("inbound"))
        XCTAssertFalse(AgrypnosCopy.notifDiscordHelp.lowercased().contains("inbound"))
        XCTAssertFalse(AgrypnosCopy.notifDiscordHelp.lowercased().contains("arm"))
        XCTAssertFalse(AgrypnosCopy.notifDiscordHelp.lowercased().contains("listen port"))
        XCTAssertFalse(AgrypnosCopy.notifDiscordHelp.lowercased().contains("interactions endpoint"))
        XCTAssertEqual(AgrypnosCopy.notifDiscordInboundTokenShort, "Token")
        XCTAssertEqual(AgrypnosCopy.notifDiscordInboundChannelShort, "Channel")
        XCTAssertEqual(AgrypnosCopy.notifDiscordInboundTokenPlaceholder, "paste bot token")
        XCTAssertEqual(AgrypnosCopy.notifDiscordInboundChannelPlaceholder, "channel id")
        XCTAssertFalse(AgrypnosCopy.notifDiscordInboundHelp.contains("123456"))
        XCTAssertFalse(AgrypnosCopy.notifDiscordInboundHelp.contains("YOUR_TOKEN"))
        XCTAssertFalse(AgrypnosCopy.notifDiscordInbound.contains("http"))
        XCTAssertFalse(AgrypnosCopy.notifDiscordInboundHelp.lowercased().contains("webhook"))
    }

    func testInboundCopyBansListenPortWebhookAsInboundPollingAndRichStatus() {
        let blob = inboundChromeBlob()
        XCTAssertTrue(blob.contains("your discord bot"))
        XCTAssertTrue(blob.contains("/arm"))
        XCTAssertTrue(blob.contains("/disarm"))
        XCTAssertTrue(blob.contains("/status"))
        XCTAssertTrue(blob.contains("/help"))
        XCTAssertTrue(blob.contains("likely asleep"))
        XCTAssertTrue(blob.contains("receiving updates"))
        XCTAssertTrue(blob.contains("discord inbound"))
        XCTAssertFalse(blob.contains("keychain"))
        for banned in [
            "we notify your phone",
            "notify your phone",
            "agent stopped",
            "job finished",
            "still thinking",
            "agent finished",
            "mac-proven",
            "mac proven",
            "finish eta",
            "task text",
            "remote-control",
            "remote control",
            "shared agrypnos bot",
            "disarm always sleeps",
            "the mac is asleep.",
            "listen port",
            "interactions endpoint",
            "isn't polling",
            "isn’t polling",
            "not polling",
        ] {
            XCTAssertFalse(blob.contains(banned), "banned phrase in Discord inbound chrome: \(banned)")
        }
    }

    func testBotTokenAndChannelIdChromePersistOrReject() {
        XCTAssertEqual(
            DiscordBotTokenChrome.commit("BotToken.example.value.longenough"),
            .persist("BotToken.example.value.longenough")
        )
        XCTAssertEqual(DiscordBotTokenChrome.commit("  MTIz.abc.defghijklmnopqrst  "), .persist("MTIz.abc.defghijklmnopqrst"))
        XCTAssertEqual(DiscordBotTokenChrome.commit(""), .clear)
        XCTAssertEqual(DiscordBotTokenChrome.commit("   "), .clear)
        XCTAssertEqual(
            DiscordBotTokenChrome.commit("https://discord.com/api/webhooks/1/abc"),
            .reject
        )
        XCTAssertEqual(DiscordBotTokenChrome.commit("short"), .reject)

        XCTAssertEqual(DiscordChannelIdChrome.commit("123456789012345678"), .persist("123456789012345678"))
        XCTAssertEqual(DiscordChannelIdChrome.commit("  99  "), .persist("99"))
        XCTAssertEqual(DiscordChannelIdChrome.commit(""), .clear)
        XCTAssertEqual(DiscordChannelIdChrome.commit("   "), .clear)
        XCTAssertEqual(DiscordChannelIdChrome.commit("not-a-id"), .reject)
        XCTAssertEqual(DiscordChannelIdChrome.commit("-100123"), .reject)
        XCTAssertEqual(
            AgrypnosCopy.notifDiscordInboundTokenInvalid,
            "That is not a Discord bot token. Nothing was saved."
        )
        XCTAssertEqual(
            AgrypnosCopy.notifDiscordInboundChannelInvalid,
            "That is not a Discord channel id. Nothing was saved."
        )
    }

    func testSetupHelpNamesDiscordInboundWithoutClaimingMacProve() {
        let help = AgrypnosCopy.notifSetupHelp
        let lower = help.lowercased()
        XCTAssertTrue(lower.contains("discord inbound"))
        XCTAssertTrue(lower.contains("webhook"))
        XCTAssertTrue(help.contains("/arm") && help.contains("/disarm") && help.contains("/status") && help.contains("/help"))
        XCTAssertFalse(lower.contains("mac-proven"))
        XCTAssertFalse(lower.contains("mac proven"))
        XCTAssertFalse(lower.contains("listen port"))
        XCTAssertFalse(lower.contains("interactions endpoint"))
        XCTAssertEqual(
            CopyWrap.lineCount(help, columns: PopoverCopyLayout.innerColumns),
            PopoverCopyLayout.notifSetupHelpMaxLines
        )
        XCTAssertEqual(PopoverCopyLayout.notifSetupHelpMaxLines, 24)
        XCTAssertEqual(
            PopoverCopyLayout.notifSetupHelpHeightPoints,
            24 * PopoverCopyLayout.lineHeightPoints
        )
    }

    func testTransportStaysGatewayWithNoListenPort() {
        XCTAssertNil(DiscordInboundTransport.listenPort)
        XCTAssertNil(DiscordInboundTransport.interactionsEndpointURL)
        XCTAssertFalse(DiscordInboundTransport.usesIncomingWebhook)
        XCTAssertFalse(DiscordInboundTransport.scrapeChannelHistoryOnWake)
    }

    private func inboundChromeBlob() -> String {
        [
            AgrypnosCopy.notifDiscordInbound,
            AgrypnosCopy.notifDiscordInboundHelp,
            AgrypnosCopy.notifDiscordInboundTokenShort,
            AgrypnosCopy.notifDiscordInboundChannelShort,
            AgrypnosCopy.notifDiscordInboundTokenPlaceholder,
            AgrypnosCopy.notifDiscordInboundChannelPlaceholder,
            DiscordInboundCopy.commandsHelp,
            DiscordInboundCopy.help,
        ].joined(separator: "\n").lowercased()
    }

    private func compactYs(_ slots: PopoverSlot?...) -> [Int] {
        slots.compactMap { $0?.y }
    }
}
