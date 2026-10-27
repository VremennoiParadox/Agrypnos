public enum QuestionSetupChrome {
    public static let disclosureTitle = "Question notifications"
    public static let beta = "BETA"
    public static let cursorNote = "Cursor cannot forward a question or send a waiting alert. The question stays in Cursor."
    public static let codexEnableTitle = "Enable Codex alerts"
    public static let codexHelp = "Adds a hook that tells your bot when Codex is waiting on you or waiting for an approval. It does not answer the question. There is no shell command to trust it."
    public static let codexTrustStatus = "Added the hook. Codex has to run it before an alert is sent."
    public static let title = "Forward agent questions"
    public static let needsBot = "You must have a Discord or Telegram bot configured to activate this feature."
    public static let help = "Full question forwarding with answering through the bot for OpenCode and Claude Code. Codex only pings you through the bot. It does not forward or answer. Cursor is unavailable because it does not have the signals this needs."
    public static let policy = "After a question is recognized, Agrypnos waits 10 minutes for an answer. If none comes, and Keep awake is already on, Keep awake turns off. The Mac is asked to sleep only when the lid is confirmed closed. A busy agent delays that. " + needsBot
    public static let helpY = 40
    public static var helpMaxLines: Int {
        max(CopyWrap.lineCount(help, columns: PopoverCopyLayout.innerColumns), 1)
    }
    public static var policyMaxLines: Int {
        max(CopyWrap.lineCount(policy, columns: PopoverCopyLayout.innerColumns), 1)
    }
    public static var policyY: Int { helpY + helpMaxLines * PopoverCopyLayout.lineHeightPoints + 8 }
    public static let statusHeight = 56
    public static var statusY: Int { policyY + policyMaxLines * PopoverCopyLayout.lineHeightPoints + 8 }
    public static var relayCardHeight: Int { statusY + statusHeight + 12 }
    public static let pluginCardHeight = 156
    public static let claudeEnableTitle = "Enable Claude Code forwarding"
    public static let claudeHelp = "Adds a PreToolUse AskUserQuestion hook to your Claude settings. Interactive sessions hold hooks until you trust the folder."
    public static let claudeStatusY = 144
    public static let claudeCardHeight = claudeStatusY + 32 + 12
    public static let hookHelpY = 36
    public static let hookButtonRowHeight = 28
    public static let hookStatusHeight = 32
    public static var codexHelpMaxLines: Int {
        max(CopyWrap.lineCount(codexHelp, columns: PopoverCopyLayout.innerColumns), 1)
    }
    public static var codexHelpHeight: Int { codexHelpMaxLines * PopoverCopyLayout.lineHeightPoints }
    public static var codexEnableY: Int { hookHelpY + codexHelpHeight }
    public static var codexDisableY: Int { codexEnableY + hookButtonRowHeight }
    public static var codexStatusY: Int { codexDisableY + hookButtonRowHeight }
    public static var codexCardHeight: Int { codexStatusY + hookStatusHeight + 12 }
    public static var cursorNoteMaxLines: Int {
        max(CopyWrap.lineCount(cursorNote, columns: PopoverCopyLayout.innerColumns), 1)
    }
    public static var cursorNoteCardHeight: Int {
        12 + cursorNoteMaxLines * PopoverCopyLayout.lineHeightPoints + 12
    }
    public static let enableTitle = "Enable OpenCode forwarding"
    public static let pluginHelp = "One-time setup for OpenCode 1.18.32 terminals. Restart OpenCode once, then use your normal chats."
}
