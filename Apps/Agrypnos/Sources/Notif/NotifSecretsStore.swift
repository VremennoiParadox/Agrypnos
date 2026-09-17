import Foundation

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

/// Application Support file, mode 0600. Not Keychain (unsigned builds prompt for
/// the login password). Not UserDefaults.
enum NotifSecretsStore {
    static func load() -> NotifSecrets {
        guard let data = try? Data(contentsOf: fileURL()),
              let payload = NotifSecretsPayload.decode(data)
        else { return NotifSecrets() }
        return NotifSecrets(
            discordWebhookURL: payload.discordWebhookURL,
            telegramBotToken: payload.telegramBotToken,
            telegramChatId: payload.telegramChatId
        )
    }

    @discardableResult
    static func setDiscordWebhookURL(_ value: String?) -> Bool {
        var secrets = load()
        secrets.discordWebhookURL = NotifSecretsPayload.present(value)
        return write(secrets)
    }

    @discardableResult
    static func setTelegramBotToken(_ value: String?) -> Bool {
        var secrets = load()
        secrets.telegramBotToken = NotifSecretsPayload.present(value)
        return write(secrets)
    }

    @discardableResult
    static func setTelegramChatId(_ value: String?) -> Bool {
        var secrets = load()
        secrets.telegramChatId = NotifSecretsPayload.present(value)
        return write(secrets)
    }

    static func clear() {
        try? FileManager.default.removeItem(at: fileURL())
    }

    @discardableResult
    static func write(_ secrets: NotifSecrets) -> Bool {
        let payload = NotifSecretsPayload(
            discordWebhookURL: secrets.discordWebhookURL,
            telegramBotToken: secrets.telegramBotToken,
            telegramChatId: secrets.telegramChatId
        )
        guard let data = NotifSecretsPayload.encode(payload) else { return false }
        do {
            try FileManager.default.createDirectory(
                at: directoryURL(),
                withIntermediateDirectories: true
            )
            let url = fileURL()
            try data.write(to: url, options: .atomic)
            try FileManager.default.setAttributes(
                [.posixPermissions: 0o600],
                ofItemAtPath: url.path
            )
            return true
        } catch {
            return false
        }
    }

    static func directoryURL() -> URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(NotifSecretsFileChrome.folderName, isDirectory: true)
    }

    static func fileURL() -> URL {
        directoryURL().appendingPathComponent(NotifSecretsFileChrome.fileName)
    }
}
