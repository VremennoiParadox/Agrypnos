public enum NotifDiscordFieldCommit: Equatable, Sendable {
    case persist(String)
    case clear
    case reject
}

public enum NotifDiscordFieldChrome: Sendable {
    public static func commit(_ raw: String) -> NotifDiscordFieldCommit {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return .clear }
        guard DiscordWebhookURL.parse(trimmed) != nil else { return .reject }
        return .persist(trimmed)
    }
}

public enum NotifOptionalSecretChrome: Sendable {
    public static func commit(_ raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

public enum NotifEnableChrome: Sendable {
    public static var defaultEnabled: Bool { UserPreferences.default.notifEnabled }
}

public enum NotifClearChrome: Sendable {
    public static let deletedAccounts = [
        "discordWebhookURL",
        "telegramBotToken",
        "telegramChatId",
    ]
}
