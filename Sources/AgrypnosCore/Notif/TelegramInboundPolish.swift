import Foundation

public enum TelegramInboundDrain: Equatable, Sendable {
    /// Setup / quit / inbound off. Ack without applying. No reply.
    case leftover
    /// Commands that arrived while the Mac was asleep. Ack without applying. Missed reply.
    case wakeMiss
    /// Live poll. Apply arm/disarm/status/help.
    case live

    /// A still-seeded in-flight poll after sleep must not auto-apply.
    public static func effective(
        stored: TelegramInboundCursor,
        fetched: TelegramInboundCursor
    ) -> TelegramInboundDrain {
        if stored.drain == .wakeMiss { return .wakeMiss }
        return fetched.drain
    }
}

public enum TelegramInboundEffect: Equatable, Sendable {
    case ignore
    case missedWhileAsleep
    case apply(TelegramInboundIntent)
}

public enum TelegramInboundDispatch: Sendable {
    public static func effect(
        drain: TelegramInboundDrain,
        intent: TelegramInboundIntent
    ) -> TelegramInboundEffect {
        guard intent != .ignore else { return .ignore }
        switch drain {
        case .leftover:
            return .ignore
        case .wakeMiss:
            return .missedWhileAsleep
        case .live:
            return .apply(intent)
        }
    }
}

public enum TelegramInboundDisarm: Sendable {
    /// Sleep only on confirmed lid-close. Open or unconfirmed: clear hold, no sleep.
    public static func shouldRequestSleep(lidCloseConfirmed: Bool) -> Bool {
        lidCloseConfirmed
    }
}

public struct TelegramBotCommand: Equatable, Sendable {
    public var command: String
    public var description: String

    public init(command: String, description: String) {
        self.command = command
        self.description = description
    }
}

public enum TelegramBotCommandMenu: Sendable {
    public static let commands: [TelegramBotCommand] = [
        TelegramBotCommand(command: "arm", description: "Turn Keep the watch on."),
        TelegramBotCommand(
            command: "disarm",
            description: "Turn Keep the watch off. Sleeps the Mac only if the lid is closed."
        ),
        TelegramBotCommand(command: "status", description: "Dump live watch facts Agrypnos already knows."),
        TelegramBotCommand(command: "help", description: "Explain /arm, /disarm, /status, and /help."),
    ]
}
