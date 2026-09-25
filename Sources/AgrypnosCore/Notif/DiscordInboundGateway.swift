import Foundation

/// Receive on the Mac via Gateway. No listen port. No Interactions Endpoint URL.
public enum DiscordInboundTransport: Sendable {
    public static let listenPort: Int? = nil
    public static let interactionsEndpointURL: URL? = nil
    public static let usesIncomingWebhook = false
    public static let scrapeChannelHistoryOnWake = false
    public static let gatewayURL = URL(string: "wss://gateway.discord.gg/?v=10&encoding=json")!
}

public enum DiscordGatewayEvent: Equatable, Sendable {
    case hello(heartbeatIntervalMs: Int)
    case heartbeatAck
    case reconnect
    case invalidSession(resumable: Bool)
    case ready(sessionId: String, applicationId: String?)
    case inbound(DiscordInboundUpdate)
    case other
}

public struct DiscordGatewayFrame: Equatable, Sendable {
    public var op: Int
    public var sequence: Int64?
    public var event: DiscordGatewayEvent
}

public enum DiscordGatewayPayload: Sendable {
    /// GUILDS | GUILD_MESSAGES | DIRECT_MESSAGES. Slash INTERACTION_CREATE needs no privileged intent.
    public static let identifyIntents = 1 | (1 << 9) | (1 << 12)

    public static func identify(botToken: String) -> [String: Any]? {
        guard let token = NotifSecretsPayload.present(botToken) else { return nil }
        return [
            "op": 2,
            "d": [
                "token": token,
                "intents": identifyIntents,
                "properties": [
                    "os": "macos",
                    "browser": "Agrypnos",
                    "device": "Agrypnos",
                ],
            ],
        ]
    }

    public static func resume(botToken: String, sessionId: String?, sequence: Int64?) -> [String: Any]? {
        guard let token = NotifSecretsPayload.present(botToken) else { return nil }
        guard let sessionId = NotifSecretsPayload.present(sessionId), let sequence else { return nil }
        return [
            "op": 6,
            "d": [
                "token": token,
                "session_id": sessionId,
                "seq": Int(sequence),
            ],
        ]
    }

    public static func heartbeat(sequence: Int64?) -> [String: Any]? {
        let d: Any = sequence.map { Int($0) as Any } ?? NSNull()
        return ["op": 1, "d": d]
    }
}

public enum DiscordGatewayParser: Sendable {
    public static func frame(from data: Data) -> DiscordGatewayFrame? {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        guard let op = DiscordJSON.int(object["op"]) else { return nil }
        let sequence = DiscordJSON.int64(object["s"])
        return DiscordGatewayFrame(op: op, sequence: sequence, event: event(op: op, object: object))
    }

    static func event(op: Int, object: [String: Any]) -> DiscordGatewayEvent {
        switch op {
        case 10:
            let interval = DiscordJSON.int(dict(object["d"])?["heartbeat_interval"])
            guard let interval else { return .other }
            return .hello(heartbeatIntervalMs: interval)
        case 11:
            return .heartbeatAck
        case 7:
            return .reconnect
        case 9:
            return .invalidSession(resumable: DiscordJSON.bool(object["d"]))
        case 0:
            return dispatch(type: object["t"] as? String, data: dict(object["d"]))
        default:
            return .other
        }
    }

    static func dispatch(type: String?, data: [String: Any]?) -> DiscordGatewayEvent {
        switch type {
        case "READY":
            guard let sessionId = NotifSecretsPayload.present(data?["session_id"] as? String) else {
                return .other
            }
            let applicationId = NotifSecretsPayload.present(dict(data?["application"])?["id"] as? String)
                ?? DiscordJSON.int64(dict(data?["application"])?["id"]).map(String.init)
            return .ready(sessionId: sessionId, applicationId: applicationId)
        case "MESSAGE_CREATE":
            guard let update = messageUpdate(data) else { return .other }
            return .inbound(update)
        case "INTERACTION_CREATE":
            guard let update = slashUpdate(data) else { return .other }
            return .inbound(update)
        default:
            return .other
        }
    }

    static func messageUpdate(_ data: [String: Any]?) -> DiscordInboundUpdate? {
        guard let data else { return nil }
        if data["webhook_id"] != nil { return nil }
        if data["interaction"] != nil { return nil }
        if DiscordJSON.bool(dict(data["author"])?["bot"]) { return nil }
        guard let channelId = snowflake(data["channel_id"]) else { return nil }
        return DiscordInboundUpdate(
            channelId: channelId,
            text: data["content"] as? String,
            source: .message
        )
    }

    static func slashUpdate(_ data: [String: Any]?) -> DiscordInboundUpdate? {
        guard let data else { return nil }
        guard DiscordJSON.int(data["type"]) == 2 else { return nil }
        guard let channelId = snowflake(data["channel_id"]) else { return nil }
        let name = dict(data["data"])?["name"] as? String
        return DiscordInboundUpdate(
            channelId: channelId,
            text: name,
            interactionId: snowflake(data["id"]),
            interactionToken: NotifSecretsPayload.present(data["token"] as? String),
            source: .slash
        )
    }

    static func snowflake(_ value: Any?) -> String? {
        if let string = value as? String {
            return NotifSecretsPayload.present(string)
        }
        if let n = DiscordJSON.int64(value) {
            return String(n)
        }
        return nil
    }

    static func dict(_ value: Any?) -> [String: Any]? {
        value as? [String: Any]
    }
}

enum DiscordJSON {
    static func int64(_ value: Any?) -> Int64? {
        switch value {
        case let i as Int64: return i
        case let i as Int: return Int64(i)
        case let i as UInt64 where i <= UInt64(Int64.max): return Int64(i)
        case let n as NSNumber: return n.int64Value
        case let d as Double where d.rounded() == d: return Int64(d)
        case let s as String: return Int64(s)
        default: return nil
        }
    }

    static func int(_ value: Any?) -> Int? {
        int64(value).map(Int.init)
    }

    static func bool(_ value: Any?) -> Bool {
        if let b = value as? Bool { return b }
        if let n = value as? NSNumber { return n.boolValue }
        return false
    }
}
