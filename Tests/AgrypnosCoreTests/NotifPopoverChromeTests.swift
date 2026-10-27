import XCTest
@testable import AgrypnosCore

final class NotifPopoverChromeTests: XCTestCase {
    func testNotifSectionCardsAreEnableDiscordTelegramInboundSetupAndClear() {
        XCTAssertEqual(
            PopoverSection.notif.cards,
            [
                .notifSetup,
                .notifEnable,
                .notifDiscord,
                .notifTelegram,
                .questionNotifications,
                .notifClear,
            ]
        )
        XCTAssertEqual(PopoverSection.notif.cards.count, 6)
        XCTAssertFalse(PopoverSection.notif.cards.contains(.notifTelegramInbound))
        XCTAssertEqual(PopoverSection.notif.cards.filter { $0 == .notifDiscord }.count, 1)
        XCTAssertFalse(PopoverSection.notif.cards.contains(.notifDiscordInbound))
        XCTAssertEqual(PopoverSection.notif.cards.first, .notifSetup)
        XCTAssertEqual(PopoverSection.notif.cards.last, .notifClear)
        XCTAssertFalse(PopoverSection.watch.cards.contains(.notifEnable))
        XCTAssertFalse(PopoverSection.power.cards.contains(.notifSetup))
        XCTAssertFalse(PopoverSection.agents.cards.contains(.notifClear))
        XCTAssertFalse(PopoverSection.general.cards.contains(.notifDiscord))
    }

    func testNotifChromeUsesDefaultOff() {
        XCTAssertFalse(UserPreferences.default.notifEnabled)
        XCTAssertFalse(UserPreferences().notifEnabled)
        XCTAssertFalse(NotifEnableChrome.defaultEnabled)
        XCTAssertEqual(NotifEnableChrome.defaultEnabled, UserPreferences.default.notifEnabled)
    }

    func testTelegramCommitClearsEmptyAndKeepsTrimmedValue() {
        XCTAssertNil(NotifOptionalSecretChrome.commit(""))
        XCTAssertNil(NotifOptionalSecretChrome.commit("  "))
        XCTAssertEqual(NotifOptionalSecretChrome.commit("123:token"), "123:token")
        XCTAssertEqual(NotifOptionalSecretChrome.commit("  -1001  "), "-1001")
        XCTAssertEqual(NotifOptionalSecretChrome.commit("99"), "99")
    }

    func testTelegramBotTokenCommitNeedsARealBotTokenNotAPrefix() {
        XCTAssertEqual(
            TelegramBotTokenChrome.commit("111:AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"),
            .persist("111:AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA")
        )
        XCTAssertEqual(TelegramBotTokenChrome.commit(""), .clear)
        XCTAssertEqual(TelegramBotTokenChrome.commit("111"), .reject)
        XCTAssertEqual(TelegramBotTokenChrome.commit("111:"), .reject)
        XCTAssertEqual(TelegramBotTokenChrome.commit("111:short"), .reject)
        XCTAssertEqual(TelegramBotTokenChrome.commit("not-a-token"), .reject)
        XCTAssertEqual(
            TelegramBotTokenChrome.commit(
                """
                Use this token to access the HTTP API:
                111:AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
                Keep your token secure
                """
            ),
            .persist("111:AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA")
        )
        XCTAssertEqual(
            TelegramBotTokenChrome.commit("HTTP API: 111:AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"),
            .persist("111:AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA")
        )
        XCTAssertEqual(
            AgrypnosCopy.notifTelegramTokenInvalid,
            "That is not a Telegram bot token. Nothing was saved."
        )
    }

    func testTelegramChatIdPersistsNumericIdsAndRejectsJunk() {
        XCTAssertEqual(TelegramChatIdChrome.commit("5728126329"), .persist("5728126329"))
        XCTAssertEqual(TelegramChatIdChrome.commit("  -1001234567890  "), .persist("-1001234567890"))
        XCTAssertEqual(TelegramChatIdChrome.commit(""), .clear)
        XCTAssertEqual(TelegramChatIdChrome.commit("   "), .clear)
        XCTAssertEqual(TelegramChatIdChrome.commit("not-a-id"), .reject)
        XCTAssertEqual(TelegramChatIdChrome.commit("@channel"), .reject)
    }

