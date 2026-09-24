import Foundation

public enum TelegramInboundIntent: Equatable, Sendable {
    case ignore
    case arm
    case disarm
    case status
    case help

    /// Shared Mac + Core decision. nil means do not call WatchEngine engage.
    public func shouldSetEngaged(currentlyEngaged: Bool) -> Bool? {
        switch self {
        case .arm:
            return currentlyEngaged ? nil : true
        case .disarm:
            return currentlyEngaged ? false : nil
        case .ignore, .status, .help:
            return nil
        }
    }
}

public enum TelegramInboundCommand: Equatable, Sendable {
    case arm
    case disarm
    case status
    case help

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
        case "help": return .help
        default: return nil
        }
    }

    var intent: TelegramInboundIntent {
        switch self {
        case .arm: return .arm
        case .disarm: return .disarm
        case .status: return .status
        case .help: return .help
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

public enum TelegramInboundPoll: Sendable {
    public static let drainSeconds = 0
    public static let longPollSeconds = 25
}

/// `getUpdates` offset plus a one-shot backlog drain. Unseeded first poll acks without running commands.
public struct TelegramInboundCursor: Equatable, Sendable {
    public var offset: Int64
    public var seeded: Bool
    public var wakeMiss: Bool

    public static let unset = TelegramInboundCursor(offset: 0, seeded: false, wakeMiss: false)

    public init(offset: Int64, seeded: Bool, wakeMiss: Bool = false) {
        self.offset = max(0, offset)
        self.seeded = seeded
        self.wakeMiss = seeded ? false : wakeMiss
    }

    public var shouldApplyCommands: Bool { seeded }

    public var drain: TelegramInboundDrain {
        if seeded { return .live }
        return wakeMiss ? .wakeMiss : .leftover
    }

    /// Drain poll is timeout 0 so a live first command after start is not swallowed by a long-poll.
    public var pollTimeout: Int {
        seeded ? TelegramInboundPoll.longPollSeconds : TelegramInboundPoll.drainSeconds
    }

    /// Setup / quit / inbound off: keep the offset, skip leftover commands once, silent.
    public func startingSession() -> TelegramInboundCursor {
        TelegramInboundCursor(offset: offset, seeded: false, wakeMiss: false)
    }

    /// Sleep wake: drain queued commands without applying, then reply missed-while-asleep.
    public func startingWakeMiss() -> TelegramInboundCursor {
        TelegramInboundCursor(offset: offset, seeded: false, wakeMiss: true)
    }

    public func acknowledging(_ updates: [TelegramInboundUpdate]) -> TelegramInboundCursor {
        TelegramInboundCursor(
            offset: TelegramInboundOffset.next(current: offset, updates: updates),
            seeded: true,
            wakeMiss: false
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
    public static let missedWhileAsleep = "Missed while asleep."
    public static let help = """
    /arm — turn Keep the watch on.
    /disarm — turn Keep the watch off. Always clears Keep the watch. Puts the Mac to sleep only when the lid is closed (confirmed). Never sleeps the Mac when the lid is open.
    /status — watch facts Agrypnos already knows: Keep the watch, How long, lid, Agents, last end, and safety prefs. Includes live battery when known. Not a remaining-time countdown.
    /help — this list.
    If the bot does not reply, the Mac is likely asleep or Agrypnos is not polling.
    """

    public static func status(
        _ snapshot: TelegramWatchStatus,
        now: Date,
        calendar: Calendar = .current,
        locale: Locale? = nil
    ) -> String {
        TelegramWatchStatusCopy.reply(snapshot, now: now, calendar: calendar, locale: locale)
    }

    public static func reply(
        intent: TelegramInboundIntent,
        engaged _: Bool,
        duration _: DurationOption
    ) -> String? {
        switch intent {
        case .ignore, .status: return nil
        case .arm: return armed
        case .disarm: return disarmed
        case .help: return help
        }
    }

    public static func reply(
        intent: TelegramInboundIntent,
        status snapshot: TelegramWatchStatus,
        now: Date,
        calendar: Calendar = .current,
        locale: Locale? = nil
    ) -> String? {
        switch intent {
        case .ignore: return nil
        case .arm: return armed
        case .disarm: return disarmed
        case .status: return status(snapshot, now: now, calendar: calendar, locale: locale)
        case .help: return help
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
