import Foundation

#if canImport(AgrypnosCore)
import AgrypnosCore
#endif

struct NotifSecrets: Equatable {
    var discordWebhookURL: String?
    var telegramBotToken: String?
    var telegramChatId: String?
    var discordBotToken: String?
    var discordChannelId: String?
    var telegramQuestionUserId: String?
    var discordQuestionUserId: String?
    var openCodeQuestions: OpenCodeQuestionSettings?
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
            telegramChatId: payload.telegramChatId,
            discordBotToken: payload.discordBotToken,
            discordChannelId: payload.discordChannelId,
            telegramQuestionUserId: payload.telegramQuestionUserId,
            discordQuestionUserId: payload.discordQuestionUserId,
            openCodeQuestions: payload.openCodeQuestions
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

    @discardableResult
    static func setDiscordBotToken(_ value: String?) -> Bool {
        var secrets = load()
        secrets.discordBotToken = NotifSecretsPayload.present(value)
        return write(secrets)
    }

    @discardableResult
    static func setDiscordChannelId(_ value: String?) -> Bool {
        var secrets = load()
        secrets.discordChannelId = NotifSecretsPayload.present(value)
        return write(secrets)
    }

    @discardableResult
    static func setTelegramQuestionUserId(_ value: String?) -> Bool {
        var secrets = load()
        secrets.telegramQuestionUserId = NotifSecretsPayload.present(value)
        return write(secrets)
    }

    @discardableResult
    static func setDiscordQuestionUserId(_ value: String?) -> Bool {
        var secrets = load()
        secrets.discordQuestionUserId = NotifSecretsPayload.present(value)
        return write(secrets)
    }

    static func clear() {
        try? FileManager.default.removeItem(at: fileURL())
    }

    @discardableResult
    static func setOpenCodeQuestions(_ value: OpenCodeQuestionSettings?) -> Bool {
        var secrets = load()
        secrets.openCodeQuestions = value
        return write(secrets)
    }

    @discardableResult
    static func write(_ secrets: NotifSecrets) -> Bool {
        let payload = NotifSecretsPayload(
            discordWebhookURL: secrets.discordWebhookURL,
            telegramBotToken: secrets.telegramBotToken,
            telegramChatId: secrets.telegramChatId,
            discordBotToken: secrets.discordBotToken,
            discordChannelId: secrets.discordChannelId,
            telegramQuestionUserId: secrets.telegramQuestionUserId,
            discordQuestionUserId: secrets.discordQuestionUserId,
            openCodeQuestions: secrets.openCodeQuestions
        )
        guard let data = NotifSecretsPayload.encode(payload) else { return false }
        do {
            let dir = directoryURL()
            try FileManager.default.createDirectory(
                at: dir,
                withIntermediateDirectories: true
            )
            let url = fileURL()
            let temp = dir.appendingPathComponent(".\(NotifSecretsFileChrome.fileName).tmp")
            if FileManager.default.fileExists(atPath: temp.path) {
                try FileManager.default.removeItem(at: temp)
            }
            guard FileManager.default.createFile(
                atPath: temp.path,
                contents: data,
                attributes: [.posixPermissions: 0o600]
            ) else {
                return false
            }
            do {
                if FileManager.default.fileExists(atPath: url.path) {
                    _ = try FileManager.default.replaceItemAt(url, withItemAt: temp)
                } else {
                    try FileManager.default.moveItem(at: temp, to: url)
                }
            } catch {
                try? FileManager.default.removeItem(at: temp)
                throw error
            }
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