    func testTelegramChatIdKeepsAPalindromicEvenLengthId() {
        XCTAssertEqual(TelegramChatIdChrome.commit("12121212"), .persist("12121212"))
    }

    func testTelegramFieldsHaveVisibleTokenAndChatIdCaptions() {
        XCTAssertEqual(AgrypnosCopy.notifTelegramTokenShort, "Token")
        XCTAssertEqual(AgrypnosCopy.notifTelegramChatShort, "Chat id")
        XCTAssertEqual(AgrypnosCopy.notifTelegramUserId, "Telegram user id")
        XCTAssertEqual(AgrypnosCopy.notifDiscordUserId, "Discord user id")
        let needed = AgrypnosCopy.notifTelegramChatShort.count * 9 + 8
        let userLabel = AgrypnosCopy.notifTelegramUserId.count * 9 + 8
        XCTAssertGreaterThanOrEqual(PopoverCopyLayout.secretFieldLabelWidthPoints, needed)
        XCTAssertGreaterThanOrEqual(PopoverCopyLayout.secretFieldLabelWidthPoints, userLabel)
        XCTAssertEqual(AgrypnosCopy.notifSaveFailed, "Couldn't save that secret.")
        XCTAssertFalse(AgrypnosCopy.notifSaveFailed.lowercased().contains("saved."))
    }

    func testSecretRevealButtonSitsBesideTheFieldAndStartsHidden() {
        let total = 200
        let field = SecretRevealChrome.fieldWidth(total: total)
        XCTAssertEqual(
            field + SecretRevealChrome.gapPoints + SecretRevealChrome.buttonWidthPoints,
            total
        )
        XCTAssertGreaterThanOrEqual(field, SecretRevealChrome.fieldMinWidthPoints)
        XCTAssertEqual(SecretRevealChrome.symbolName(revealed: false), "eye")
        XCTAssertEqual(SecretRevealChrome.symbolName(revealed: true), "eye.slash")
        XCTAssertTrue(SecretRevealChrome.nextRevealed(false))
        XCTAssertFalse(SecretRevealChrome.nextRevealed(true))
        XCTAssertEqual(
            AgrypnosCopy.revealAccess(label: AgrypnosCopy.notifDiscordInboundToken, revealed: false),
            "Show Discord bot token"
        )
        XCTAssertEqual(
            AgrypnosCopy.revealAccess(label: AgrypnosCopy.notifDiscordInboundChannelId, revealed: true),
            "Hide Discord channel id"
        )
        XCTAssertNotEqual(
            AgrypnosCopy.revealAccess(label: AgrypnosCopy.notifTelegramToken, revealed: false),
            AgrypnosCopy.revealAccess(label: AgrypnosCopy.notifTelegramChatId, revealed: false)
        )
    }

    func testTelegramHelpAndPlaceholdersSayWhereChatIdComesFrom() {
        let help = AgrypnosCopy.notifTelegramHelp.lowercased()
        XCTAssertTrue(help.contains("your telegram bot"))
        XCTAssertFalse(help.contains("does not run a shared bot"))
        XCTAssertTrue(help.contains("chat id"))
        XCTAssertTrue(help.contains("getupdates"))
        XCTAssertEqual(
            CopyWrap.lineCount(
                AgrypnosCopy.notifTelegramHelp,
                columns: PopoverCopyLayout.innerColumns
            ),
            PopoverCopyLayout.notifTelegramHelpMaxLines
        )
        XCTAssertEqual(AgrypnosCopy.notifTelegramChatPlaceholder, "from getUpdates")
        XCTAssertEqual(AgrypnosCopy.notifTelegramTokenPlaceholder, "paste bot token")
        XCTAssertFalse(AgrypnosCopy.notifTelegramChatPlaceholder.contains("123456"))
    }

