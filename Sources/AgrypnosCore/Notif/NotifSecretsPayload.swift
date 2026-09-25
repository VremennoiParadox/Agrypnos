import Foundation

public struct NotifSecretsPayload: Equatable, Sendable {
    public var discordWebhookURL: String?
    public var telegramBotToken: String?
    public var telegramChatId: String?
    public var discordBotToken: String?
    public var discordChannelId: String?

    public init(
        discordWebhookURL: String? = nil,
        telegramBotToken: String? = nil,
        telegramChatId: String? = nil,
        discordBotToken: String? = nil,
        discordChannelId: String? = nil
    ) {
        self.discordWebhookURL = Self.present(discordWebhookURL)
        self.telegramBotToken = Self.present(telegramBotToken)
        self.telegramChatId = Self.present(telegramChatId)
        self.discordBotToken = Self.present(discordBotToken)
        self.discordChannelId = Self.present(discordChannelId)
    }

    public static func encode(
        discordWebhookURL: String?,
        telegramBotToken: String?,
        telegramChatId: String?,
        discordBotToken: String? = nil,
        discordChannelId: String? = nil
    ) -> Data? {
        encode(
            NotifSecretsPayload(
                discordWebhookURL: discordWebhookURL,
                telegramBotToken: telegramBotToken,
                telegramChatId: telegramChatId,
                discordBotToken: discordBotToken,
                discordChannelId: discordChannelId
            )
        )
    }

    public static func encode(_ payload: NotifSecretsPayload) -> Data? {
        var object: [String: String] = [:]
        if let value = payload.discordWebhookURL { object["discordWebhookURL"] = value }
        if let value = payload.telegramBotToken { object["telegramBotToken"] = value }
        if let value = payload.telegramChatId { object["telegramChatId"] = value }
        if let value = payload.discordBotToken { object["discordBotToken"] = value }
        if let value = payload.discordChannelId { object["discordChannelId"] = value }
        return try? JSONSerialization.data(withJSONObject: object)
    }

    public static func decode(_ data: Data) -> NotifSecretsPayload? {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        return NotifSecretsPayload(
            discordWebhookURL: object["discordWebhookURL"] as? String,
            telegramBotToken: object["telegramBotToken"] as? String,
            telegramChatId: object["telegramChatId"] as? String,
            discordBotToken: object["discordBotToken"] as? String,
            discordChannelId: object["discordChannelId"] as? String
        )
    }

    public static func present(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
