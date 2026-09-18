import XCTest
@testable import AgrypnosCore

final class NotifPopoverChromeTests: XCTestCase {
    func testNotifSectionCardsAreEnableDiscordTelegramSetupAndClear() {
        XCTAssertEqual(
            PopoverSection.notif.cards,
            [.notifEnable, .notifDiscord, .notifTelegram, .notifSetup, .notifClear]
        )
        XCTAssertFalse(PopoverSection.notif.cards.isEmpty)
        XCTAssertEqual(PopoverSection.notif.cards.first, .notifEnable)
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

    func testDiscordCommitPersistsValidURLClearsEmptyAndRejectsJunk() {
        XCTAssertEqual(
            NotifDiscordFieldChrome.commit("https://discord.com/api/webhooks/1/abc"),
            .persist("https://discord.com/api/webhooks/1/abc")
        )
        XCTAssertEqual(
            NotifDiscordFieldChrome.commit("  https://discord.com/api/webhooks/99/Tok.en-1_2  "),
            .persist("https://discord.com/api/webhooks/99/Tok.en-1_2")
        )
        XCTAssertEqual(
            NotifDiscordFieldChrome.commit("<https://discord.com/api/webhooks/1/abc>"),
            .persist("https://discord.com/api/webhooks/1/abc")
        )
        XCTAssertEqual(NotifDiscordFieldChrome.commit(""), .clear)
        XCTAssertEqual(NotifDiscordFieldChrome.commit("   "), .clear)
        XCTAssertEqual(NotifDiscordFieldChrome.commit("https://example.com/api/webhooks/1/abc"), .reject)
        XCTAssertEqual(NotifDiscordFieldChrome.commit("http://discord.com/api/webhooks/1/abc"), .reject)
        XCTAssertEqual(NotifDiscordFieldChrome.commit("https://httpbin.org/post"), .reject)
        XCTAssertEqual(NotifDiscordFieldChrome.commit("not a url"), .reject)
        if case .reject = NotifDiscordFieldChrome.commit("https://evil.com/api/webhooks/1/abc") {
            // associated value must not carry the secret-shaped junk for logs
        } else {
            XCTFail("invalid Discord URL must reject without saving")
        }
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
        let needed = AgrypnosCopy.notifTelegramChatShort.count * 9 + 8
        XCTAssertGreaterThanOrEqual(PopoverCopyLayout.secretFieldLabelWidthPoints, needed)
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
            AgrypnosCopy.revealAccess(label: AgrypnosCopy.notifDiscord, revealed: false),
            "Show Discord webhook URL"
        )
        XCTAssertEqual(
            AgrypnosCopy.revealAccess(label: AgrypnosCopy.notifDiscord, revealed: true),
            "Hide Discord webhook URL"
        )
        XCTAssertNotEqual(
            AgrypnosCopy.revealAccess(label: AgrypnosCopy.notifTelegramToken, revealed: false),
            AgrypnosCopy.revealAccess(label: AgrypnosCopy.notifTelegramChatId, revealed: false)
        )
    }

    func testTelegramHelpAndPlaceholdersSayWhereChatIdComesFrom() {
        let help = AgrypnosCopy.notifTelegramHelp.lowercased()
        XCTAssertTrue(help.contains("your telegram bot"))
        XCTAssertTrue(help.contains("does not run a shared bot"))
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
        XCTAssertEqual(AgrypnosCopy.notifDiscordPlaceholder, "paste webhook URL")
        XCTAssertFalse(AgrypnosCopy.notifTelegramChatPlaceholder.contains("123456"))
        XCTAssertFalse(AgrypnosCopy.notifDiscordPlaceholder.contains("discord.com/api/webhooks/"))
    }

    func testClearSecretsCopyDeletesSavedFileNotKeychain() {
        XCTAssertEqual(AgrypnosCopy.notifClear, "Clear secrets")
        XCTAssertTrue(AgrypnosCopy.notifSetupHelp.lowercased().contains("clear secrets"))
        XCTAssertFalse(AgrypnosCopy.notifSetupHelp.lowercased().contains("keychain"))
        XCTAssertEqual(NotifSecretsFileChrome.folderName, "Agrypnos")
        XCTAssertEqual(NotifSecretsFileChrome.fileName, "notif-secrets.json")
        XCTAssertFalse(NotifSecretsFileChrome.fileName.contains("preferences"))
        XCTAssertNil(NotifOptionalSecretChrome.commit(""))
        XCTAssertEqual(NotifDiscordFieldChrome.commit(""), .clear)
    }

