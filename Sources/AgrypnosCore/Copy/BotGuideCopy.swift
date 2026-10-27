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

public enum BotGuideTab: CaseIterable, Equatable, Sendable {
    case telegram
    case discord
    case openCode
    case claudeCode
    case codex
    case cursor

    public var title: String {
        switch self {
        case .telegram: return "Telegram"
        case .discord: return "Discord"
        case .openCode: return "OpenCode"
        case .claudeCode: return "Claude Code"
        case .codex: return "Codex"
        case .cursor: return "Cursor"
        }
    }
}

public enum BotGuideFamily: Equatable, Sendable {
    case bots
    case tools

    public var windowTitle: String {
        switch self {
        case .bots: return BotGuide.windowTitle
        case .tools: return BotGuide.toolWindowTitle
        }
    }

    public var tabs: [BotGuideTab] {
        switch self {
        case .bots: return [.telegram, .discord]
        case .tools: return [.openCode, .claudeCode, .codex, .cursor]
        }
    }
}

/// Read-only Bot setup window copy (Notif → Setup instructions…).
public enum BotGuide {
    public static let windowTitle = "Bot setup"
    public static let toolWindowTitle = "Question setup"
    public static let windowWidth = 520
    public static let tabMargin = 16

    public static func sections(for tab: BotGuideTab) -> [BotGuideSection] {
        switch tab {
        case .telegram: return [telegramSetup, telegramTurnOn, commands(asleep: telegramAsleep), turnOff]
        case .discord: return [discordBot, commands(asleep: discordAsleep), turnOff]
        case .openCode: return questionGuide("OpenCode", [
            savedBot,
            BotGuideStep("Enable OpenCode forwarding",
                "Open Notif → Question notifications, then click Enable OpenCode forwarding. Agrypnos installs and registers its global terminal plugin. Restart OpenCode once to load forwarding, then use your normal chats. No port or project-directory setup is needed. Free text and approvals stay on the Mac.",
                link: BotGuideLink(title: "OpenCode plugins", url: "https://opencode.ai/docs/plugins/")),
            answerOnBot,
            disableOpenCode,
            watchAndExpiry,
        ])
        case .claudeCode: return questionGuide("Claude Code", [
            savedBot,
            BotGuideStep("Enable Claude Code forwarding",
                "Open Notif → Question notifications, then click Enable Claude Code forwarding. Agrypnos merges a PreToolUse AskUserQuestion hook into ~/.claude/settings.json and keeps your other hooks, including UserPromptSubmit / Stop / StopFailure. Interactive sessions hold hooks until you trust the folder. Ask a structured choice in that same Claude Code session and answer on your bot. This path is not Mac-proven yet."),
            answerOnBot,
            watchAndExpiry,
        ])
        case .codex: return questionGuide("Codex", [
            savedBot,
            BotGuideStep("Enable Codex alerts",
                "Open Notif → Question notifications, then click Enable Codex alerts. Agrypnos adds a hook to ~/.codex/hooks.json and keeps your other hooks. There is no codex hooks shell command, and the ChatGPT app has no documented trust screen. Until Codex runs the hook, no alert is sent. The alert says Codex is waiting on you, or waiting for an approval. It does not answer the question."),
        ])
        case .cursor: return toolNote(
            "Cursor",
            "Cursor cannot forward a question or send a waiting alert. The question stays in Cursor. There is no setup."
        )
        }
    }

    static func toolNote(_ title: String, _ body: String) -> [BotGuideSection] {
        [BotGuideSection(title: title, note: nil, numbered: false, steps: [
            BotGuideStep("Setup", body),
        ])]
    }

    static func questionGuide(_ title: String, _ steps: [BotGuideStep]) -> [BotGuideSection] {
        [BotGuideSection(title: title, note: nil, numbered: true, steps: steps)]
    }

    static let savedBot = BotGuideStep(
        "Use the bot you already saved",
        "Turn on Telegram or Discord inbound in Notif and save the bot token and chat or channel id. Question forwarding uses that bot. The switch stays off until one of those is saved."
    )

    static let answerOnBot = BotGuideStep(
        "Answer a new question",
        "Check for a connected terminal count. Start a new structured choice question in that same chat. Select every answer on your bot, review, then Send answers. Answer on Mac leaves it local without rejecting the question."
    )

    static let disableOpenCode = BotGuideStep(
        "Disable or remove",
        "Disable OpenCode forwarding keeps the plugin installed but inactive. Remove OpenCode integration removes only unchanged Agrypnos-owned files and its registration."
    )

    static let watchAndExpiry = BotGuideStep(
        "Keep awake and expiry",
        "Forwarding never arms Keep awake. While already armed, a question holds it for up to 10 minutes; other busy or unknown agent activity delays auto-off. Manual off and safety still win. App restart and sleep invalidate phone controls and leave existing pending questions local; new questions can forward when connected again. Screen lock alone does not cancel forwarding."
    )

    static let telegramAsleep = "If the bot isn’t replying, the Mac is likely asleep / Agrypnos isn’t polling."
    static let discordAsleep = "If the bot isn’t replying, the Mac is likely asleep / Agrypnos isn’t receiving updates."

    static let idleAfterWait =
        "Arm Keep awake with How long set to Agents and run an agent so Agrypnos sees a local busy signal. When the wait after agent signals stop ends, expect one message. Then Keep awake turns off."

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
                "Get a message when Keep awake turns off",
                "Switch on Watch-end POST. Agrypnos messages your Telegram bot when the timer ends or the wait after agent signals stop ends."
            ),
            BotGuideStep(
                "Send commands from Telegram",
                "Switch on the Telegram card. Commands turn on with it. It is separate from the POST switch. Only the chat id you saved can send commands."
            ),
            BotGuideStep("Test it", idleAfterWait),
        ]
    )

    static let discordBot = BotGuideSection(
        title: "Create your Discord bot",
        note: "You own this bot. Agrypnos does not run a shared bot. The same bot messages this channel and receives commands.",
        numbered: true,
        steps: [
            BotGuideStep(
                "Create an application",
                "Open the Discord Developer Portal → New Application → name it → Create.",
                link: BotGuideLink(title: "Open Developer Portal", url: "https://discord.com/developers/applications")
            ),
            BotGuideStep(
                "Copy the bot token",
                "Go to Bot → Reset Token and copy it. Paste it into Notif → Discord → Token. Treat it like a password.",
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
                "Right-click the channel the bot should listen in → Copy Channel ID. Paste it into Notif → Discord → Channel. Only that channel can send commands, so anyone who can post there can use them.",
                image: "guide-discord-copy-channel-id"
            ),
            BotGuideStep(
                "Old webhook URL",
                "An old webhook URL is unused. Paste the bot token and channel id."
            ),
            BotGuideStep(
                "Get a message when Keep awake turns off",
                "Switch on Watch-end POST. Agrypnos messages this channel when the timer ends, when the wait after agent signals stop ends, or when it asks the Mac to sleep."
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
                BotGuideStep("/arm", "Turns Keep awake on."),
                BotGuideStep(
                    "/disarm",
                    "Turns Keep awake off. With the lid open it does not sleep the Mac. With the lid confirmed closed it turns Keep awake off and sends the Mac to sleep."
                ),
                BotGuideStep(
                    "/status",
                    "Returns Keep awake, How long, lid, Agents facts when relevant, the last time Keep awake turned off, and safety prefs. Includes live battery when known, like Battery 62% · on AC."
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
                "Switch the toggles off in Notif to stop. Clear secrets deletes the saved tokens and ids from this Mac."
            ),
        ]
    )
}
