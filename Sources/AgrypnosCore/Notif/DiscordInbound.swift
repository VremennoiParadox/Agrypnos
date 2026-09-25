import Foundation

public enum DiscordInboundSource: Equatable, Sendable {
    case message
    case slash
}

public struct DiscordInboundUpdate: Equatable, Sendable {
    public var channelId: String
    public var text: String?
    public var interactionId: String?
    public var interactionToken: String?
    public var source: DiscordInboundSource

    public init(
        channelId: String,
        text: String?,
        interactionId: String? = nil,
        interactionToken: String? = nil,
        source: DiscordInboundSource = .message
    ) {
        self.channelId = channelId
        self.text = text
        self.interactionId = interactionId
        self.interactionToken = interactionToken
        self.source = source
    }
}

public enum DiscordInboundPolicy: Sendable {
    public static func shouldReceive(
        enabled: Bool,
        botToken: String?,
        channelId: String?
    ) -> Bool {
        enabled
            && NotifSecretsPayload.present(botToken) != nil
            && NotifSecretsPayload.present(channelId) != nil
    }

    public static func intent(
        enabled: Bool,
        botToken: String?,
        savedChannelId: String?,
        update: DiscordInboundUpdate
    ) -> TelegramInboundIntent {
        guard shouldReceive(enabled: enabled, botToken: botToken, channelId: savedChannelId) else {
            return .ignore
        }
        guard channelMatches(saved: savedChannelId, incoming: update.channelId) else {
            return .ignore
        }
        guard let text = update.text else { return .ignore }
        return TelegramInboundCommand.parse(text)?.intent ?? .ignore
    }

    public static func sameBot(fetchedToken: String?, currentToken: String?) -> Bool {
        NotifSecretsPayload.present(fetchedToken) != nil
            && NotifSecretsPayload.present(fetchedToken) == NotifSecretsPayload.present(currentToken)
    }

    static func channelMatches(saved: String?, incoming: String) -> Bool {
        guard let saved = NotifSecretsPayload.present(saved) else { return false }
        let incomingTrimmed = incoming.trimmingCharacters(in: .whitespacesAndNewlines)
        if saved == incomingTrimmed { return true }
        if let a = Int64(saved), let b = Int64(incomingTrimmed), a == b { return true }
        return false
    }
}

/// Gateway resume cursor. Unseeded first receive acks without running commands.
public struct DiscordInboundCursor: Equatable, Sendable {
    public var sessionId: String?
    public var sequence: Int64?
    public var seeded: Bool
    public var wakeMiss: Bool
    public var resumeGatewayURL: String?

    public static let unset = DiscordInboundCursor(
        sessionId: nil,
        sequence: nil,
        seeded: false,
        wakeMiss: false
    )

    public init(
        sessionId: String?,
        sequence: Int64?,
        seeded: Bool,
        wakeMiss: Bool = false,
        resumeGatewayURL: String? = nil
    ) {
        self.sessionId = NotifSecretsPayload.present(sessionId)
        self.sequence = sequence
        self.seeded = seeded
        self.wakeMiss = seeded ? false : wakeMiss
        self.resumeGatewayURL = NotifSecretsPayload.present(resumeGatewayURL)
    }

    public var shouldApplyCommands: Bool { seeded }

    public var drain: TelegramInboundDrain {
        if seeded { return .live }
        return wakeMiss ? .wakeMiss : .leftover
    }

    public var canResume: Bool { sessionId != nil && sequence != nil }

    /// Setup / quit / inbound off: keep resume state, skip leftover commands once, silent.
    public func startingSession() -> DiscordInboundCursor {
        DiscordInboundCursor(
            sessionId: sessionId,
            sequence: sequence,
            seeded: false,
            wakeMiss: false,
            resumeGatewayURL: resumeGatewayURL
        )
    }

