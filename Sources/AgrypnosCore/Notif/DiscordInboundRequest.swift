import Foundation

public enum DiscordInboundRequestFactory: Sendable {
    public static func currentApplication(botToken: String) -> NotifOutboundRequest? {
        api(botToken: botToken, method: "GET", path: "/api/v10/applications/@me", body: Data())
    }

    public static func bulkOverwriteCommands(
        botToken: String,
        applicationId: String
    ) -> NotifOutboundRequest? {
        guard let applicationId = snowflakePath(applicationId) else { return nil }
        let commands: [[String: Any]] = DiscordBotCommandMenu.commands.map {
            [
                "type": 1,
                "name": $0.command,
                "description": $0.description,
            ]
        }
        guard let body = try? JSONSerialization.data(withJSONObject: commands) else { return nil }
        return api(
            botToken: botToken,
            method: "PUT",
            path: "/api/v10/applications/\(applicationId)/commands",
            body: body
        )
    }

    public static func channelMessage(
        botToken: String,
        channelId: String,
        content: String
    ) -> NotifOutboundRequest? {
        guard let channelId = snowflakePath(channelId) else { return nil }
        guard let body = NotifOutboundRequestFactory.json(["content": content]) else { return nil }
        return api(
            botToken: botToken,
            method: "POST",
            path: "/api/v10/channels/\(channelId)/messages",
            body: body
        )
    }

    public static func interactionCallback(
        interactionId: String,
        interactionToken: String,
        content: String
    ) -> NotifOutboundRequest? {
        guard let interactionId = snowflakePath(interactionId) else { return nil }
        guard let token = NotifSecretsPayload.present(interactionToken) else { return nil }
        var allowed = CharacterSet.urlPathAllowed
        allowed.remove(charactersIn: "/")
        let encoded = token.addingPercentEncoding(withAllowedCharacters: allowed) ?? token
        let bodyObject: [String: Any] = [
            "type": 4,
            "data": ["content": content],
        ]
        guard let body = try? JSONSerialization.data(withJSONObject: bodyObject) else { return nil }
        return api(
            botToken: nil,
            method: "POST",
            path: "/api/v10/interactions/\(interactionId)/\(encoded)/callback",
            body: body
        )
    }

    /// Never scrape channel history on wake to invent missed commands.
    public static func channelMessages(botToken _: String, channelId _: String) -> NotifOutboundRequest? {
        nil
    }

    /// Do not set Discord's Interactions Endpoint URL. Receive on the Mac.
    public static func interactionsEndpointRegistration() -> NotifOutboundRequest? {
        nil
    }

    static func api(
        botToken: String?,
        method: String,
        path: String,
        body: Data
    ) -> NotifOutboundRequest? {
        guard path.hasPrefix("/api/v10/") else { return nil }
        let parts = path.split(separator: "/", omittingEmptySubsequences: true)
        guard !parts.contains("webhooks") else { return nil }
        var components = URLComponents()
        components.scheme = "https"
        components.host = "discord.com"
        components.path = path
        guard let url = components.url, url.host == "discord.com", url.scheme == "https" else {
            return nil
        }
        var headers = NotifOutboundRequestFactory.jsonHeaders
        if let token = NotifSecretsPayload.present(botToken) {
            headers["Authorization"] = "Bot \(token)"
        } else if method != "POST" || !path.contains("/interactions/") {
            return nil
        }
        return NotifOutboundRequest(url: url, httpMethod: method, headers: headers, body: body)
    }

    static func snowflakePath(_ raw: String) -> String? {
        guard let value = NotifSecretsPayload.present(raw) else { return nil }
        let digits = value.unicodeScalars
        guard digits.allSatisfy({ $0.isASCII && CharacterSet.decimalDigits.contains($0) }) else {
            return nil
        }
        return value
    }
}

public enum DiscordApplicationParser: Sendable {
    public static func id(from data: Data) -> String? {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        if let string = NotifSecretsPayload.present(object["id"] as? String) {
            return string
        }
        if let n = DiscordJSON.int64(object["id"]) {
            return String(n)
        }
        return nil
    }
}
