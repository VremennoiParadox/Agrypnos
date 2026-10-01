import Foundation

public struct NotifSecretsPayload: Equatable, Sendable {
    public var discordWebhookURL: String?
    public var telegramBotToken: String?
    public var telegramChatId: String?
    public var discordBotToken: String?
    public var discordChannelId: String?
    public var telegramQuestionUserId: String?
    public var discordQuestionUserId: String?
    public var openCodeQuestions: OpenCodeQuestionSettings?

    public init(
        discordWebhookURL: String? = nil,
        telegramBotToken: String? = nil,
        telegramChatId: String? = nil,
        discordBotToken: String? = nil,
        discordChannelId: String? = nil,
        telegramQuestionUserId: String? = nil,
        discordQuestionUserId: String? = nil,
        openCodeQuestions: OpenCodeQuestionSettings? = nil
    ) {
        self.discordWebhookURL = Self.present(discordWebhookURL)
        self.telegramBotToken = Self.present(telegramBotToken)
        self.telegramChatId = Self.present(telegramChatId)
        self.discordBotToken = Self.present(discordBotToken)
        self.discordChannelId = Self.present(discordChannelId)
        self.telegramQuestionUserId = Self.present(telegramQuestionUserId)
        self.discordQuestionUserId = Self.present(discordQuestionUserId)
        self.openCodeQuestions = openCodeQuestions
    }

    public static func encode(
        discordWebhookURL: String?,
        telegramBotToken: String?,
        telegramChatId: String?,
        discordBotToken: String? = nil,
        discordChannelId: String? = nil,
        telegramQuestionUserId: String? = nil,
        discordQuestionUserId: String? = nil
    ) -> Data? {
        encode(
            NotifSecretsPayload(
                discordWebhookURL: discordWebhookURL,
                telegramBotToken: telegramBotToken,
                telegramChatId: telegramChatId,
                discordBotToken: discordBotToken,
                discordChannelId: discordChannelId,
                telegramQuestionUserId: telegramQuestionUserId,
                discordQuestionUserId: discordQuestionUserId
            )
        )
    }

    public static func encode(_ payload: NotifSecretsPayload) -> Data? {
        var object: [String: Any] = [:]
        if let value = payload.discordWebhookURL { object["discordWebhookURL"] = value }
        if let value = payload.telegramBotToken { object["telegramBotToken"] = value }
        if let value = payload.telegramChatId { object["telegramChatId"] = value }
        if let value = payload.discordBotToken { object["discordBotToken"] = value }
        if let value = payload.discordChannelId { object["discordChannelId"] = value }
        if let value = payload.telegramQuestionUserId { object["telegramQuestionUserId"] = value }
        if let value = payload.discordQuestionUserId { object["discordQuestionUserId"] = value }
        if let value = payload.openCodeQuestions,
           let data = try? JSONEncoder().encode(value),
           let connection = try? JSONSerialization.jsonObject(with: data) {
            object["openCodeQuestions"] = connection
        }
        return try? JSONSerialization.data(withJSONObject: object)
    }

    public static func decode(_ data: Data) -> NotifSecretsPayload? {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        let connection = (object["openCodeQuestions"] as? [String: Any]).flatMap { value in
            (try? JSONSerialization.data(withJSONObject: value)).flatMap {
                try? JSONDecoder().decode(OpenCodeQuestionSettings.self, from: $0)
            }
        }
        return NotifSecretsPayload(
            discordWebhookURL: object["discordWebhookURL"] as? String,
            telegramBotToken: object["telegramBotToken"] as? String,
            telegramChatId: object["telegramChatId"] as? String,
            discordBotToken: object["discordBotToken"] as? String,
            discordChannelId: object["discordChannelId"] as? String,
            telegramQuestionUserId: object["telegramQuestionUserId"] as? String,
            discordQuestionUserId: object["discordQuestionUserId"] as? String,
            openCodeQuestions: connection
        )
    }

    public static func present(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
