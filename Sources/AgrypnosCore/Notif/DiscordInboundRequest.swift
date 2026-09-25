import Foundation

public enum DiscordInboundRequestFactory: Sendable {
    public static func currentApplication(botToken: String) -> NotifOutboundRequest? {
        api(botToken: botToken, method: "GET", path: "/api/v10/applications/@me", body: Data())
    }

    public static func gatewayBot(botToken: String) -> NotifOutboundRequest? {
        api(botToken: botToken, method: "GET", path: "/api/v10/gateway/bot", body: Data())
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

    /// ACK a slash command within 3s. Follow with `interactionEditOriginal`.
    public static func interactionDefer(
        interactionId: String,
        interactionToken: String
    ) -> NotifOutboundRequest? {
        guard let interactionId = snowflakePath(interactionId) else { return nil }
        guard let token = NotifSecretsPayload.present(interactionToken) else { return nil }
        var allowed = CharacterSet.urlPathAllowed
        allowed.remove(charactersIn: "/")
        let encoded = token.addingPercentEncoding(withAllowedCharacters: allowed) ?? token
        guard let body = try? JSONSerialization.data(withJSONObject: ["type": 5]) else { return nil }
        return api(
            botToken: nil,
            method: "POST",
            path: "/api/v10/interactions/\(interactionId)/\(encoded)/callback",
            body: body
        )
    }

    /// PATCH the deferred slash reply. Interaction token in the path — not an incoming webhook.
    public static func interactionEditOriginal(
        applicationId: String,
        interactionToken: String,
        content: String
    ) -> NotifOutboundRequest? {
        guard let applicationId = snowflakePath(applicationId) else { return nil }
        guard let token = NotifSecretsPayload.present(interactionToken) else { return nil }
        var allowed = CharacterSet.urlPathAllowed
        allowed.remove(charactersIn: "/")
        let encoded = token.addingPercentEncoding(withAllowedCharacters: allowed) ?? token
        guard let body = NotifOutboundRequestFactory.json(["content": content]) else { return nil }
        return api(
            botToken: nil,
            method: "PATCH",
            path: "/api/v10/webhooks/\(applicationId)/\(encoded)/messages/@original",
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
        let interactionOriginal =
            method == "PATCH"
            && parts.count >= 6
            && parts[0] == "api"
            && parts[1] == "v10"
            && parts[2] == "webhooks"
            && snowflakePath(String(parts[3])) != nil
            && parts[parts.count - 2] == "messages"
            && parts[parts.count - 1] == "@original"
        guard !parts.contains("webhooks") || interactionOriginal else { return nil }
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
        } else if method == "POST", path.contains("/interactions/") {
            // slash callback / defer — interaction token is in the path
        } else if interactionOriginal {
            // deferred slash follow-up — interaction token is in the path
        } else {
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

public enum DiscordGatewayBotParser: Sendable {
    public static func url(from data: Data) -> URL? {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        guard let raw = NotifSecretsPayload.present(object["url"] as? String) else { return nil }
        guard let url = URL(string: raw), url.scheme == "wss" else { return nil }
        guard let host = url.host?.lowercased(), host.hasSuffix("gateway.discord.gg") else {
            return nil
        }
        return url
    }
}

public enum DiscordGatewayURLFactory: Sendable {
    public static func socketURL(
        gatewayBotData: Data?,
        resumeGatewayURL: String?,
        canResume: Bool
    ) -> URL {
        if canResume, let resume = resumeURL(from: resumeGatewayURL) {
            return resume
        }
        if let data = gatewayBotData, let url = DiscordGatewayBotParser.url(from: data) {
            return withGatewayQuery(url)
        }
        return DiscordInboundTransport.gatewayURL
    }

    public static func resumeURL(from raw: String?) -> URL? {
        guard let raw = NotifSecretsPayload.present(raw) else { return nil }
        guard let url = URL(string: raw), url.scheme == "wss" else { return nil }
        guard let host = url.host?.lowercased(), host.hasSuffix("gateway.discord.gg") else {
            return nil
        }
        return withGatewayQuery(url)
    }

    public static func withGatewayQuery(_ url: URL) -> URL {
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false) ?? URLComponents()
        var items = components.queryItems ?? []
        if !items.contains(where: { $0.name == "v" }) {
            items.append(URLQueryItem(name: "v", value: "10"))
        }
        if !items.contains(where: { $0.name == "encoding" }) {
            items.append(URLQueryItem(name: "encoding", value: "json"))
        }
        components.queryItems = items
        return components.url ?? url
    }
}
