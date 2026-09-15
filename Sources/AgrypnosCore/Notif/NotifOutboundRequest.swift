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
        guard let url = httpsURL(webhookURL) else { return nil }
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
        let token = botToken.trimmingCharacters(in: .whitespacesAndNewlines)
        let chat = chatId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !token.isEmpty, !chat.isEmpty else { return nil }
        guard let url = URL(string: "https://api.telegram.org/bot\(token)/sendMessage") else {
            return nil
        }
        guard url.scheme == "https" else { return nil }
        guard let body = json(["chat_id": chat, "text": text]) else { return nil }
        return NotifOutboundRequest(
            url: url,
            httpMethod: "POST",
            headers: jsonHeaders,
            body: body
        )
    }

    static let jsonHeaders = ["Content-Type": "application/json"]

    static func httpsURL(_ raw: String) -> URL? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let url = URL(string: trimmed), url.scheme == "https" else {
            return nil
        }
        return url
    }

    static func json(_ object: [String: String]) -> Data? {
        try? JSONSerialization.data(withJSONObject: object)
    }
}
