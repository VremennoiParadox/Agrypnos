import Foundation
import Security

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

    @discardableResult
    static func setDiscordWebhookURL(_ value: String?) -> Bool {
        set(.discordWebhookURL, value)
    }

    @discardableResult
    static func setTelegramBotToken(_ value: String?) -> Bool {
        set(.telegramBotToken, value)
    }

    @discardableResult
    static func setTelegramChatId(_ value: String?) -> Bool {
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

    @discardableResult
    static func set(_ account: Account, _ value: String?) -> Bool {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if trimmed.isEmpty {
            delete(account)
            return true
        }
        let data = Data(trimmed.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account.rawValue,
        ]
        let update: [String: Any] = [kSecValueData as String: data]
        let updated = SecItemUpdate(query as CFDictionary, update as CFDictionary)
        if updated == errSecSuccess { return true }
        guard updated == errSecItemNotFound else { return false }
        var add = query
        add[kSecValueData as String] = data
        add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        return SecItemAdd(add as CFDictionary, nil) == errSecSuccess
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