    func testSecretsPayloadRoundTripsAndOmitsEmptyFields() throws {
        let data = try XCTUnwrap(
            NotifSecretsPayload.encode(
                discordWebhookURL: "https://discord.com/api/webhooks/1/abc",
                telegramBotToken: "111:token",
                telegramChatId: "5728126329"
            )
        )
        let decoded = try XCTUnwrap(NotifSecretsPayload.decode(data))
        XCTAssertEqual(decoded.discordWebhookURL, "https://discord.com/api/webhooks/1/abc")
        XCTAssertEqual(decoded.telegramBotToken, "111:token")
        XCTAssertEqual(decoded.telegramChatId, "5728126329")
        let empty = try XCTUnwrap(NotifSecretsPayload.encode(
            discordWebhookURL: "  ",
            telegramBotToken: nil,
            telegramChatId: ""
        ))
        let emptyDecoded = try XCTUnwrap(NotifSecretsPayload.decode(empty))
        XCTAssertNil(emptyDecoded.discordWebhookURL)
        XCTAssertNil(emptyDecoded.telegramBotToken)
        XCTAssertNil(emptyDecoded.telegramChatId)
    }

    func testSetupHelpFitsItsSlotAndIsSelfServe() {
        let help = AgrypnosCopy.notifSetupHelp
        let lines = CopyWrap.lineCount(help, columns: PopoverCopyLayout.innerColumns)
        XCTAssertEqual(PopoverCopyLayout.helpMaxLines, 2)
        XCTAssertGreaterThan(lines, PopoverCopyLayout.helpMaxLines)
        XCTAssertEqual(lines, 17)
        XCTAssertEqual(PopoverCopyLayout.notifSetupHelpMaxLines, 17)
        XCTAssertEqual(
            PopoverCopyLayout.notifSetupHelpHeightPoints,
            17 * PopoverCopyLayout.lineHeightPoints
        )
        XCTAssertGreaterThanOrEqual(
            PopoverCopyLayout.notifSetupHelpMaxLines,
            lines
        )

        let lower = help.lowercased()
        XCTAssertTrue(help.contains("Server Settings"))
        XCTAssertTrue(help.contains("Integrations"))
        XCTAssertTrue(help.contains("Webhooks"))
        XCTAssertTrue(help.contains("New Webhook"))
        XCTAssertTrue(help.contains("@BotFather"))
        XCTAssertTrue(help.contains("/newbot"))
        XCTAssertTrue(help.contains("getUpdates"))
        XCTAssertTrue(help.contains("YOUR_TOKEN"))
        XCTAssertTrue(lower.contains("empty result"))
        XCTAssertTrue(lower.contains("arm") && help.contains("Agents"))
        XCTAssertTrue(lower.contains("local busy"))
        XCTAssertTrue(lower.contains("idle wait") || lower.contains("idle after wait"))
        XCTAssertTrue(lower.contains("one post") || lower.contains("one POST"))
        XCTAssertTrue(lower.contains("your webhook") || help.contains("your webhook"))
        XCTAssertTrue(lower.contains("telegram"))
        XCTAssertTrue(lower.contains("clear secrets"))
        XCTAssertFalse(lower.contains("see readme") && !help.contains("Server Settings"))
        XCTAssertFalse(isReadmeOnly(help))
    }

    func testEnableAndTelegramHelpFitTallerSlots() {
        XCTAssertEqual(
            CopyWrap.lineCount(
                AgrypnosCopy.notifEnabledHelp,
                columns: PopoverCopyLayout.innerColumns
            ),
            4
        )
        XCTAssertEqual(PopoverCopyLayout.notifEnableHelpMaxLines, 4)
        XCTAssertEqual(
            CopyWrap.lineCount(
                AgrypnosCopy.notifTelegramHelp,
                columns: PopoverCopyLayout.innerColumns
            ),
            3
        )
        XCTAssertEqual(PopoverCopyLayout.notifTelegramHelpMaxLines, 3)
        XCTAssertEqual(
            CopyWrap.lineCount(
                AgrypnosCopy.notifDiscordInvalid,
                columns: PopoverCopyLayout.innerColumns
            ),
            2
        )
        XCTAssertEqual(PopoverCopyLayout.notifDiscordStatusMaxLines, 2)
        XCTAssertLessThanOrEqual(
            CopyWrap.lineCount(
                AgrypnosCopy.notifDiscordHelp,
                columns: PopoverCopyLayout.innerColumns
            ),
            PopoverCopyLayout.helpMaxLines
        )
    }

