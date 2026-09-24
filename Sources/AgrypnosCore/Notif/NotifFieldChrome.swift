import Foundation

public enum NotifFieldCommit: Equatable, Sendable {
    case persist(String)
    case clear
    case reject
}

public enum NotifDiscordFieldChrome: Sendable {
    public static func commit(_ raw: String) -> NotifFieldCommit {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
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

    public static func commit(_ raw: String) -> NotifFieldCommit {
        let trimmed = raw.replacingOccurrences(of: "\u{ff1a}", with: ":")
            .trimmingCharacters(in: .whitespacesAndNewlines)
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
    public static func commit(_ raw: String) -> NotifFieldCommit {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
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

public enum TelegramInboundChrome: Sendable {
    public static var defaultEnabled: Bool { UserPreferences.default.telegramInboundEnabled }
}

public enum SecretRevealChrome: Sendable {
    public static let buttonWidthPoints = 22
    public static let gapPoints = 4
    public static let fieldMinWidthPoints = 80

    public static func fieldWidth(total: Int) -> Int {
        max(total - buttonWidthPoints - gapPoints, fieldMinWidthPoints)
    }

    public static func nextRevealed(_ revealed: Bool) -> Bool { !revealed }

    public static func symbolName(revealed: Bool) -> String {
        revealed ? "eye.slash" : "eye"
    }
}

public enum NotifSecretsFileChrome: Sendable {
    public static let folderName = "Agrypnos"
    public static let fileName = "notif-secrets.json"
}
