import Foundation

/// Cmd+V in the popover used to insert the clipboard twice.
public enum PastedSecretChrome: Sendable {
    public static let minimumOnceCount = 8

    public static func once(_ raw: String) -> String {
        guard raw.count >= minimumOnceCount, raw.count.isMultiple(of: 2) else {
            return raw
        }
        let mid = raw.index(raw.startIndex, offsetBy: raw.count / 2)
        let left = String(raw[..<mid])
        let right = String(raw[mid...])
        return left == right ? left : raw
    }
}

public enum NotifDiscordFieldCommit: Equatable, Sendable {
    case persist(String)
    case clear
    case reject
}

public enum NotifDiscordFieldChrome: Sendable {
    public static func commit(_ raw: String) -> NotifDiscordFieldCommit {
        let trimmed = PastedSecretChrome.once(
            raw.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        if trimmed.isEmpty { return .clear }
        guard let url = DiscordWebhookURL.parse(trimmed) else { return .reject }
        return .persist(url.absoluteString)
    }
}

public enum NotifOptionalSecretChrome: Sendable {
    public static func commit(_ raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

public enum TelegramBotTokenChrome: Sendable {
    public static let secretMinimumCount = 20

    static let tokenPattern = try! NSRegularExpression(
        pattern: "[0-9]+:[A-Za-z0-9_-]{\(secretMinimumCount),}"
    )

    public static func commit(_ raw: String) -> NotifDiscordFieldCommit {
        let trimmed = PastedSecretChrome.once(
            raw.replacingOccurrences(of: "\u{ff1a}", with: ":")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        )
        if trimmed.isEmpty { return .clear }
        let ns = trimmed as NSString
        let matches = tokenPattern.matches(
            in: trimmed,
            range: NSRange(location: 0, length: ns.length)
        )
        guard let match = matches.max(by: { $0.range.length < $1.range.length }) else {
            return .reject
        }
        return .persist(ns.substring(with: match.range))
    }
}

public enum TelegramChatIdChrome: Sendable {
    public static func commit(_ raw: String) -> NotifDiscordFieldCommit {
        let trimmed = PastedSecretChrome.once(
            raw.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        if trimmed.isEmpty { return .clear }
        guard isChatId(trimmed) else { return .reject }
        return .persist(trimmed)
    }

    static func isChatId(_ trimmed: String) -> Bool {
        let digits = trimmed.hasPrefix("-") ? String(trimmed.dropFirst()) : trimmed
        guard !digits.isEmpty,
              digits.unicodeScalars.allSatisfy({
                  $0.isASCII && CharacterSet.decimalDigits.contains($0)
              }),
              Int64(trimmed) != nil
        else {
            return false
        }
        return true
    }
}

public enum NotifEnableChrome: Sendable {
    public static var defaultEnabled: Bool { UserPreferences.default.notifEnabled }
}

public enum NotifClearChrome: Sendable {
    public static let deletedAccounts = [
        "secrets",
        "discordWebhookURL",
        "telegramBotToken",
        "telegramChatId",
    ]
}

public enum NotifSecretStoreAction: Equatable, Sendable {
    case persist(String)
    case skip
    case reject
}

/// Empty Notif fields on tab leave / end-editing must not delete Keychain secrets.
/// Clear secrets is the delete path. Unsaved draft stays in the field when store is empty.
public enum NotifSecretLeaveChrome: Sendable {
    public static func storeAction(_ commit: NotifDiscordFieldCommit) -> NotifSecretStoreAction {
        switch commit {
        case .persist(let value): return .persist(value)
        case .clear: return .skip
        case .reject: return .reject
        }
    }

    public static func storeAction(_ trimmed: String?) -> NotifSecretStoreAction {
        guard let trimmed else { return .skip }
        return .persist(trimmed)
    }

    public static func displayed(stored: String?, field: String) -> String {
        stored ?? field
    }
}
