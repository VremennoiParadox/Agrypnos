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
        let token = botToken.trimmingCharacters(in: .whitespacesAndNewlines)
        let chat = chatId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !token.isEmpty, !chat.isEmpty else { return nil }
        var pathAllowed = CharacterSet.urlPathAllowed
        pathAllowed.insert(charactersIn: ":")
        let encodedToken = token.addingPercentEncoding(withAllowedCharacters: pathAllowed) ?? token
        guard
            let url = URL(string: "https://api.telegram.org/bot\(encodedToken)/sendMessage"),
            url.scheme == "https",
            url.host == "api.telegram.org"
        else {
            return nil
        }
        guard let body = json(["chat_id": chat, "text": text]) else { return nil }
        return NotifOutboundRequest(
            url: url,
            httpMethod: "POST",
            headers: jsonHeaders,
            body: body
        )
    }

    static let jsonHeaders = ["Content-Type": "application/json"]

    static func json(_ object: [String: String]) -> Data? {
        try? JSONSerialization.data(withJSONObject: object)
    }
}
