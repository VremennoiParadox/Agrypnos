import XCTest
@testable import AgrypnosCore

final class BotGuideCopyTests: XCTestCase {
    func testWindowChromeIsPlain() {
        XCTAssertEqual(BotGuide.windowTitle, "Bot setup")
        XCTAssertEqual(BotGuide.toolWindowTitle, "Question setup")
        XCTAssertEqual(BotGuideFamily.bots.windowTitle, "Bot setup")
        XCTAssertEqual(BotGuideFamily.tools.windowTitle, "Question setup")
        XCTAssertEqual(BotGuideTab.allCases, [.telegram, .discord, .openCode, .claudeCode, .codex, .cursor])
        XCTAssertEqual(BotGuideFamily.bots.tabs, [.telegram, .discord])
        XCTAssertEqual(BotGuideFamily.tools.tabs, [.openCode, .claudeCode, .codex, .cursor])
        XCTAssertEqual(BotGuideTab.telegram.title, "Telegram")
        XCTAssertEqual(BotGuideTab.discord.title, "Discord")
        XCTAssertEqual(BotGuideTab.openCode.title, "OpenCode")
        XCTAssertEqual(BotGuideTab.claudeCode.title, "Claude Code")
        XCTAssertEqual(BotGuideTab.codex.title, "Codex")
        XCTAssertEqual(BotGuideTab.cursor.title, "Cursor")
        XCTAssertEqual(AgrypnosCopy.notifSetup, "Setup instructions…")
        XCTAssertFalse(BotGuideFamily.bots.tabs.contains(.openCode))
        XCTAssertFalse(BotGuideFamily.bots.tabs.contains(.claudeCode))
        XCTAssertFalse(BotGuideFamily.bots.tabs.contains(.codex))
        XCTAssertFalse(BotGuideFamily.bots.tabs.contains(.cursor))
        XCTAssertFalse(BotGuideFamily.tools.tabs.contains(.telegram))
        XCTAssertFalse(BotGuideFamily.tools.tabs.contains(.discord))
        let tabBudget = BotGuide.windowWidth - 2 * BotGuide.tabMargin
        let estimated = BotGuideFamily.tools.tabs.reduce(0) { $0 + $1.title.count * 8 + 24 }
        XCTAssertLessThanOrEqual(estimated, tabBudget)
    }

    func testTelegramWalksBotFatherTokenChatIdAndInbound() {
        let text = BotGuide.text(for: .telegram)
        for needle in ["BotFather", "/newbot", "Token", "getUpdates", "\"chat\":{\"id\":", "Chat id", "Empty result", "Telegram inbound", "Idle-after-wait POST"] {
            XCTAssertTrue(text.contains(needle), "Telegram guide misses \(needle)")
        }
        let links = BotGuide.sections(for: .telegram).flatMap(\.steps).compactMap(\.link)
        XCTAssertTrue(links.contains(BotGuideLink(title: "Open BotFather", url: "https://t.me/BotFather")))
        XCTAssertFalse(text.lowercased().contains("webhook"))
    }

    func testDiscordKeepsWebhookOutboundOnlyAndBotSeparate() {
        let sections = BotGuide.sections(for: .discord)
        let webhook = try! XCTUnwrap(sections.first)
        let webhookText = ([webhook.title, webhook.note ?? ""] + webhook.steps.map { $0.title + " " + $0.body })
            .joined(separator: "\n")
        XCTAssertTrue(webhookText.contains("Server Settings → Integrations → Webhooks → New Webhook"))
        XCTAssertTrue(webhookText.contains("Copy Webhook URL"))
        XCTAssertTrue(webhookText.lowercased().contains("does not receive commands"))
        XCTAssertFalse(webhookText.contains("/arm"))

        let text = BotGuide.text(for: .discord)
        for needle in ["Developer Portal", "New Application", "Reset Token", "applications.commands", "Send Messages", "Developer Mode", "Copy Channel ID", "Discord inbound"] {
            XCTAssertTrue(text.contains(needle), "Discord guide misses \(needle)")
        }
        XCTAssertTrue(text.contains("`bot`") || text.contains("bot and applications.commands"))
        XCTAssertTrue(text.lowercased().contains("never paste it into the webhook field"))
        let links = sections.flatMap(\.steps).compactMap(\.link)
        XCTAssertTrue(links.contains(
            BotGuideLink(title: "Open Developer Portal", url: "https://discord.com/developers/applications")
        ))
    }

    func testCommandsCoverLidGatedDisarmAsleepMissedAndBattery() {
        for tab in [BotGuideTab.telegram, .discord] {
            let text = BotGuide.text(for: tab)
            let lower = text.lowercased()
            for command in ["/arm", "/disarm", "/status", "/help"] {
                XCTAssertTrue(text.contains(command), "\(tab) guide misses \(command)")
            }
            XCTAssertTrue(lower.contains("with the lid open it does not sleep the mac"))
            XCTAssertTrue(lower.contains("with the lid confirmed closed it turns keep the watch off and sends the mac to sleep"))
            XCTAssertTrue(lower.contains("likely asleep"))
            XCTAssertTrue(text.contains("Missed while asleep."))
            XCTAssertTrue(lower.contains("not run later"))
            XCTAssertTrue(lower.contains("live battery when known"))
            XCTAssertTrue(text.contains(
                "Keep the watch, How long, lid, Agents facts when relevant, last watch end, and safety prefs"
            ))
            XCTAssertTrue(lower.contains("clear secrets"))
            XCTAssertTrue(lower.contains("idle through the wait"))
        }
        XCTAssertTrue(BotGuide.text(for: .telegram).contains("isn’t polling"))
        let discord = BotGuide.text(for: .discord).lowercased()
        XCTAssertTrue(discord.contains("isn’t receiving updates"))
        XCTAssertFalse(discord.contains("polling"))
    }

