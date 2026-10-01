import Foundation

public struct DiscordQuestionInteraction: Equatable, Sendable {
    public let interactionID: String
    public let interactionToken: String
    public let senderID: String
    public let reference: QuestionMessageRef
    public let actionToken: String

    public static func parse(_ data: [String: Any]?) -> Self? {
        guard let data, DiscordJSON.int(data["type"]) == 3,
              let interactionID = snowflake(data["id"]),
              let interactionToken = NotifSecretsPayload.present(data["token"] as? String),
              let channelID = snowflake(data["channel_id"]),
              let message = data["message"] as? [String: Any],
              let messageID = snowflake(message["id"]),
              let details = data["data"] as? [String: Any],
              let customID = details["custom_id"] as? String,
              customID.hasPrefix("aq:"), customID.count > 3, customID.count <= 100,
              let user = ((data["member"] as? [String: Any])?["user"] as? [String: Any])
                  ?? (data["user"] as? [String: Any]),
              let senderID = snowflake(user["id"]), !DiscordJSON.bool(user["bot"])
        else { return nil }
        return Self(interactionID: interactionID, interactionToken: interactionToken,
            senderID: senderID,
            reference: QuestionMessageRef(destination: .discord, destinationID: channelID, messageID: messageID),
            actionToken: String(customID.dropFirst(3)))
    }

    private static func snowflake(_ raw: Any?) -> String? {
        guard let value = raw as? String else { return nil }
        return DiscordInboundRequestFactory.snowflakePath(value)
    }
}

public enum DiscordQuestionMessage {
    public static func notice(_ content: String, botToken: String, channelID: String) -> NotifOutboundRequest? {
        request(method: "POST", botToken: botToken, channelID: channelID, messageID: nil,
            body: ["content": content, "allowed_mentions": noMentions])
    }

    public static func initial(batch: QuestionBatch, botToken: String, channelID: String) -> NotifOutboundRequest? {
        request(method: "POST", botToken: botToken, channelID: channelID, messageID: nil,
            body: ["content": batch.panelText(at: 0) + "\n\nPreparing controls…", "allowed_mentions": noMentions])
    }

    public static func requests(view: QuestionView, botToken: String, channelID: String) -> [NotifOutboundRequest] {
        guard let request = request(method: "POST", botToken: botToken, channelID: channelID,
            messageID: nil, body: body(view)) else { return [] }
        return [request]
    }

    public static func edit(view: QuestionView, botToken: String, reference: QuestionMessageRef) -> NotifOutboundRequest? {
        guard reference.destination == .discord else { return nil }
        return request(method: "PATCH", botToken: botToken, channelID: reference.destinationID,
            messageID: reference.messageID, body: body(view))
    }

    public static func deferInteraction(interactionID: String, token: String) -> NotifOutboundRequest? {
        guard let interactionID = DiscordInboundRequestFactory.snowflakePath(interactionID),
              let token = NotifSecretsPayload.present(token),
              let body = try? JSONSerialization.data(withJSONObject: ["type": 6]) else { return nil }
        var allowed = CharacterSet.urlPathAllowed
        allowed.remove(charactersIn: "/")
        let encoded = token.addingPercentEncoding(withAllowedCharacters: allowed) ?? token
        return DiscordInboundRequestFactory.api(botToken: nil, method: "POST",
            path: "/api/v10/interactions/\(interactionID)/\(encoded)/callback", body: body)
    }

    private static var noMentions: [String: Any] {
        ["parse": [String](), "users": [String](), "roles": [String](), "replied_user": false]
    }

    private static func body(_ view: QuestionView) -> [String: Any] {
        let question = view.batch.questions[view.questionIndex]
        var buttons: [[String: Any]] = []
        for control in view.controls {
            let label: String
            switch control.action {
            case let .choose(_, optionID):
                guard let index = question.options.firstIndex(where: { $0.id == optionID }) else { continue }
                label = "\(view.selections[question.id]?.contains(optionID) == true ? "✓ " : "")\(index + 1)"
            case .next: label = view.isReview ? "Next review" : "Review / next"
            case .back: label = "Back"
            case .send: label = "Send answers"
            case .returnLocal: label = "Answer on Mac"
            }
            buttons.append(["type": 2, "style": 2, "label": label,
                "custom_id": "aq:" + control.token])
        }
        var rows: [[String: Any]] = []
        for offset in stride(from: 0, to: buttons.count, by: 5) {
            rows.append(["type": 1, "components": Array(buttons[offset..<min(offset + 5, buttons.count)])])
        }
        return ["content": QuestionMessageText.render(view), "allowed_mentions": noMentions,
            "components": rows]
    }

    private static func request(method: String, botToken: String, channelID: String,
                                messageID: String?, body: [String: Any]) -> NotifOutboundRequest? {
        var body = body
        if let text = body["content"] as? String {
            let markers = Set("\\`*_~|<>[]()#+-.!".unicodeScalars)
            let escaped = text.unicodeScalars.map { markers.contains($0) ? "\\" + String($0) : String($0) }.joined()
            guard escaped.utf16.count <= 2000 else { return nil }
            body["content"] = escaped
            body["flags"] = 4 // SUPPRESS_EMBEDS, including previews of local question URLs.
        }
        guard let channelID = DiscordInboundRequestFactory.snowflakePath(channelID),
              let data = try? JSONSerialization.data(withJSONObject: body) else { return nil }
        var path = "/api/v10/channels/\(channelID)/messages"
        if let messageID {
            guard let messageID = DiscordInboundRequestFactory.snowflakePath(messageID) else { return nil }
            path += "/\(messageID)"
        }
        return DiscordInboundRequestFactory.api(botToken: botToken, method: method, path: path, body: data)
    }
}

public enum DiscordQuestionResponse: Equatable, Sendable {
    case sent(QuestionMessageRef)
    case rejected(retryAfter: TimeInterval?)
    case unconfirmed

    public static func parse(status: Int?, body: Data) -> Self {
        guard let status else { return .unconfirmed }
        if status == 429 {
            let retry = (try? JSONDecoder().decode(RateLimit.self, from: body))?.retry_after
            return .rejected(retryAfter: retry.flatMap { $0 > 0 && $0 <= 600 ? $0 : nil })
        }
        guard status < 500 else { return .unconfirmed }
        guard (200...299).contains(status) else { return .rejected(retryAfter: nil) }
        guard let wire = try? JSONDecoder().decode(Message.self, from: body),
              let id = DiscordInboundRequestFactory.snowflakePath(wire.id),
              let channelID = DiscordInboundRequestFactory.snowflakePath(wire.channel_id)
        else { return .unconfirmed }
        return .sent(QuestionMessageRef(destination: .discord, destinationID: channelID, messageID: id))
    }

    private struct Message: Decodable { let id: String; let channel_id: String }
    private struct RateLimit: Decodable { let retry_after: TimeInterval? }
}
