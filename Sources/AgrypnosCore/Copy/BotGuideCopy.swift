public struct BotGuideLink: Equatable, Sendable {
    public let title: String
    public let url: String
}

public struct BotGuideStep: Equatable, Sendable {
    public let title: String
    public let body: String
    /// Asset catalog name. A missing asset renders the step as text only.
    public let image: String?
    public let link: BotGuideLink?

    init(_ title: String, _ body: String, image: String? = nil, link: BotGuideLink? = nil) {
        self.title = title
        self.body = body
        self.image = image
        self.link = link
    }
}

public struct BotGuideSection: Equatable, Sendable {
    public let title: String
    public let note: String?
    /// Setup steps are numbered; the command list is not.
    public let numbered: Bool
    public let steps: [BotGuideStep]
}

public enum BotGuideTab: CaseIterable, Sendable {
    case telegram
    case discord

    public var title: String {
        switch self {
        case .telegram: return "Telegram"
        case .discord: return "Discord"
        }
    }
}

/// Read-only Bot setup window copy (Notif → Setup instructions…).
public enum BotGuide {
    public static let windowTitle = "Bot setup"

    public static func sections(for tab: BotGuideTab) -> [BotGuideSection] {
        switch tab {
        case .telegram: return [telegramSetup, telegramTurnOn, commands(asleep: telegramAsleep), turnOff]
        case .discord: return [discordWebhook, discordBot, commands(asleep: discordAsleep), turnOff]
        }
    }

    static let telegramAsleep = "If the bot isn’t replying, the Mac is likely asleep / Agrypnos isn’t polling."
    static let discordAsleep = "If the bot isn’t replying, the Mac is likely asleep / Agrypnos isn’t receiving updates."

    static let idleAfterWait =
        "Arm Keep the watch with How long set to Agents and run an agent so Agrypnos sees a local busy signal. When those signals stay idle through the wait (the idle wait in Agents), expect one message. Then Keep the watch turns off."

    static let telegramSetup = BotGuideSection(
        title: "Create your Telegram bot",
        note: "You own the bot. Agrypnos does not run a shared bot.",
        numbered: true,
        steps: [
            BotGuideStep(
                "Open BotFather",
                "BotFather is Telegram’s bot for making bots. Send it /newbot, then pick a display name and a username that ends in “bot”.",
                image: "guide-telegram-botfather",
                link: BotGuideLink(title: "Open BotFather", url: "https://t.me/BotFather")
            ),
            BotGuideStep(
                "Copy the token",
                "BotFather replies with a bot token. Paste it into Notif → Telegram → Token. Treat it like a password."
            ),
            BotGuideStep(
                "Message your bot once",
                "Open your new bot and tap Start (or send any message). Telegram only shows your chat id after you message the bot."
            ),
            BotGuideStep(
                "Find your chat id",
                "In a browser, open api.telegram.org/bot<token>/getUpdates with your token in place of <token>. Find \"chat\":{\"id\": and copy the number after it. Empty result? Message the bot again, then reload. Close the tab when done — the token stays in its history.",
                image: "guide-telegram-getupdates"
            ),
            BotGuideStep(
                "Paste the chat id",
                "Paste that number into Notif → Telegram → Chat id."
            ),
        ]
    )

    static let telegramTurnOn = BotGuideSection(
        title: "Turn it on",
        note: nil,
        numbered: true,
        steps: [
            BotGuideStep(
                "Get a message when the watch ends",
                "Switch on Watch-end POST. Agrypnos messages your Telegram bot when the timer ends or Agents stay idle through the wait."
            ),
            BotGuideStep(
                "Send commands from Telegram",
                "Switch on Telegram inbound. It is separate from the POST switch. Only the chat id you saved can send commands."
            ),
            BotGuideStep("Test it", idleAfterWait),
        ]
    )

    static let discordWebhook = BotGuideSection(
        title: "Messages to you (webhook)",
        note: "The webhook only posts to your channel. It does not receive commands.",
        numbered: true,
        steps: [
            BotGuideStep(
                "Create a webhook",
                "In your Discord server: Server Settings → Integrations → Webhooks → New Webhook. You need permission to manage webhooks.",
                image: "guide-discord-webhook-integrations"
            ),
            BotGuideStep(
                "Copy the URL",
                "Name it, pick the channel, then Copy Webhook URL. Paste it into Notif → Discord webhook URL. It is a secret — don’t share it.",
                image: "guide-discord-webhook-copy"
            ),
            BotGuideStep(
                "Turn it on",
                "Switch on Watch-end POST. Agrypnos posts to your webhook when the timer ends or Agents stay idle through the wait."
            ),
            BotGuideStep("Test it", idleAfterWait),
        ]
    )

    static let discordBot = BotGuideSection(
        title: "Commands (your bot)",
        note: "A separate bot, not the webhook. You own it. Agrypnos does not run a shared bot.",
        numbered: true,
        steps: [
            BotGuideStep(
                "Create an application",
                "Open the Discord Developer Portal → New Application → name it → Create.",
                link: BotGuideLink(title: "Open Developer Portal", url: "https://discord.com/developers/applications")
            ),
            BotGuideStep(
                "Copy the bot token",
                "Go to Bot → Reset Token and copy it. Paste it into Notif → Discord inbound → Token. Treat it like a password and never paste it into the webhook field.",
                image: "guide-discord-bot-reset-token"
            ),
            BotGuideStep(
                "Invite the bot to your server",
                "Go to OAuth2 → URL Generator. Tick the scopes bot and applications.commands, then the Send Messages permission. Open the generated URL, pick your server, and authorize.",
                image: "guide-discord-oauth-url"
            ),
            BotGuideStep(
                "Turn on Developer Mode",
                "In Discord: User Settings → Advanced → Developer Mode. This lets you copy ids.",
                image: "guide-discord-developer-mode"
            ),
            BotGuideStep(
                "Copy the channel id",
                "Right-click the channel the bot should listen in → Copy Channel ID. Paste it into Notif → Discord inbound → Channel. Only that channel can send commands, so anyone who can post there can use them.",
                image: "guide-discord-copy-channel-id"
            ),
            BotGuideStep(
                "Turn inbound on",
                "Switch on Discord inbound. Agrypnos adds /arm, /disarm, /status, and /help to your bot’s / menu. Type /help in that channel to check."
            ),
        ]
    )

    static func commands(asleep: String) -> BotGuideSection {
        BotGuideSection(
            title: "Commands",
            note: nil,
            numbered: false,
            steps: [
                BotGuideStep("/arm", "Turns Keep the watch on."),
                BotGuideStep(
                    "/disarm",
                    "Turns Keep the watch off. With the lid open it does not sleep the Mac. With the lid confirmed closed it turns Keep the watch off and sends the Mac to sleep."
                ),
                BotGuideStep(
                    "/status",
                    "Returns Keep the watch, How long, lid, Agents facts when relevant, last watch end, and safety prefs. Includes live battery when known, like Battery 62% · on AC."
                ),
                BotGuideStep("/help", "Lists these commands."),
                BotGuideStep(
                    "Bot not replying?",
                    "\(asleep) Commands sent while the Mac slept are not run later. On wake the bot replies “Missed while asleep.”"
                ),
            ]
        )
    }

    static let turnOff = BotGuideSection(
        title: "Turn off",
        note: nil,
        numbered: false,
        steps: [
            BotGuideStep(
                "Stop or remove",
                "Switch the toggles off in Notif to stop. Clear secrets deletes the saved tokens, URL, and ids from this Mac."
            ),
        ]
    )
}
