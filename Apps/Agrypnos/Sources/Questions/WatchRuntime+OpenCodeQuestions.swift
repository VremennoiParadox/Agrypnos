import Foundation

#if canImport(AgrypnosCore)
import AgrypnosCore
#endif

extension WatchRuntime {
    var openCodeQuestionCaption: String {
        if let failure = openCodeSetupFailure { return failure }
        if !preferences.forwardAgentQuestions { return "OpenCode: forwarding off." }
        if questionSourcesSuspended { return "OpenCode: paused while the Mac sleeps." }
        if !preferences.includedAgentKinds.contains(.openCode) { return "OpenCode: select it in Agents first." }
        let relay = questionRelaySettings()
        if relay.telegram?.isComplete != true && relay.discord?.isComplete != true {
            return "OpenCode: enable bot inbound and save its answering user ID."
        }
        if preferences.openCodePluginEnabled {
            let count = openCodePluginSource?.connectedCount ?? 0
            if count > 0 { return "OpenCode 1.18.32: connected (\(count) terminal\(count == 1 ? "" : "s"))." }
            return "OpenCode: installed, waiting. Restart OpenCode once to load forwarding."
        }
        return "OpenCode: forwarding is not installed."
    }

    func syncQuestionSources() {
        guard !openCodeSetupInProgress else { return }
        syncOpenCodeQuestionSources()
        syncClaudeQuestionHook()
        syncCodexAlerts()
    }

    func syncOpenCodeQuestionSources() {
        let relay = questionRelaySettings()
        guard !questionSourcesSuspended, !questionSourcesTerminated, relay.enabled,
              preferences.openCodePluginEnabled,
              relay.includedKinds.contains(.openCode),
              relay.telegram?.isComplete == true || relay.discord?.isComplete == true else {
            stopOpenCodeQuestionSources(); return
        }
        syncOpenCodePlugin(relay: relay)
    }

    func stopOpenCodeQuestionSources() {
        openCodeSetupRevision &+= 1
        stopOpenCodePlugin()
        openCodeRelaySettings = nil
    }

    func stopQuestionSources() {
        stopOpenCodeQuestionSources()
        stopClaudeQuestionHook()
        stopCodexAlerts()
    }

}