    func testGuideBansFictionAndCarriesNoSecrets() {
        let blob = BotGuide.allText.lowercased()
        for banned in [
            "we notify your phone",
            "notify your phone",
            "agent stopped",
            "job finished",
            "still thinking",
            "agent finished",
            "finish eta",
            "task text",
            "remaining",
            "remote control",
            "shared agrypnos bot",
            "disarm always sleeps",
            "the mac is asleep.",
            "listen port",
            "interactions endpoint",
            "keychain",
            "time-to-empty",
            "warranty",
        ] {
            XCTAssertFalse(blob.contains(banned), "banned phrase in bot guide: \(banned)")
        }
        XCTAssertTrue(blob.contains("does not run a shared bot"))
        XCTAssertFalse(BotGuide.allText.contains("discord.com/api/webhooks/"))
        XCTAssertNil(BotGuide.allText.range(of: #"\d{6,}:[A-Za-z0-9_-]{20,}"#, options: .regularExpression))
        for tab in [BotGuideTab.telegram, .discord] {
            let lower = BotGuide.text(for: tab).lowercased()
            XCTAssertFalse(lower.contains("mac-proven"), "\(tab) must not claim Mac-proven")
            XCTAssertFalse(lower.contains("mac proven"), "\(tab) must not claim Mac proven")
        }
        XCTAssertTrue(BotGuide.text(for: .claudeCode).contains("not Mac-proven yet"))
    }

    func testEveryStepIsFilledAndImagesAndLinksAreWellFormed() {
        var images: [String] = []
        for tab in BotGuideTab.allCases {
            let sections = BotGuide.sections(for: tab)
            let minimum = (tab == .telegram || tab == .discord) ? 3 : 1
            XCTAssertGreaterThanOrEqual(sections.count, minimum)
            for section in sections {
                XCTAssertFalse(section.title.isEmpty)
                XCTAssertFalse(section.steps.isEmpty)
                for step in section.steps {
                    XCTAssertFalse(step.title.isEmpty)
                    XCTAssertFalse(step.body.isEmpty)
                    if let image = step.image {
                        XCTAssertTrue(image.hasPrefix("guide-"), image)
                        images.append(image)
                    }
                    if let link = step.link {
                        XCTAssertTrue(link.url.hasPrefix("https://"), link.url)
                    }
                }
            }
        }
        XCTAssertEqual(images.count, Set(images).count)
        XCTAssertEqual(
            Set(images),
            [
                "guide-telegram-botfather",
                "guide-telegram-getupdates",
                "guide-discord-webhook-integrations",
                "guide-discord-webhook-copy",
                "guide-discord-bot-reset-token",
                "guide-discord-oauth-url",
                "guide-discord-developer-mode",
                "guide-discord-copy-channel-id",
            ]
        )
    }

    func testClaudeHookSetupNamesTrustAndKeepsBrainrotHonesty() {
        let text = BotGuide.allText
        XCTAssertTrue(text.contains("Enable Claude Code forwarding"))
        XCTAssertTrue(text.lowercased().contains("trust the folder"))
        XCTAssertTrue(text.contains("PreToolUse"))
        XCTAssertTrue(text.contains("AskUserQuestion"))
        XCTAssertTrue(text.contains("UserPromptSubmit"))
        XCTAssertTrue(text.contains("brainrot") || text.contains("other hooks"))
        XCTAssertTrue(text.contains("Enable OpenCode forwarding"))
        XCTAssertTrue(text.contains("Question notifications"))
        XCTAssertTrue(text.contains("Enable Codex alerts"))
        XCTAssertFalse(text.contains("Agents → Which tools count as busy → Forward agent questions"))
        XCTAssertFalse(text.contains("Notif does not have those cards."))
        XCTAssertFalse(text.contains("Codex question forwarding is not there."))
        XCTAssertFalse(text.contains("Notif → Forward agent questions"))
    }

    func testToolTabsAreInstructionsOnly() {
        for tab in [BotGuideTab.openCode, .claudeCode, .codex, .cursor] {
            let text = BotGuide.text(for: tab)
            XCTAssertFalse(text.isEmpty)
            XCTAssertFalse(text.localizedCaseInsensitiveContains("agent stopped"))
            XCTAssertFalse(text.localizedCaseInsensitiveContains("job finished"))
        }
        XCTAssertTrue(BotGuide.text(for: .cursor).contains("Cursor cannot forward a question"))
        XCTAssertTrue(BotGuide.text(for: .codex).contains("does not answer"))
        XCTAssertTrue(BotGuide.text(for: .codex).contains("no codex hooks shell command"))
        XCTAssertFalse(BotGuide.text(for: .codex).contains("run /hooks"))
        XCTAssertTrue(BotGuide.text(for: .codex).contains("does not answer"))
        XCTAssertTrue(BotGuide.text(for: .openCode).contains("Restart OpenCode once"))
        XCTAssertTrue(BotGuide.text(for: .claudeCode).contains("AskUserQuestion"))
    }
}

extension BotGuide {
    static func text(for tab: BotGuideTab) -> String {
        sections(for: tab).map { section in
            ([section.title, section.note ?? ""]
                + section.steps.map { [$0.title, $0.body, $0.link?.title ?? ""].joined(separator: " ") })
                .joined(separator: "\n")
        }.joined(separator: "\n")
    }

    static var allText: String {
        BotGuideTab.allCases.map { text(for: $0) }.joined(separator: "\n")
    }
}
