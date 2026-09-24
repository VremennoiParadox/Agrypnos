import XCTest
@testable import AgrypnosCore

final class TelegramInboundPopoverChromeTests: XCTestCase {
    func testNotifPlacesInboundAfterTelegramSecretsAndBeforeSetup() {
        XCTAssertEqual(
            PopoverSection.notif.cards,
            [
                .notifEnable,
                .notifDiscord,
                .notifTelegram,
                .notifTelegramInbound,
                .notifSetup,
                .notifClear,
            ]
        )
        XCTAssertEqual(PopoverSection.notif.cards.count, 6)
        XCTAssertFalse(PopoverSection.watch.cards.contains(.notifTelegramInbound))
        XCTAssertFalse(PopoverSection.power.cards.contains(.notifTelegramInbound))
        XCTAssertFalse(PopoverSection.agents.cards.contains(.notifTelegramInbound))
        XCTAssertFalse(PopoverSection.general.cards.contains(.notifTelegramInbound))
    }

    func testInboundDefaultsOffAndStaysSeparateFromOutboundPOST() {
        XCTAssertFalse(TelegramInboundChrome.defaultEnabled)
        XCTAssertFalse(UserPreferences.default.telegramInboundEnabled)
        XCTAssertFalse(UserPreferences().telegramInboundEnabled)
        XCTAssertNotEqual(AgrypnosCopy.notifTelegramInbound, AgrypnosCopy.notifEnabled)
        XCTAssertFalse(UserPreferences.default.notifEnabled)

        var prefs = UserPreferences.default
        prefs.notifEnabled = true
        XCTAssertFalse(prefs.telegramInboundEnabled)
        prefs.telegramInboundEnabled = true
        XCTAssertTrue(prefs.notifEnabled)
        XCTAssertTrue(prefs.telegramInboundEnabled)

        var engine = WatchEngine(preferences: .default)
        engine.userSetTelegramInboundEnabled(true)
        XCTAssertTrue(engine.preferences.telegramInboundEnabled)
        XCTAssertFalse(engine.preferences.notifEnabled)
        engine.userSetTelegramInboundEnabled(false)
        XCTAssertFalse(engine.preferences.telegramInboundEnabled)
    }

    func testInboundCopyListsSlashCommandsAsleepAndLidGatedDisarm() {
        XCTAssertEqual(AgrypnosCopy.notifTelegramInbound, "Telegram inbound")
        XCTAssertEqual(
            AgrypnosCopy.notifTelegramInboundHelp,
            "Commands on your Telegram bot: /arm, /disarm, /status, /help. If the bot isn’t replying, the Mac is likely asleep / Agrypnos isn’t polling. /disarm with the lid open turns Keep the watch off and does not sleep the Mac. With the lid confirmed closed it turns Keep the watch off and sends the Mac to sleep."
        )
        let help = AgrypnosCopy.notifTelegramInboundHelp
        let lower = help.lowercased()
        XCTAssertTrue(help.contains("/arm"))
        XCTAssertTrue(help.contains("/disarm"))
        XCTAssertTrue(help.contains("/status"))
        XCTAssertTrue(help.contains("/help"))
        XCTAssertTrue(lower.contains("your telegram bot"))
        XCTAssertTrue(lower.contains("likely asleep"))
        XCTAssertTrue(lower.contains("isn’t polling") || lower.contains("isn't polling"))
        XCTAssertTrue(lower.contains("lid open"))
        XCTAssertTrue(lower.contains("does not sleep the mac") || lower.contains("doesn’t sleep the mac"))
        XCTAssertTrue(lower.contains("confirmed closed"))
        XCTAssertTrue(lower.contains("sends the mac to sleep"))
        XCTAssertTrue(TelegramInboundCopy.help.contains("/arm"))
        XCTAssertTrue(TelegramInboundCopy.help.contains("/disarm"))
        XCTAssertTrue(TelegramInboundCopy.help.contains("/status"))
        XCTAssertTrue(TelegramInboundCopy.help.contains("/help"))
        XCTAssertEqual(
            CopyWrap.lineCount(help, columns: PopoverCopyLayout.innerColumns),
            PopoverCopyLayout.notifTelegramInboundHelpMaxLines
        )
        XCTAssertEqual(PopoverCopyLayout.notifTelegramInboundHelpMaxLines, 9)
        XCTAssertGreaterThan(
            CopyWrap.lineCount(help, columns: PopoverCopyLayout.innerColumns),
            PopoverCopyLayout.helpMaxLines
        )
        XCTAssertEqual(
            CopyWrap.lineCount(
                AgrypnosCopy.notifTelegramInbound,
                columns: PopoverCopyLayout.innerColumns
            ),
            1
        )
    }

