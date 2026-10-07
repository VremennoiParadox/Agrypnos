import Foundation
#if canImport(AgrypnosCore)
import AgrypnosCore
#endif

extension WatchRuntime {
    var codexHooksURL: URL {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".codex/hooks.json")
    }

    var codexAlertCaption: String {
        if let failure = codexSetupFailure { return failure }
        if preferences.codexAlertEnabled { return QuestionSetupChrome.codexTrustStatus }
        return QuestionSetupChrome.codexHelp
    }

    private func codexHasDestination() -> Bool {
        let secrets = readNotifSecrets()
        return !NotifIdlePostPolicy.destinations(
            discordWebhookURL: secrets.discordWebhookURL,
            telegramBotToken: secrets.telegramBotToken,
            telegramChatId: secrets.telegramChatId
        ).isEmpty
    }

    private func codexSetupFailed(_ text: String) -> Bool {
        codexSetupFailure = text
        notify(text)
        delegate?.watchRuntimeDidChange(self)
        return false
    }

    private func writeCodexHooks(_ data: Data, to url: URL) throws {
        let directory = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let temp = directory.appendingPathComponent(".\(url.lastPathComponent).tmp")
        if FileManager.default.fileExists(atPath: temp.path) {
            try FileManager.default.removeItem(at: temp)
        }
        try data.write(to: temp, options: .atomic)
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
    }

    func enableCodexAlerts() -> Bool {
        guard codexHasDestination() else {
            return codexSetupFailed("Save a Telegram chat or Discord webhook first.")
        }
        do {
            let executable = Bundle.main.executableURL?.path ?? CommandLine.arguments[0]
            let quoted = executable.contains(" ") ? "\"\(executable)\"" : executable
            let command = quoted + " " + CodexAlertHook.flag
            let url = codexHooksURLOverride ?? codexHooksURL
            let existing = (try? Data(contentsOf: url)) ?? Data()
            let merged = try CodexAlertHook.enable(hooksJSON: existing, command: command)
            try writeCodexHooks(merged, to: url)
            engine.preferences.codexAlertEnabled = true
            codexSetupFailure = nil
            store.save(engine.preferences)
            syncCodexAlerts()
            delegate?.watchRuntimeDidChange(self)
            return true
        } catch {
            return codexSetupFailed("Codex: couldn't merge ~/.codex/hooks.json. Existing hooks were left as they were.")
        }
    }

    func disableCodexAlerts() {
        let url = codexHooksURLOverride ?? codexHooksURL
        do {
            if FileManager.default.fileExists(atPath: url.path) {
                let existing = try Data(contentsOf: url)
                let stripped = try CodexAlertHook.disable(hooksJSON: existing)
                try writeCodexHooks(stripped, to: url)
            }
            stopCodexAlerts()
            engine.preferences.codexAlertEnabled = false
            codexSetupFailure = nil
            store.save(engine.preferences)
            delegate?.watchRuntimeDidChange(self)
        } catch {
            _ = codexSetupFailed("Codex: couldn't update ~/.codex/hooks.json. Existing hooks were left as they were.")
        }
    }

    func stopCodexAlerts() {
        codexAlertSource?.stop()
        codexAlertSource = nil
    }

    func syncCodexAlerts() {
        let want = !questionSourcesSuspended && !questionSourcesTerminated
            && preferences.codexAlertEnabled
            && codexHasDestination()
        if !want {
            stopCodexAlerts()
            return
        }
        if codexAlertSource != nil { return }
        let source = CodexAlertHookSource(
            socketURL: codexSocketURLOverride ?? CodexAlertHookProcess.defaultSocketURL(),
            receive: { [weak self] data in
                guard let self, let notice = CodexAlertHook.notice(data) else { return }
                self.codexPostedSentences.append(notice)
                guard !self.codexSuppressNetwork else { return }
                Task { await self.postCodexAlert(notice) }
            })
        do { try source.start(); codexAlertSource = source }
        catch { codexSetupFailure = "Codex: couldn't listen for the waiting alert." }
    }

    func postCodexAlert(_ sentence: String) async {
        let secrets = readNotifSecrets()
        let channels = NotifIdlePostPolicy.destinations(
            discordWebhookURL: secrets.discordWebhookURL,
            telegramBotToken: secrets.telegramBotToken,
            telegramChatId: secrets.telegramChatId
        )
        var requests: [NotifOutboundRequest] = []
        if channels.contains(.discord),
           let url = secrets.discordWebhookURL,
           let request = NotifOutboundRequestFactory.discord(webhookURL: url, content: sentence) {
            requests.append(request)
        }
        if channels.contains(.telegram),
           let token = secrets.telegramBotToken,
           let chat = secrets.telegramChatId,
           let request = NotifOutboundRequestFactory.telegram(botToken: token, chatId: chat, text: sentence) {
            requests.append(request)
        }
        await QuestionNoticeSender.deliver(requests)
    }
}
