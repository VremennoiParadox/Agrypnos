public enum NotifChannel: Equatable, Sendable {
    case discord
    case telegram
}

/// Destinations for the one-shot idle-after-wait POST. Never-busy and non-settle reasons are none.
public enum NotifIdlePostPolicy: Sendable {
    public static func shouldPost(
        enabled: Bool,
        reason: DisengageReason,
        sawBusy: Bool
    ) -> Bool {
        enabled && reason == .agentsSettled && sawBusy
    }

    public static func destinations(
        discordWebhookURL: String?,
        telegramBotToken: String?,
        telegramChatId: String?
    ) -> [NotifChannel] {
        var destinations: [NotifChannel] = []
        if present(discordWebhookURL) {
            destinations.append(.discord)
        }
        if present(telegramBotToken), present(telegramChatId) {
            destinations.append(.telegram)
        }
        return destinations
    }

    public static func channels(
        enabled: Bool,
        reason: DisengageReason,
        sawBusy: Bool,
        discordWebhookURL: String?,
        telegramBotToken: String?,
        telegramChatId: String?
    ) -> [NotifChannel] {
        guard shouldPost(enabled: enabled, reason: reason, sawBusy: sawBusy) else { return [] }
        return destinations(
            discordWebhookURL: discordWebhookURL,
            telegramBotToken: telegramBotToken,
            telegramChatId: telegramChatId
        )
    }

    static func present(_ value: String?) -> Bool {
        guard let value else { return false }
        return !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
