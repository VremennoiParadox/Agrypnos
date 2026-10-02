import Foundation
#if canImport(AgrypnosCore)
import AgrypnosCore
#endif

extension WatchRuntime {
    var claudeSettingsURL: URL {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".claude/settings.json")
    }
    var claudeQuestionCaption: String {
        if let failure = claudeSetupFailure { return failure }
        if !preferences.forwardAgentQuestions { return "Claude Code: forwarding off." }
        if !preferences.includedAgentKinds.contains(.claudeCode) { return "Claude Code: select it in Agents first." }
        let relay = questionRelaySettings()
        if relay.telegram?.isComplete != true && relay.discord?.isComplete != true {
            return "Claude Code: enable bot inbound and save its answering user ID."
        }
        if preferences.claudeQuestionHookEnabled {
            return "Claude Code: hook installed. Interactive sessions hold hooks until you trust the folder."
        }
        return "Claude Code: click Enable Claude Code forwarding."
    }
    private var claudeSetupPrerequisite: String? {
        if questionSourcesTerminated || questionSourcesSuspended { return "Claude Code: forwarding is paused." }
        if !preferences.includedAgentKinds.contains(.claudeCode) { return "Claude Code: select it in Agents first." }
        let relay = questionRelaySettings()
        if relay.telegram?.isComplete != true && relay.discord?.isComplete != true {
            return "Claude Code: enable bot inbound and save its answering user ID."
        }
        return nil
    }
    private func claudeSetupFailed(_ text: String) -> Bool {
        claudeSetupFailure = text; notify(text); delegate?.watchRuntimeDidChange(self); return false
    }
    private func writeClaudeSettings(_ data: Data, to url: URL) throws {
        let directory = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let temp = directory.appendingPathComponent(url.lastPathComponent + ".tmp")
        try data.write(to: temp, options: .atomic)
        _ = try FileManager.default.replaceItemAt(url, withItemAt: temp)
    }
    func enableClaudeQuestionHook() async -> Bool {
        if let reason = claudeSetupPrerequisite { return claudeSetupFailed(reason) }
        do {
            let executable = Bundle.main.executableURL?.path ?? CommandLine.arguments[0]
            let quoted = executable.contains(" ") ? "\"\(executable)\"" : executable
            let command = quoted + " " + ClaudeAskUserQuestionPayload.flag
            let url = claudeSettingsURLOverride ?? claudeSettingsURL
            let existing = (try? Data(contentsOf: url)) ?? Data("{}".utf8)
            let merged = try ClaudeHookSettingsMerge.enable(settingsJSON: existing, command: command,
                timeoutSeconds: ClaudeAskUserQuestionPayload.commandTimeoutSeconds)
            try writeClaudeSettings(merged, to: url)
            engine.preferences.claudeQuestionHookEnabled = true
            engine.preferences.forwardAgentQuestions = true
            claudeSetupFailure = nil
            store.save(engine.preferences)
            questionRelay.refreshSettings()
            syncQuestionSources()
            delegate?.watchRuntimeDidChange(self)
            return true
        } catch {
            return claudeSetupFailed("Claude Code: couldn't merge ~/.claude/settings.json. Existing hooks were left as they were.")
        }
    }
    func disableClaudeQuestionHook() {
        let url = claudeSettingsURLOverride ?? claudeSettingsURL
        if let existing = try? Data(contentsOf: url),
           let stripped = try? ClaudeHookSettingsMerge.disable(settingsJSON: existing) {
            try? writeClaudeSettings(stripped, to: url)
        }
        engine.preferences.claudeQuestionHookEnabled = false
        claudeSetupFailure = nil
        store.save(engine.preferences)
        questionRelay.refreshSettings()
        syncQuestionSources()
        delegate?.watchRuntimeDidChange(self)
    }
}
