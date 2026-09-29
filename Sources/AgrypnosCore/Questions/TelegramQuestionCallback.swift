import Foundation

public struct TelegramQuestionCallback: Equatable, Sendable {
    public let id: String
    public let senderID: String
    public let reference: QuestionMessageRef
    public let actionToken: String

    public init(id: String, senderID: String, reference: QuestionMessageRef, actionToken: String) {
        self.id = id
        self.senderID = senderID
        self.reference = reference
        self.actionToken = actionToken
    }

    static func parse(_ raw: Any?) -> Self? {
        guard let raw, JSONSerialization.isValidJSONObject(raw),
              let data = try? JSONSerialization.data(withJSONObject: raw),
              let wire = try? JSONDecoder().decode(Wire.self, from: data),
              !wire.id.isEmpty, wire.from.id > 0, wire.message.message_id > 0,
              wire.data.hasPrefix("aq:"), wire.data.utf8.count <= 64, wire.data.count > 3 else { return nil }
        return Self(id: wire.id, senderID: String(wire.from.id),
            reference: QuestionMessageRef(destination: .telegram, destinationID: String(wire.message.chat.id),
                messageID: String(wire.message.message_id)), actionToken: String(wire.data.dropFirst(3)))
    }

    private struct Wire: Decodable {
        struct ID: Decodable { let id: Int64 }
        struct Message: Decodable { let message_id: Int64; let chat: ID }
        let id: String
        let from: ID
        let message: Message
        let data: String
    }
}

public enum TelegramQuestionResponse: Equatable, Sendable {
    case sent(QuestionMessageRef)
    case rejected(retryAfter: TimeInterval?)
    case unconfirmed

    public static func parse(status: Int?, body: Data) -> Self {
        guard let status else { return .unconfirmed }
        let response = try? JSONDecoder().decode(Wire.self, from: body)
        if status == 429, response?.ok == false {
            let retry = response?.parameters?.retry_after
            return .rejected(retryAfter: retry.flatMap { $0 > 0 && $0 <= 600 ? Double($0) : nil })
        }
        // A server failure or lost response can follow creation; never resend blindly.
        guard status < 500 else { return .unconfirmed }
        guard (200...299).contains(status) else { return .rejected(retryAfter: nil) }
        guard let response else { return .unconfirmed }
        guard response.ok else { return .rejected(retryAfter: nil) }
        guard let message = response.result, message.message_id > 0 else { return .unconfirmed }
        return .sent(QuestionMessageRef(destination: .telegram, destinationID: String(message.chat.id),
            messageID: String(message.message_id)))
    }

    private struct Wire: Decodable {
        struct Chat: Decodable { let id: Int64 }
        struct Message: Decodable { let message_id: Int64; let chat: Chat }
        struct Parameters: Decodable { let retry_after: Int? }
        let ok: Bool
        let result: Message?
        let parameters: Parameters?
    }
}
