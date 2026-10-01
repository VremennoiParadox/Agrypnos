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
        if readNotifSecrets().openCodeQuestions == nil { return "OpenCode: save a server connection below." }
        return openCodeQuestionState.caption
    }

    func syncQuestionSources() {
        guard !openCodeSetupInProgress else { return }
        let relay = questionRelaySettings()
        let settings = readNotifSecrets().openCodeQuestions
        guard !questionSourcesSuspended, !questionSourcesTerminated, relay.enabled,
              relay.includedKinds.contains(.openCode),
              relay.telegram?.isComplete == true || relay.discord?.isComplete == true else { stopQuestionSources(); return }
        if preferences.openCodePluginEnabled { syncOpenCodePlugin(relay: relay); return }
        guard let settings else { stopQuestionSources(); return }
        guard let configuration = try? OpenCodeQuestionConfiguration(settings) else {
            stopQuestionSources()
            openCodeQuestionState = .unavailable("Use http://127.0.0.1:PORT and an absolute project directory.")
            return
        }
        if openCodeSourceSettings == settings, openCodeRelaySettings == relay,
           openCodeQuestionSource != nil { return }
        stopQuestionSources()
        questionRelay.refreshSettings()
        openCodeSourceSettings = settings
        openCodeRelaySettings = relay
        let source = OpenCodeQuestionSource(configuration: configuration,
            exchange: openCodeQuestionExchange, streamSession: openCodeQuestionStreamSession,
            uptime: { [weak self] in self?.questionUptime() ?? 0 },
            receive: { [weak self] batch in
                guard let self, let source = self.openCodeQuestionSource else { return false }
                return self.questionRelay.receive(batch, submit: { [weak source] answer in
                    guard let source else { return .rejected }
                    return await source.submit(key: batch.key, answer: answer)
                }, returnLocal: { [weak source] in source?.returnToLocal(key: batch.key) })
            }, resolved: { [weak self] key in
                self?.questionRelay.cancel(key: key)
                // An answer made locally after remote expiry also clears its deferred end.
                self?.questionRelayDidChange(.cleared(key))
            }, stateChanged: { [weak self] state in
                self?.openCodeQuestionState = state
                if let self { self.delegate?.watchRuntimeDidChange(self) }
            })
        openCodeQuestionSource = source
        source.start()
    }

    func stopQuestionSources() {
        openCodeSetupRevision &+= 1
        stopOpenCodePlugin()
        let source = openCodeQuestionSource
        openCodeQuestionSource = nil
        openCodeSourceSettings = nil
        openCodeRelaySettings = nil
        source?.stop()
        openCodeQuestionState = .stopped
    }

    @discardableResult
    func setOpenCodeQuestionSettings(_ settings: OpenCodeQuestionSettings?) -> Bool {
        if let settings, (try? OpenCodeQuestionConfiguration(settings)) == nil { return false }
        let wasPlugin = preferences.openCodePluginEnabled
        if settings != nil { engine.preferences.openCodePluginEnabled = false }
        guard readNotifSecrets().openCodeQuestions != settings || wasPlugin else { return true }
        guard NotifSecretsStore.setOpenCodeQuestions(settings) else {
            engine.preferences.openCodePluginEnabled = wasPlugin; return false
        }
        openCodeSetupFailure = nil
        store.save(engine.preferences)
        clearQuestionWatch()
        delegate?.watchRuntimeDidChange(self)
        return true
    }
}