    func testClearSecretsCopyDeletesSavedFileNotKeychain() {
        XCTAssertEqual(AgrypnosCopy.notifClear, "Clear secrets")
        XCTAssertTrue(BotGuide.allText.lowercased().contains("clear secrets"))
        XCTAssertFalse(BotGuide.allText.lowercased().contains("keychain"))
        XCTAssertEqual(NotifSecretsFileChrome.folderName, "Agrypnos")
        XCTAssertEqual(NotifSecretsFileChrome.fileName, "notif-secrets.json")
        XCTAssertFalse(NotifSecretsFileChrome.fileName.contains("preferences"))
        XCTAssertNil(NotifOptionalSecretChrome.commit(""))
    }

    func testSecretsPayloadRoundTripsAndOmitsEmptyFields() throws {
        let data = try XCTUnwrap(
            NotifSecretsPayload.encode(
                telegramBotToken: "111:token",
                telegramChatId: "5728126329"
            )
        )
        let decoded = try XCTUnwrap(NotifSecretsPayload.decode(data))
        XCTAssertEqual(decoded.telegramBotToken, "111:token")
        XCTAssertEqual(decoded.telegramChatId, "5728126329")
        let empty = try XCTUnwrap(NotifSecretsPayload.encode(
            telegramBotToken: nil,
            telegramChatId: ""
        ))
        let emptyDecoded = try XCTUnwrap(NotifSecretsPayload.decode(empty))
        XCTAssertNil(emptyDecoded.telegramBotToken)
        XCTAssertNil(emptyDecoded.telegramChatId)
    }

    func testSetupIsAButtonToASelfServeGuide() {
        XCTAssertEqual(AgrypnosCopy.notifSetup, "Setup instructions…")
        XCTAssertEqual(
            CopyWrap.lineCount(AgrypnosCopy.notifSetup, columns: PopoverCopyLayout.innerColumns),
            1
        )
        let help = BotGuide.allText
        let lower = help.lowercased()
        XCTAssertFalse(help.contains("Webhooks → New Webhook"))
        XCTAssertFalse(help.contains("Copy Webhook URL"))
        XCTAssertFalse(help.contains("discord.com/api/webhooks/"))
        XCTAssertTrue(help.contains("Developer Portal"))
        XCTAssertTrue(help.contains("Reset Token"))
        XCTAssertTrue(help.contains("applications.commands"))
        XCTAssertTrue(help.contains("Copy Channel ID"))
        XCTAssertTrue(help.contains("Watch-end POST"))
        XCTAssertTrue(help.contains("asks the Mac to sleep"))
        XCTAssertTrue(lower.contains("old webhook url is unused"))
        XCTAssertTrue(help.contains("BotFather"))
        XCTAssertTrue(help.contains("/newbot"))
        XCTAssertTrue(help.contains("getUpdates"))
        XCTAssertTrue(lower.contains("empty result"))
        XCTAssertTrue(lower.contains("arm") && help.contains("Agents"))
        XCTAssertTrue(lower.contains("local busy"))
        XCTAssertTrue(lower.contains("wait after agent signals stop"))
        XCTAssertTrue(lower.contains("one message"))
        XCTAssertTrue(lower.contains("clear secrets"))
        XCTAssertTrue(lower.contains("live battery"))
        XCTAssertTrue(lower.contains("when known"))
        XCTAssertFalse(isReadmeOnly(help))
    }

    func testEnableAndTelegramHelpFitTallerSlots() {
        XCTAssertEqual(
            CopyWrap.lineCount(
                AgrypnosCopy.notifEnabledHelp,
                columns: PopoverCopyLayout.innerColumns
            ),
            6
        )
        XCTAssertEqual(PopoverCopyLayout.notifEnableHelpMaxLines, 6)
        XCTAssertEqual(
            CopyWrap.lineCount(
                AgrypnosCopy.notifTelegramHelp,
                columns: PopoverCopyLayout.innerColumns
            ),
            4
        )
        XCTAssertEqual(PopoverCopyLayout.notifTelegramHelpMaxLines, 4)
        XCTAssertEqual(
            CopyWrap.lineCount(
                AgrypnosCopy.notifDiscordHelp,
                columns: PopoverCopyLayout.innerColumns
            ),
            7
        )
        XCTAssertEqual(PopoverCopyLayout.notifDiscordHelpMaxLines, 7)
    }