    func testNotifCopyStaysIdleAfterWaitAndNamesYourWebhook() {
        XCTAssertEqual(
            AgrypnosCopy.notifDiscordInvalid,
            "That is not a Discord webhook URL. Nothing was saved."
        )
        XCTAssertEqual(AgrypnosCopy.notifSetup, "Setup")
        let blob = [
            AgrypnosCopy.notifEnabled,
            AgrypnosCopy.notifEnabledHelp,
            AgrypnosCopy.notifDiscord,
            AgrypnosCopy.notifDiscordHelp,
            AgrypnosCopy.notifDiscordInvalid,
            AgrypnosCopy.notifTelegram,
            AgrypnosCopy.notifTelegramTokenShort,
            AgrypnosCopy.notifTelegramChatShort,
            AgrypnosCopy.notifTelegramToken,
            AgrypnosCopy.notifTelegramChatId,
            AgrypnosCopy.notifDiscordPlaceholder,
            AgrypnosCopy.notifTelegramTokenPlaceholder,
            AgrypnosCopy.notifTelegramChatPlaceholder,
            AgrypnosCopy.notifTelegramHelp,
            AgrypnosCopy.notifSetup,
            AgrypnosCopy.notifSetupHelp,
            AgrypnosCopy.notifClear,
            AgrypnosCopy.revealAccess(label: AgrypnosCopy.notifDiscord, revealed: false),
            AgrypnosCopy.revealAccess(label: AgrypnosCopy.notifTelegramToken, revealed: true),
            AgrypnosCopy.notifSaveFailed,
            AgrypnosCopy.notifDiscordPostFailed,
            AgrypnosCopy.notifTelegramPostFailed,
            AgrypnosCopy.notifTelegramChatInvalid,
            AgrypnosCopy.notifTelegramTokenInvalid,
            AgrypnosCopy.notifIdleBody,
        ].joined(separator: "\n").lowercased()
        XCTAssertTrue(blob.contains("your webhook"))
        XCTAssertTrue(blob.contains("your telegram bot"))
        XCTAssertTrue(blob.contains("does not run a shared bot"))
        XCTAssertTrue(blob.contains("idle after the wait") || blob.contains("idle after wait"))
        XCTAssertTrue(blob.contains("show discord webhook url"))
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

    func testNotifSectionStacksFiveCardsAndMayScroll() {
        let layout = PopoverStackLayout.make(section: .notif)
        XCTAssertEqual(layout.section, .notif)
        XCTAssertEqual(
            layout.stackedCards.map(\.y),
            compactYs(
                layout.notifEnable,
                layout.notifDiscord,
                layout.notifTelegram,
                layout.notifSetup,
                layout.notifClear
            )
        )
        XCTAssertEqual(layout.notifEnable?.y, PopoverStackLayout.firstCardY)
        XCTAssertEqual(layout.notifDiscord?.y, layout.notifEnable!.maxY + PopoverStackLayout.cardGap)
        XCTAssertEqual(layout.notifTelegram?.y, layout.notifDiscord!.maxY + PopoverStackLayout.cardGap)
        XCTAssertEqual(layout.notifSetup?.y, layout.notifTelegram!.maxY + PopoverStackLayout.cardGap)
        XCTAssertEqual(layout.notifClear?.y, layout.notifSetup!.maxY + PopoverStackLayout.cardGap)
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
        XCTAssertGreaterThan(
            layout.notifSetup!.height,
            PopoverStackLayout.titleRowHeight + PopoverCopyLayout.helpHeightPoints
        )
        XCTAssertEqual(
            layout.notifSetup!.height,
            PopoverStackLayout.inset
                + PopoverStackLayout.titleRowHeight
                + PopoverCopyLayout.notifSetupHelpHeightPoints
                + PopoverStackLayout.inset
        )
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
                + PopoverCopyLayout.helpHeightPoints
                + PopoverStackLayout.secretFieldRowHeight
                + PopoverCopyLayout.notifDiscordStatusHeightPoints
                + PopoverStackLayout.inset
        )
        XCTAssertEqual(
            layout.notifTelegram!.height,
            PopoverStackLayout.inset
                + PopoverStackLayout.titleRowHeight
                + PopoverCopyLayout.notifTelegramHelpHeightPoints
                + 2 * PopoverStackLayout.secretFieldRowHeight
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
