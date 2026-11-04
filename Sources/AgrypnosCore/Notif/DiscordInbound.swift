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

    public static func slashIgnoreReply(source: DiscordInboundSource) -> String? {
        guard source == .slash else { return nil }
        return "That command was not applied."
    }

    static func channelMatches(saved: String?, incoming: String) -> Bool {
        guard let saved = NotifSecretsPayload.present(saved) else { return false }
        let incomingTrimmed = incoming.trimmingCharacters(in: .whitespacesAndNewlines)
        if saved == incomingTrimmed { return true }
        if let a = Int64(saved), let b = Int64(incomingTrimmed), a == b { return true }
        return false
    }
}

/// Deferred slash ACK can finish after wake. Stale generation must not apply arm/disarm.
public enum DiscordDeferredSlash: Sendable {
    public static func shouldApply(current: UInt64, captured: UInt64) -> Bool {
        TelegramInboundGeneration.allowsApply(current: current, captured: captured)
    }

    /// Drain captured when the frame was accepted. A later `.live` seed must not apply.
    public static func shouldApply(
        capturedDrain: TelegramInboundDrain,
        current: UInt64,
        captured: UInt64
    ) -> Bool {
        capturedDrain == .live && shouldApply(current: current, captured: captured)
    }

    /// Stale after wake: reply missed, do not arm/disarm.
    public static func shouldReplyMissedWhileAsleep(current: UInt64, captured: UInt64) -> Bool {
        !shouldApply(current: current, captured: captured)
    }

    public static func shouldReplyMissedWhileAsleep(
        capturedDrain: TelegramInboundDrain,
        current: UInt64,
        captured: UInt64
    ) -> Bool {
        switch capturedDrain {
        case .leftover:
            return false
        case .wakeMiss:
            return true
        case .live:
            return !shouldApply(current: current, captured: captured)
        }
    }

    public static func shouldApply(
        intent _: TelegramInboundIntent,
        current: UInt64,
        captured: UInt64
    ) -> Bool {
        shouldApply(current: current, captured: captured)
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
    public static func armed(duration: DurationOption) -> String {
        TelegramInboundCopy.armed(duration: duration)
    }
    public static func disarmed(wasEngaged: Bool, sleepRequested: Bool) -> String {
        TelegramInboundCopy.disarmed(wasEngaged: wasEngaged, sleepRequested: sleepRequested)
    }
    public static let missedWhileAsleep = TelegramInboundCopy.missedWhileAsleep
    public static let commandsHelp = "Commands on your Discord bot: /arm, /disarm, /status, /help."
    public static let help = """
    /arm: turn Keep awake on.
    /disarm: turn Keep awake off. With the lid open the Mac stays awake. With the lid confirmed closed it also goes to sleep, even if Keep awake was already off.
    /status: what Agrypnos knows right now. Keep awake, How long, time left on a timer, lid, panel mode, agent activity in Agents mode, when Keep awake last turned off and why, live battery when known, and your safety settings.
    /help: this list.

    No reply usually means the Mac is asleep, or Agrypnos isn't receiving updates. Commands sent in the meantime don't run when it wakes. You get "Missed while asleep." instead.
    """

    public static func reply(
        intent: TelegramInboundIntent,
        engaged: Bool,
        duration: DurationOption
    ) -> String? {
        switch intent {
        case .ignore, .status: return nil
        case .arm: return armed(duration: duration)
        case .disarm: return disarmed(wasEngaged: engaged, sleepRequested: false)
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
        case .arm: return armed(duration: snapshot.duration)
        case .disarm: return disarmed(wasEngaged: snapshot.engaged, sleepRequested: false)
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
