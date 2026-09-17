import Foundation
import Security

#if canImport(AgrypnosCore)
import AgrypnosCore
#endif

struct NotifSecrets: Equatable {
    var discordWebhookURL: String?
    var telegramBotToken: String?
    var telegramChatId: String?

    var isEmpty: Bool {
        discordWebhookURL == nil && telegramBotToken == nil && telegramChatId == nil
    }
}

/// Keychain only. One item so one Always Allow covers Discord + Telegram.
/// Never UserDefaults. Clear/remove deletes the entries.
enum NotifSecretsStore {
    static let service = "app.agrypnos.Agrypnos.notif"

    enum Account: String {
        case secrets
        case discordWebhookURL
        case telegramBotToken
        case telegramChatId
    }

    // Raw values match NotifClearChrome.deletedAccounts.

    static func load() -> NotifSecrets {
        var secrets = readBlob() ?? NotifSecrets()
        let legacy = readLegacy()
        guard !legacy.isEmpty else { return secrets }
        if secrets.discordWebhookURL == nil { secrets.discordWebhookURL = legacy.discordWebhookURL }
        if secrets.telegramBotToken == nil { secrets.telegramBotToken = legacy.telegramBotToken }
        if secrets.telegramChatId == nil { secrets.telegramChatId = legacy.telegramChatId }
        if writeBlob(secrets) {
            deleteLegacy()
        }
        return secrets
    }

    @discardableResult
    static func setDiscordWebhookURL(_ value: String?) -> Bool {
        var secrets = load()
        secrets.discordWebhookURL = NotifSecretsPayload.present(value)
        return writeBlob(secrets)
    }

    @discardableResult
    static func setTelegramBotToken(_ value: String?) -> Bool {
        var secrets = load()
        secrets.telegramBotToken = NotifSecretsPayload.present(value)
        return writeBlob(secrets)
    }

    @discardableResult
    static func setTelegramChatId(_ value: String?) -> Bool {
        var secrets = load()
        secrets.telegramChatId = NotifSecretsPayload.present(value)
        return writeBlob(secrets)
    }

    static func clear() {
        for account in NotifClearChrome.deletedAccounts {
            guard let item = Account(rawValue: account) else { continue }
            delete(item)
        }
    }

    static func readBlob() -> NotifSecrets? {
        guard let data = getData(.secrets) else { return nil }
        guard let payload = NotifSecretsPayload.decode(data) else { return nil }
        return NotifSecrets(
            discordWebhookURL: payload.discordWebhookURL,
            telegramBotToken: payload.telegramBotToken,
            telegramChatId: payload.telegramChatId
        )
    }

    static func readLegacy() -> NotifSecrets {
        NotifSecrets(
            discordWebhookURL: getString(.discordWebhookURL),
            telegramBotToken: getString(.telegramBotToken),
            telegramChatId: getString(.telegramChatId)
        )
    }

    @discardableResult
    static func writeBlob(_ secrets: NotifSecrets) -> Bool {
        let payload = NotifSecretsPayload(
            discordWebhookURL: secrets.discordWebhookURL,
            telegramBotToken: secrets.telegramBotToken,
            telegramChatId: secrets.telegramChatId
        )
        guard let data = NotifSecretsPayload.encode(payload) else { return false }
        guard setData(.secrets, data) else { return false }
        deleteLegacy()
        return true
    }

    static func deleteLegacy() {
        delete(.discordWebhookURL)
        delete(.telegramBotToken)
        delete(.telegramChatId)
    }

    static func getString(_ account: Account) -> String? {
        guard let data = getData(account) else { return nil }
        return NotifSecretsPayload.present(String(data: data, encoding: .utf8))
    }

    static func getData(_ account: Account) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account.rawValue,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var out: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &out)
        guard status == errSecSuccess else { return nil }
        return out as? Data
    }

    @discardableResult
    static func setData(_ account: Account, _ data: Data) -> Bool {
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