    /// Sleep wake: drain queued Gateway events without applying, then reply missed-while-asleep.
    public func startingWakeMiss() -> DiscordInboundCursor {
        DiscordInboundCursor(
            sessionId: sessionId,
            sequence: sequence,
            seeded: false,
            wakeMiss: true,
            resumeGatewayURL: resumeGatewayURL
        )
    }

    /// Advance `s` during Resume replay without seeding live. Seed only after READY or RESUMED.
    public func recording(
        sequence: Int64?,
        sessionId: String? = nil,
        resumeGatewayURL: String? = nil
    ) -> DiscordInboundCursor {
        DiscordInboundCursor(
            sessionId: sessionId ?? self.sessionId,
            sequence: sequence ?? self.sequence,
            seeded: seeded,
            wakeMiss: wakeMiss,
            resumeGatewayURL: resumeGatewayURL ?? self.resumeGatewayURL
        )
    }

    public func acknowledging(
        sequence: Int64?,
        sessionId: String? = nil,
        resumeGatewayURL: String? = nil
    ) -> DiscordInboundCursor {
        DiscordInboundCursor(
            sessionId: sessionId ?? self.sessionId,
            sequence: sequence ?? self.sequence,
            seeded: true,
            wakeMiss: false,
            resumeGatewayURL: resumeGatewayURL ?? self.resumeGatewayURL
        )
    }

    public func invalidatingSession(resumable: Bool) -> DiscordInboundCursor {
        if resumable {
            return DiscordInboundCursor(
                sessionId: sessionId,
                sequence: sequence,
                seeded: seeded,
                wakeMiss: wakeMiss,
                resumeGatewayURL: resumeGatewayURL
            )
        }
        return DiscordInboundCursor(
            sessionId: nil,
            sequence: nil,
            seeded: false,
            wakeMiss: wakeMiss
        )
    }
}

public enum DiscordInboundCopy: Sendable {
    public static let armed = TelegramInboundCopy.armed
    public static let disarmed = TelegramInboundCopy.disarmed
    public static let missedWhileAsleep = TelegramInboundCopy.missedWhileAsleep
    public static let commandsHelp = "Commands on your Discord bot: /arm, /disarm, /status, /help."
    public static let help = """
    /arm — turn Keep the watch on.
    /disarm — turn Keep the watch off. Always clears Keep the watch. Puts the Mac to sleep only when the lid is closed (confirmed). Never sleeps the Mac when the lid is open.
    /status — watch facts Agrypnos already knows: Keep the watch, How long, lid, Agents, last end, and safety prefs. Includes live battery when known. Not a remaining-time countdown.
    /help — this list.
    If the bot does not reply, the Mac is likely asleep or Agrypnos is not receiving updates.
    """

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
        case .status: return TelegramInboundCopy.status(snapshot, now: now, calendar: calendar, locale: locale)
        case .help: return help
        }
    }
}

public enum DiscordBotCommandMenu: Sendable {
    public static let commands: [TelegramBotCommand] = TelegramBotCommandMenu.commands
}

public enum DiscordInboundCursorCodec: Sendable {
    public static func encode(_ cursor: DiscordInboundCursor) -> Data {
        var object: [String: Any] = [
            "seeded": cursor.seeded,
            "wakeMiss": cursor.wakeMiss,
        ]
        if let sessionId = cursor.sessionId { object["sessionId"] = sessionId }
        if let sequence = cursor.sequence { object["sequence"] = NSNumber(value: sequence) }
        if let url = cursor.resumeGatewayURL { object["resumeGatewayURL"] = url }
        return (try? JSONSerialization.data(withJSONObject: object)) ?? Data("{}".utf8)
    }

    public static func decode(_ data: Data?) -> DiscordInboundCursor {
        guard let data,
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            return .unset
        }
        return DiscordInboundCursor(
            sessionId: object["sessionId"] as? String,
            sequence: DiscordJSON.int64(object["sequence"]),
            seeded: DiscordJSON.bool(object["seeded"]),
            wakeMiss: DiscordJSON.bool(object["wakeMiss"]),
            resumeGatewayURL: object["resumeGatewayURL"] as? String
        )
    }
}
