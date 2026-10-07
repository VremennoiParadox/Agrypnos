public enum QuestionSetupChrome {
    public static let disclosureTitle = "Question notifications"
    public static let beta = "BETA"
    public static let cursorNote = "Cursor cannot forward a question or send a waiting alert. The question stays in Cursor."
    public static let codexEnableTitle = "Enable Codex alerts"
    public static let codexHelp = "Adds a hook that tells your bot when Codex is waiting on you or waiting for an approval. It does not answer the question. There is no shell command to trust it. Not proven in the ChatGPT app yet."
    public static let codexTrustStatus = "Added the hook. Codex has to run it before an alert is sent. That step is not proven in the ChatGPT app yet."
    public static let title = "Forward agent questions"
    public static let help = "Structured OpenCode and Claude Code choices on your bot. Codex sends a waiting alert and does not answer. Cursor stays in Cursor. Free text and approvals stay on Mac."
    public static let policy = "While armed, questions hold the watch for 10 minutes. Busy or unknown activity delays auto-off. Forwarding never arms it."
    public static let helpY = 40
    public static let telegramUserY = 112
    public static let discordUserY = 140
    public static let policyY = 176
    public static let statusY = 248
    public static let statusHeight = 56
    public static let relayCardHeight = 316
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
