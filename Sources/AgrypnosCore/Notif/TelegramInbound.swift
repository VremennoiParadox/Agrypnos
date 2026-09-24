import Foundation

public enum TelegramInboundIntent: Equatable, Sendable {
    case ignore
    case arm
    case disarm
    case status

    /// Shared Mac + Core decision. nil means do not call WatchEngine engage.
    public func shouldSetEngaged(currentlyEngaged: Bool) -> Bool? {
        switch self {
        case .arm:
            return currentlyEngaged ? nil : true
        case .disarm:
            return currentlyEngaged ? false : nil
        case .ignore, .status:
            return nil
        }
    }
}

public enum TelegramInboundCommand: Equatable, Sendable {
    case arm
    case disarm
    case status

    public static func parse(_ text: String) -> TelegramInboundCommand? {
        var trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("/") {
            trimmed.removeFirst()
        }
        if let at = trimmed.firstIndex(of: "@") {
            trimmed = String(trimmed[..<at])
        }
        switch trimmed.lowercased() {
        case "arm": return .arm
        case "disarm": return .disarm
        case "status": return .status
        default: return nil
        }
    }

    var intent: TelegramInboundIntent {
        switch self {
        case .arm: return .arm
        case .disarm: return .disarm
        case .status: return .status
        }
    }
}

public struct TelegramInboundUpdate: Equatable, Sendable {
    public var updateId: Int64
    public var chatId: String
    public var text: String?

    public init(updateId: Int64, chatId: String, text: String?) {
        self.updateId = updateId
        self.chatId = chatId
        self.text = text
    }
}

public enum TelegramInboundPolicy: Sendable {
    public static func shouldPoll(
        enabled: Bool,
        botToken: String?,
        chatId: String?
    ) -> Bool {
        enabled
            && NotifSecretsPayload.present(botToken) != nil
            && NotifSecretsPayload.present(chatId) != nil
    }

    public static func intent(
        enabled: Bool,
        botToken: String?,
        savedChatId: String?,
        update: TelegramInboundUpdate
    ) -> TelegramInboundIntent {
        guard shouldPoll(enabled: enabled, botToken: botToken, chatId: savedChatId) else {
            return .ignore
        }
        guard chatMatches(saved: savedChatId, incoming: update.chatId) else {
            return .ignore
        }
        guard let text = update.text else { return .ignore }
        return TelegramInboundCommand.parse(text)?.intent ?? .ignore
    }

    public static func sameBot(fetchedToken: String?, currentToken: String?) -> Bool {
        NotifSecretsPayload.present(fetchedToken) != nil
            && NotifSecretsPayload.present(fetchedToken) == NotifSecretsPayload.present(currentToken)
    }

    static func chatMatches(saved: String?, incoming: String) -> Bool {
        guard let saved = NotifSecretsPayload.present(saved) else { return false }
        let incomingTrimmed = incoming.trimmingCharacters(in: .whitespacesAndNewlines)
        if saved == incomingTrimmed { return true }
        if let a = Int64(saved), let b = Int64(incomingTrimmed), a == b { return true }
        return false
    }
}

public enum TelegramInboundOffset: Sendable {
    public static func next(current: Int64, updates: [TelegramInboundUpdate]) -> Int64 {
        guard let maxId = updates.map(\.updateId).max() else { return current }
        return max(current, maxId + 1)
    }
}

/// `getUpdates` offset plus a one-shot backlog drain. Unseeded first poll acks without running commands.
public struct TelegramInboundCursor: Equatable, Sendable {
    public var offset: Int64
    public var seeded: Bool

    public static let unset = TelegramInboundCursor(offset: 0, seeded: false)

    public init(offset: Int64, seeded: Bool) {
        self.offset = max(0, offset)
        self.seeded = seeded
    }

    public var shouldApplyCommands: Bool { seeded }

    /// New process or poll loop: keep the offset, skip leftover commands once.
    public func startingSession() -> TelegramInboundCursor {
        TelegramInboundCursor(offset: offset, seeded: false)
    }

    public func acknowledging(_ updates: [TelegramInboundUpdate]) -> TelegramInboundCursor {
        TelegramInboundCursor(
            offset: TelegramInboundOffset.next(current: offset, updates: updates),
            seeded: true
        )
    }
}

public enum TelegramInboundGeneration: Sendable {
    public static func allowsApply(current: UInt64, captured: UInt64) -> Bool {
        current == captured
    }
}

public enum TelegramInboundCopy: Sendable {
    public static let armed = "Armed."
    public static let disarmed = "Disarmed."
    public static let keepOn = "Keep the watch is on."
    public static let keepOff = "Keep the watch is off."
    public static let armFailed = "Couldn't keep the watch."
    public static let disarmFailed = "Couldn't drop SleepDisabled."
    public static let commandsHelp = "Commands on your Telegram bot: arm, disarm, status."

    public static func status(engaged: Bool, duration: DurationOption) -> String {
        guard engaged else { return keepOff }
        return "\(keepOn) How long is \(duration.segmentTitle)."
    }

    public static func reply(
        intent: TelegramInboundIntent,
        engaged: Bool,
        duration: DurationOption
    ) -> String? {
        switch intent {
        case .ignore: return nil
        case .arm: return armed
        case .disarm: return disarmed
        case .status: return status(engaged: engaged, duration: duration)
        }
    }
}

public enum TelegramGetUpdatesParser: Sendable {
    public static func accepted(_ data: Data) -> Bool {
        guard
            let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            object["ok"] as? Bool == true
        else {
            return false
        }
        return true
    }

    public static func parse(_ data: Data) -> [TelegramInboundUpdate] {
        guard
            let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            object["ok"] as? Bool == true,
            let result = object["result"] as? [Any]
        else {
            return []
        }
        return result.compactMap(update(from:))
    }

    static func update(from raw: Any) -> TelegramInboundUpdate? {
        guard let object = raw as? [String: Any] else { return nil }
        guard let updateId = int64(object["update_id"]) else { return nil }
        let message = object["message"] as? [String: Any]
        let chat = message?["chat"] as? [String: Any]
        let chatId = chatId(from: chat?["id"]) ?? ""
        return TelegramInboundUpdate(
            updateId: updateId,
            chatId: chatId,
            text: message?["text"] as? String
        )
    }

    static func chatId(from value: Any?) -> String? {
        if let string = value as? String {
            return NotifSecretsPayload.present(string)
        }
        if let n = int64(value) {
            return String(n)
        }
        return nil
    }

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
}