    func testDiscordCardIsTheBotWithoutAWebhookField() {
        XCTAssertEqual(AgrypnosCopy.notifDiscord, "Discord")
        XCTAssertEqual(
            AgrypnosCopy.notifDiscordHelp,
            "Messages this channel when Watch-end POST is on, including when Agrypnos asks the Mac to sleep. Commands: /arm, /disarm, /status, /help, when Discord inbound is on. Needs your bot token + channel id. Details in Setup instructions."
        )
        let help = AgrypnosCopy.notifEnabledHelp
        XCTAssertTrue(help.contains("timer"))
        XCTAssertTrue(help.contains("wait after agent signals stop"))
        let telegram = help.split(separator: ".").first { $0.contains("Telegram") }.map(String.init) ?? help
        XCTAssertFalse(telegram.localizedCaseInsensitiveContains("asks the Mac to sleep"))
        XCTAssertTrue(help.contains("asks the Mac to sleep"))
        XCTAssertEqual(
            AgrypnosCopy.notifDiscordPostFailed,
            "Couldn't message your Discord bot."
        )
        XCTAssertFalse(AgrypnosCopy.notifDiscordHelp.lowercased().contains("webhook"))
        XCTAssertFalse(AgrypnosCopy.notifEnabledHelp.lowercased().contains("webhook"))
        XCTAssertEqual(PopoverSection.notif.cards.filter { $0 == .notifDiscord }.count, 1)
        XCTAssertFalse(PopoverSection.notif.cards.contains(.notifDiscordInbound))
    }

    func testNotifCopyStaysIdleAfterWaitAndNamesYourBot() {
        let blob = [
            AgrypnosCopy.notifEnabled,
            AgrypnosCopy.notifEnabledHelp,
            AgrypnosCopy.notifDiscord,
            AgrypnosCopy.notifDiscordHelp,
            AgrypnosCopy.notifTelegram,
            AgrypnosCopy.notifTelegramTokenShort,
            AgrypnosCopy.notifTelegramChatShort,
            AgrypnosCopy.notifTelegramToken,
            AgrypnosCopy.notifTelegramChatId,
            AgrypnosCopy.notifTelegramTokenPlaceholder,
            AgrypnosCopy.notifTelegramChatPlaceholder,
            AgrypnosCopy.notifTelegramHelp,
            AgrypnosCopy.notifTelegramInbound,
            AgrypnosCopy.notifTelegramInboundHelp,
            AgrypnosCopy.notifDiscordInbound,
            AgrypnosCopy.notifDiscordInboundHelp,
            AgrypnosCopy.notifSetup,
            BotGuide.allText,
            AgrypnosCopy.notifClear,
            AgrypnosCopy.revealAccess(label: AgrypnosCopy.notifDiscordInboundToken, revealed: false),
            AgrypnosCopy.revealAccess(label: AgrypnosCopy.notifTelegramToken, revealed: true),
            AgrypnosCopy.notifSaveFailed,
            AgrypnosCopy.notifDiscordPostFailed,
            AgrypnosCopy.notifTelegramPostFailed,
            AgrypnosCopy.notifTelegramChatInvalid,
            AgrypnosCopy.notifTelegramTokenInvalid,
            AgrypnosCopy.notifIdleBody,
        ].joined(separator: "\n").lowercased()
        XCTAssertTrue(blob.contains("your discord bot"))
        XCTAssertTrue(blob.contains("your telegram bot"))
        XCTAssertTrue(blob.contains("does not run a shared bot"))
        XCTAssertTrue(blob.contains("wait after agent signals stop"))
        XCTAssertTrue(blob.contains("show discord bot token"))
        XCTAssertTrue(blob.contains("hide telegram bot token"))
        XCTAssertFalse(blob.contains("keychain"))
        for banned in [
            "we notify your phone",
            "notify your phone",
            "agent stopped",
            "job finished",
            "still thinking",
            "agent finished",
            "login keychain",
        ] {
            XCTAssertFalse(blob.contains(banned), "banned phrase in Notif chrome copy: \(banned)")
        }
    }

