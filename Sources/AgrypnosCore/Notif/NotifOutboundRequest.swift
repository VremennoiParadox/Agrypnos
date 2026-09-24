import Foundation

public struct NotifOutboundRequest: Equatable, Sendable {
    public var url: URL
    public var httpMethod: String
    public var headers: [String: String]
    public var body: Data

    public init(url: URL, httpMethod: String, headers: [String: String], body: Data) {
        self.url = url
        self.httpMethod = httpMethod
        self.headers = headers
        self.body = body
    }
}

public enum NotifOutboundRequestFactory: Sendable {
    public static func discord(webhookURL: String, content: String) -> NotifOutboundRequest? {
        guard let url = DiscordWebhookURL.parse(webhookURL) else { return nil }
        guard let body = json(["content": content]) else { return nil }
        return NotifOutboundRequest(
            url: url,
            httpMethod: "POST",
            headers: jsonHeaders,
            body: body
        )
    }

    public static func telegram(
        botToken: String,
        chatId: String,
        text: String
    ) -> NotifOutboundRequest? {
        let chat = chatId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !chat.isEmpty else { return nil }
        guard let url = telegramAPIURL(botToken: botToken, method: "sendMessage") else { return nil }
        guard let body = telegramBody(chatId: chat, text: text) else { return nil }
        return NotifOutboundRequest(
            url: url,
            httpMethod: "POST",
            headers: jsonHeaders,
            body: body
        )
    }

    public static func telegramSetMyCommands(botToken: String) -> NotifOutboundRequest? {
        guard let url = telegramAPIURL(botToken: botToken, method: "setMyCommands") else { return nil }
        let commands = TelegramBotCommandMenu.commands.map {
            ["command": $0.command, "description": $0.description]
        }
        guard let body = try? JSONSerialization.data(withJSONObject: ["commands": commands]) else {
            return nil
        }
        return NotifOutboundRequest(
            url: url,
            httpMethod: "POST",
            headers: jsonHeaders,
            body: body
        )
    }

    public static func telegramGetUpdates(
        botToken: String,
        offset: Int64,
        timeout: Int
    ) -> NotifOutboundRequest? {
        guard
            let url = telegramAPIURL(
                botToken: botToken,
                method: "getUpdates",
                query: [
                    URLQueryItem(name: "offset", value: String(offset)),
                    URLQueryItem(name: "timeout", value: String(max(timeout, 0))),
                ]
            )
        else {
            return nil
        }
        return NotifOutboundRequest(
            url: url,
            httpMethod: "GET",
            headers: [:],
            body: Data()
        )
    }

    static func telegramAPIURL(
        botToken: String,
        method: String,
        query: [URLQueryItem] = []
    ) -> URL? {
        let token = botToken.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !token.isEmpty else { return nil }
        var pathAllowed = CharacterSet.urlPathAllowed
        pathAllowed.insert(charactersIn: ":")
        let encodedToken = token.addingPercentEncoding(withAllowedCharacters: pathAllowed) ?? token
        guard
            let base = URL(string: "https://api.telegram.org/bot\(encodedToken)/\(method)"),
            base.scheme == "https",
            base.host == "api.telegram.org"
        else {
            return nil
        }
        guard !query.isEmpty else { return base }
        guard var components = URLComponents(url: base, resolvingAgainstBaseURL: false) else {
            return nil
        }
        components.queryItems = query
        return components.url
    }

    static let jsonHeaders = ["Content-Type": "application/json"]

    static func json(_ object: [String: String]) -> Data? {
        try? JSONSerialization.data(withJSONObject: object)
    }

    static func telegramBody(chatId: String, text: String) -> Data? {
        var object: [String: Any] = ["text": text]
        if let n = Int64(chatId) {
            object["chat_id"] = n
        } else {
            object["chat_id"] = chatId
        }
        return try? JSONSerialization.data(withJSONObject: object)
    }
}

public enum NotifOutboundPostOutcome: Equatable, Sendable {
    case accepted
    case rejected
    case unreachable
}

public enum NotifOutboundPostChrome: Sendable {
    public static func channel(for url: URL) -> NotifChannel {
        url.host?.lowercased() == "api.telegram.org" ? .telegram : .discord
    }

    public static func outcome(
        channel: NotifChannel,
        statusCode: Int?,
        body: Data
    ) -> NotifOutboundPostOutcome {
        guard let statusCode else { return .unreachable }
        switch channel {
        case .discord:
            return (200...299).contains(statusCode) ? .accepted : .rejected
        case .telegram:
            guard (200...299).contains(statusCode) else { return .rejected }
            guard
                let object = try? JSONSerialization.jsonObject(with: body) as? [String: Any],
                object["ok"] as? Bool == true
            else {
                return .rejected
            }
            return .accepted
        }
    }

    public static func notifyCopy(
        channel: NotifChannel,
        outcome: NotifOutboundPostOutcome,
        detail: String? = nil
    ) -> String? {
        let base: String?
        switch outcome {
        case .accepted:
            base = nil
        case .rejected, .unreachable:
            switch channel {
            case .discord: base = AgrypnosCopy.notifDiscordPostFailed
            case .telegram: base = AgrypnosCopy.notifTelegramPostFailed
            }
        }
        guard let base else { return nil }
        let extra = detail?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !extra.isEmpty else { return base }
        return "\(base) \(String(extra.prefix(80)))"
    }

    public static func telegramDetail(body: Data) -> String? {
        guard
            let object = try? JSONSerialization.jsonObject(with: body) as? [String: Any],
            let description = object["description"] as? String
        else {
            return nil
        }
        let trimmed = description.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : String(trimmed.prefix(80))
    }
}
