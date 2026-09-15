import Foundation
import Security

#if canImport(AgrypnosCore)
import AgrypnosCore
#endif

struct NotifSecrets: Equatable {
    var discordWebhookURL: String?
    var telegramBotToken: String?
    var telegramChatId: String?
}

/// Keychain only. Never UserDefaults. Clear/remove deletes the entries.
enum NotifSecretsStore {
    static let service = "app.agrypnos.Agrypnos.notif"

    enum Account: String {
        case discordWebhookURL
        case telegramBotToken
        case telegramChatId
    }

    static func load() -> NotifSecrets {
        NotifSecrets(
            discordWebhookURL: get(.discordWebhookURL),
            telegramBotToken: get(.telegramBotToken),
            telegramChatId: get(.telegramChatId)
        )
    }

    static func setDiscordWebhookURL(_ value: String?) {
        set(.discordWebhookURL, value)
    }

    static func setTelegramBotToken(_ value: String?) {
        set(.telegramBotToken, value)
    }

    static func setTelegramChatId(_ value: String?) {
        set(.telegramChatId, value)
    }

    static func clear() {
        delete(.discordWebhookURL)
        delete(.telegramBotToken)
        delete(.telegramChatId)
    }

    static func get(_ account: Account) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account.rawValue,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var out: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &out)
        guard status == errSecSuccess, let data = out as? Data else { return nil }
        let trimmed = String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }

    static func set(_ account: Account, _ value: String?) {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if trimmed.isEmpty {
            delete(account)
            return
        }
        delete(account)
        let add: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account.rawValue,
            kSecValueData as String: Data(trimmed.utf8),
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        ]
        SecItemAdd(add as CFDictionary, nil)
    }

    static func delete(_ account: Account) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account.rawValue,
        ]
        SecItemDelete(query as CFDictionary)
    }
}
