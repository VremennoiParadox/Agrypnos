import Foundation

public struct NotifSecretsPayload: Codable, Equatable, Sendable {
    public var telegramBotToken: String?
    public var telegramChatId: String?
    public var discordBotToken: String?
    public var discordChannelId: String?
    public var telegramQuestionUserId: String?
    public var discordQuestionUserId: String?
    public var openCodeQuestions: OpenCodeQuestionSettings?

    enum CodingKeys: String, CodingKey {
        case telegramBotToken
        case telegramChatId
        case discordBotToken
        case discordChannelId
        case telegramQuestionUserId
        case discordQuestionUserId
        case openCodeQuestions
    }

    public init(
        telegramBotToken: String? = nil,
        telegramChatId: String? = nil,
        discordBotToken: String? = nil,
        discordChannelId: String? = nil,
        telegramQuestionUserId: String? = nil,
        discordQuestionUserId: String? = nil,
        openCodeQuestions: OpenCodeQuestionSettings? = nil
    ) {
        self.telegramBotToken = Self.present(telegramBotToken)
        self.telegramChatId = Self.present(telegramChatId)
        self.discordBotToken = Self.present(discordBotToken)
        self.discordChannelId = Self.present(discordChannelId)
        self.telegramQuestionUserId = Self.present(telegramQuestionUserId)
        self.discordQuestionUserId = Self.present(discordQuestionUserId)
        self.openCodeQuestions = openCodeQuestions
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            telegramBotToken: try container.decodeIfPresent(String.self, forKey: .telegramBotToken),
            telegramChatId: try container.decodeIfPresent(String.self, forKey: .telegramChatId),
            discordBotToken: try container.decodeIfPresent(String.self, forKey: .discordBotToken),
            discordChannelId: try container.decodeIfPresent(String.self, forKey: .discordChannelId),
            telegramQuestionUserId: try container.decodeIfPresent(String.self, forKey: .telegramQuestionUserId),
            discordQuestionUserId: try container.decodeIfPresent(String.self, forKey: .discordQuestionUserId),
            openCodeQuestions: try container.decodeIfPresent(OpenCodeQuestionSettings.self, forKey: .openCodeQuestions)
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(telegramBotToken, forKey: .telegramBotToken)
        try container.encodeIfPresent(telegramChatId, forKey: .telegramChatId)
        try container.encodeIfPresent(discordBotToken, forKey: .discordBotToken)
        try container.encodeIfPresent(discordChannelId, forKey: .discordChannelId)
        try container.encodeIfPresent(telegramQuestionUserId, forKey: .telegramQuestionUserId)
        try container.encodeIfPresent(discordQuestionUserId, forKey: .discordQuestionUserId)
        try container.encodeIfPresent(openCodeQuestions, forKey: .openCodeQuestions)
    }

    public static func encode(
        telegramBotToken: String?,
        telegramChatId: String?,
        discordBotToken: String? = nil,
        discordChannelId: String? = nil,
        telegramQuestionUserId: String? = nil,
        discordQuestionUserId: String? = nil
    ) -> Data? {
        encode(
            NotifSecretsPayload(
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