    func testNotifSectionStacksCardsAndMayScroll() {
        let layout = PopoverStackLayout.make(section: .notif)
        XCTAssertEqual(layout.section, .notif)
        XCTAssertEqual(
            layout.stackedCards.map(\.y),
            compactYs(
                layout.notifSetup,
                layout.notifEnable,
                layout.notifDiscord,
                layout.notifTelegram,
                layout.questionNotifications,
                layout.notifClear
            )
        )
        XCTAssertEqual(layout.notifSetup?.y, PopoverStackLayout.firstCardY)
        XCTAssertEqual(layout.notifEnable?.y, layout.notifSetup!.maxY + PopoverStackLayout.cardGap)
        XCTAssertEqual(layout.notifDiscord?.y, layout.notifEnable!.maxY + PopoverStackLayout.cardGap)
        XCTAssertNil(layout.notifDiscordInbound)
        XCTAssertNil(layout.notifTelegramInbound)
        XCTAssertEqual(layout.notifTelegram?.y, layout.notifDiscord!.maxY + PopoverStackLayout.cardGap)
        XCTAssertEqual(
            layout.questionNotifications?.y,
            layout.notifTelegram!.maxY + PopoverStackLayout.cardGap
        )
        XCTAssertEqual(layout.notifClear?.y, layout.questionNotifications!.maxY + PopoverStackLayout.cardGap)
        XCTAssertEqual(layout.contentHeight, layout.notifClear!.maxY + PopoverStackLayout.pad)
        XCTAssertNil(layout.watch)
        XCTAssertNil(layout.settle)
        XCTAssertNil(layout.login)
        XCTAssertNil(layout.quitY)
        XCTAssertEqual(
            layout.popoverHeight,
            min(layout.contentHeight, PopoverStackLayout.maxVisibleHeight)
        )
        XCTAssertEqual(layout.needsScroll, layout.contentHeight > layout.popoverHeight)
        XCTAssertLessThanOrEqual(layout.popoverHeight, PopoverStackLayout.maxVisibleHeight)
        XCTAssertEqual(layout.notifSetup!.height, PopoverStackLayout.loginCardHeight)
        XCTAssertEqual(
            layout.notifEnable!.height,
            PopoverStackLayout.inset
                + PopoverStackLayout.titleRowHeight
                + PopoverCopyLayout.notifEnableHelpHeightPoints
                + PopoverStackLayout.switchRowHeight
                + PopoverStackLayout.inset
        )
        XCTAssertEqual(
            layout.notifDiscord!.height,
            PopoverStackLayout.inset
                + PopoverStackLayout.titleRowHeight
                + CopyWrap.lineCount(
                    AgrypnosCopy.notifDiscordHelp,
                    columns: PopoverCopyLayout.innerColumns
                ) * PopoverCopyLayout.lineHeightPoints
                + 3 * PopoverStackLayout.secretFieldRowHeight
                + PopoverStackLayout.switchRowHeight
                + PopoverStackLayout.inset
        )
        XCTAssertEqual(
            layout.notifTelegram!.height,
            PopoverStackLayout.inset
                + PopoverStackLayout.titleRowHeight
                + PopoverCopyLayout.notifTelegramHelpHeightPoints
                + 3 * PopoverStackLayout.secretFieldRowHeight
                + PopoverStackLayout.switchRowHeight
                + PopoverStackLayout.inset
        )
        XCTAssertEqual(layout.notifClear!.height, PopoverStackLayout.loginCardHeight)
    }

    private func compactYs(_ slots: PopoverSlot?...) -> [Int] {
        slots.compactMap { $0?.y }
    }

    private func isReadmeOnly(_ help: String) -> Bool {
        let lower = help.lowercased()
        let hasSteps = lower.contains("server settings") && lower.contains("botfather")
        return lower.contains("readme") && !hasSteps
    }
}
