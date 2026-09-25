import Foundation

public enum DiscordGatewayEffect: Equatable, Sendable {
    case sendIdentify
    case sendResume
    case sendHeartbeat
    case inbound(DiscordInboundUpdate)
    case registerCommands(applicationId: String)
    case reconnect(resume: Bool)
}

/// Core owns identify/resume/heartbeat/cursor. Mac owns the WebSocket.
public struct DiscordGatewaySession: Equatable, Sendable {
    public var cursor: DiscordInboundCursor
    public var heartbeatIntervalMs: Int?

    public init(cursor: DiscordInboundCursor) {
        self.cursor = cursor
        self.heartbeatIntervalMs = nil
    }

    public mutating func handle(_ frame: DiscordGatewayFrame) -> [DiscordGatewayEffect] {
        switch frame.event {
        case .hello(let interval):
            heartbeatIntervalMs = interval
            return [cursor.canResume ? .sendResume : .sendIdentify]
        case .heartbeat:
            return [.sendHeartbeat]
        case .heartbeatAck:
            return []
        case .reconnect:
            return [.reconnect(resume: cursor.canResume)]
        case .invalidSession(let resumable):
            cursor = cursor.invalidatingSession(resumable: resumable)
            return [cursor.canResume ? .sendResume : .sendIdentify]
        case .ready(let sessionId, let applicationId, let resumeGatewayURL):
            cursor = cursor.acknowledging(
                sequence: frame.sequence,
                sessionId: sessionId,
                resumeGatewayURL: resumeGatewayURL
            )
            if let applicationId {
                return [.registerCommands(applicationId: applicationId)]
            }
            return []
        case .resumed:
            cursor = cursor.acknowledging(sequence: frame.sequence)
            return []
        case .inbound(let update):
            cursor = cursor.recording(sequence: frame.sequence)
            return [.inbound(update)]
        case .other:
            if let sequence = frame.sequence {
                cursor = cursor.recording(sequence: sequence)
            }
            return []
        }
    }

    public static func payload(
        _ effect: DiscordGatewayEffect,
        botToken: String,
        cursor: DiscordInboundCursor
    ) -> [String: Any]? {
        switch effect {
        case .sendIdentify:
            return DiscordGatewayPayload.identify(botToken: botToken)
        case .sendResume:
            return DiscordGatewayPayload.resume(
                botToken: botToken,
                sessionId: cursor.sessionId,
                sequence: cursor.sequence
            )
        case .sendHeartbeat:
            return DiscordGatewayPayload.heartbeat(sequence: cursor.sequence)
        case .inbound, .registerCommands, .reconnect:
            return nil
        }
    }

    public static func json(_ object: [String: Any]) -> Data? {
        try? JSONSerialization.data(withJSONObject: object)
    }
}