    func testInboundChromeIsTogglePlusHelpNotARemotePanel() {
        let layout = PopoverStackLayout.make(section: .notif)
        XCTAssertNotNil(layout.notifTelegramInbound)
        XCTAssertEqual(
            layout.notifTelegramInbound?.y,
            layout.notifTelegram!.maxY + PopoverStackLayout.cardGap
        )
        XCTAssertEqual(
            layout.notifSetup?.y,
            layout.notifTelegramInbound!.maxY + PopoverStackLayout.cardGap
        )
        XCTAssertEqual(
            layout.notifTelegramInbound!.height,
            PopoverStackLayout.inset
                + PopoverStackLayout.titleRowHeight
                + PopoverCopyLayout.notifTelegramInboundHelpHeightPoints
                + PopoverStackLayout.switchRowHeight
                + PopoverStackLayout.inset
        )
        XCTAssertEqual(
            PopoverStackLayout.notifTelegramInboundSwitchY,
            PopoverStackLayout.prefHelpY + PopoverCopyLayout.notifTelegramInboundHelpHeightPoints
        )
        XCTAssertEqual(
            layout.stackedCards.map(\.y),
            compactYs(
                layout.notifEnable,
                layout.notifDiscord,
                layout.notifTelegram,
                layout.notifTelegramInbound,
                layout.notifSetup,
                layout.notifClear
            )
        )
        XCTAssertEqual(layout.stackedCards.count, 6)
        XCTAssertNil(layout.watch)
        XCTAssertEqual(layout.contentHeight, layout.notifClear!.maxY + PopoverStackLayout.pad)
        XCTAssertEqual(
            layout.popoverHeight,
            min(layout.contentHeight, PopoverStackLayout.maxVisibleHeight)
        )
        XCTAssertEqual(layout.needsScroll, layout.contentHeight > layout.popoverHeight)
        XCTAssertGreaterThan(
            layout.notifTelegramInbound!.height,
            PopoverStackLayout.switchRowHeight
        )
        XCTAssertGreaterThan(
            layout.notifTelegramInbound!.height,
            layout.notifTelegram!.height
        )
        XCTAssertLessThan(
            layout.notifTelegramInbound!.height,
            layout.notifSetup!.height
        )
    }

    func testInboundCopyBansJobFinishedPhoneNotifyAndRichStatus() {
        let blob = inboundChromeBlob()
        XCTAssertTrue(blob.contains("your telegram bot"))
        XCTAssertTrue(blob.contains("/arm"))
        XCTAssertTrue(blob.contains("/disarm"))
        XCTAssertTrue(blob.contains("/status"))
        XCTAssertTrue(blob.contains("/help"))
        XCTAssertTrue(blob.contains("likely asleep"))
        XCTAssertTrue(blob.contains("telegram inbound"))
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
            "discord inbound",
            "disarm always sleeps",
            "the mac is asleep.",
        ] {
            XCTAssertFalse(blob.contains(banned), "banned phrase in inbound chrome: \(banned)")
        }
    }

    func testDiscordStaysOutboundOnlyAndSecretsStayOnTheTelegramCard() {
        XCTAssertEqual(AgrypnosCopy.notifDiscord, "Discord webhook URL")
        XCTAssertTrue(AgrypnosCopy.notifDiscordHelp.lowercased().contains("your webhook"))
        XCTAssertFalse(AgrypnosCopy.notifDiscord.lowercased().contains("inbound"))
        XCTAssertFalse(AgrypnosCopy.notifDiscordHelp.lowercased().contains("inbound"))
        XCTAssertFalse(AgrypnosCopy.notifDiscordHelp.lowercased().contains("arm"))
        XCTAssertEqual(AgrypnosCopy.notifTelegramTokenShort, "Token")
        XCTAssertEqual(AgrypnosCopy.notifTelegramChatShort, "Chat id")
        XCTAssertFalse(AgrypnosCopy.notifTelegramInboundHelp.contains("123456"))
        XCTAssertFalse(AgrypnosCopy.notifTelegramInboundHelp.contains("YOUR_TOKEN"))
        XCTAssertFalse(AgrypnosCopy.notifTelegramInbound.contains("http"))
    }

    func testSetupHelpNamesInboundOnOffWithoutClaimingMacProve() {
        let help = AgrypnosCopy.notifSetupHelp
        let lower = help.lowercased()
        XCTAssertTrue(lower.contains("telegram inbound"))
        XCTAssertTrue(help.contains("/arm") && help.contains("/disarm") && help.contains("/status") && help.contains("/help"))
        XCTAssertTrue(lower.contains("separate from") && lower.contains("post"))
        XCTAssertFalse(lower.contains("mac-proven"))
        XCTAssertFalse(lower.contains("mac proven"))
        XCTAssertFalse(lower.contains("we notify your phone"))
        XCTAssertEqual(
            CopyWrap.lineCount(help, columns: PopoverCopyLayout.innerColumns),
            PopoverCopyLayout.notifSetupHelpMaxLines
        )
        XCTAssertEqual(PopoverCopyLayout.notifSetupHelpMaxLines, 21)
        XCTAssertEqual(
            PopoverCopyLayout.notifSetupHelpHeightPoints,
            21 * PopoverCopyLayout.lineHeightPoints
        )
    }

    private func inboundChromeBlob() -> String {
        [
            AgrypnosCopy.notifTelegramInbound,
            AgrypnosCopy.notifTelegramInboundHelp,
            AgrypnosCopy.notifSetupHelp,
            AgrypnosCopy.notifEnabled,
            AgrypnosCopy.notifEnabledHelp,
            AgrypnosCopy.notifDiscord,
            AgrypnosCopy.notifDiscordHelp,
            AgrypnosCopy.notifTelegram,
            AgrypnosCopy.notifTelegramHelp,
            TelegramInboundCopy.commandsHelp,
        ].joined(separator: "\n").lowercased()
    }

    private func compactYs(_ slots: PopoverSlot?...) -> [Int] {
        slots.compactMap { $0?.y }
    }
}
