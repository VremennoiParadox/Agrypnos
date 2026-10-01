import Foundation

#if canImport(AgrypnosCore)
import AgrypnosCore
#endif

extension WatchRuntime {
    func makeQuestionRelay() -> QuestionRelayCoordinator {
        QuestionRelayCoordinator(settings: { [weak self] in
            self?.questionRelaySettings() ?? QuestionRelaySettings(enabled: false, includedKinds: [], telegram: nil, discord: nil)
        }, transport: questionTransport, uptime: { [weak self] in self?.questionUptime() ?? 0 }, onChange: { [weak self] event in
            self?.questionRelayDidChange(event)
        })
    }

    func questionRelaySettings() -> QuestionRelaySettings {
        let secrets = readNotifSecrets()
        let telegram: TelegramQuestionDestination?
        if engine.preferences.telegramInboundEnabled,
           let token = secrets.telegramBotToken,
           let chatID = secrets.telegramChatId,
           let userID = secrets.telegramQuestionUserId {
            telegram = TelegramQuestionDestination(token: token, chatID: chatID, userID: userID)
        } else { telegram = nil }
        let discord: DiscordQuestionDestination?
        if engine.preferences.discordInboundEnabled,
           let token = secrets.discordBotToken,
           let channelID = secrets.discordChannelId,
           let userID = secrets.discordQuestionUserId {
            discord = DiscordQuestionDestination(token: token, channelID: channelID, userID: userID)
        } else { discord = nil }
        return QuestionRelaySettings(enabled: engine.preferences.forwardAgentQuestions,
            includedKinds: engine.preferences.includedAgentKinds, telegram: telegram, discord: discord)
    }

    func setForwardAgentQuestions(_ on: Bool) {
        guard on != engine.preferences.forwardAgentQuestions else { return }
        engine.preferences.forwardAgentQuestions = on
        clearQuestionWatch()
        store.save(engine.preferences)
        questionRelay.refreshSettings()
        syncQuestionSources()
        delegate?.watchRuntimeDidChange(self)
    }

    @discardableResult
    func setNotifTelegramQuestionUserId(_ value: String?) -> Bool {
        guard NotifSecretsPayload.present(value) != readNotifSecrets().telegramQuestionUserId else { return true }
        questionRelay.invalidateAll()
        let saved = NotifSecretsStore.setTelegramQuestionUserId(value)
        clearQuestionWatch()
        delegate?.watchRuntimeDidChange(self)
        return saved
    }

    @discardableResult
    func setNotifDiscordQuestionUserId(_ value: String?) -> Bool {
        guard NotifSecretsPayload.present(value) != readNotifSecrets().discordQuestionUserId else { return true }
        questionRelay.invalidateAll()
        let saved = NotifSecretsStore.setDiscordQuestionUserId(value)
        clearQuestionWatch()
        delegate?.watchRuntimeDidChange(self)
        return saved
    }
}

extension WatchRuntime {
    func questionRelayDidChange(_ event: QuestionRelayEvent) {
        switch event {
        case let .observed(key, deadline):
            if engine.engaged, questionUptime() < deadline { questionDeadlines[key] = deadline }
        case let .cleared(key):
            questionDeadlines.removeValue(forKey: key)
            questionNewlyExpired.remove(key)
            questionUnansweredKeys.remove(key)
            questionCleared.insert(key)
        case let .expired(key):
            guard questionDeadlines.removeValue(forKey: key) != nil else { return }
            questionNewlyExpired.insert(key)
            questionUnansweredKeys.insert(key)
        }
        if !evaluatingQuestionTick, ownsWakeHold, engine.engaged { poll() }
    }

    func questionWaitDecision(agents: AgentSnapshot, observeAgents: Bool) -> (QuestionWaitDecision, [String]) {
        guard engine.engaged else { return (.normal, []) }
        if !questionDeadlines.isEmpty {
            // Resolve shorter native lifetimes before the ten-minute watch decision.
            evaluatingQuestionTick = true
            questionRelay.expireDueQuestions()
            evaluatingQuestionTick = false
        }
        let decision = questionWaitPolicy.observe(pendingDeadlines: questionDeadlines,
            newlyExpired: questionNewlyExpired, cleared: questionCleared,
            now: questionUptime(),
            busy: observeAgents ? agents.anyBusy(included: engine.preferences.includedAgentKinds) : nil,
            grace: engine.preferences.agentSettleGrace)
        questionNewlyExpired.removeAll()
        questionCleared.removeAll()
        var notices: [String] = []
        for timeout in decision.timeouts where decision.action != .endUnanswered {
            let text: String
            switch timeout.reason {
            case .busy:
                text = "Question unanswered for 10 minutes; watch remains on because local busy signals are present."
            case .unknown:
                text = "Question unanswered for 10 minutes; watch remains on because agent activity could not be checked."
            case .anotherQuestion:
                text = "Question unanswered for 10 minutes; watch remains on while another question awaits an answer."
            case .idle:
                continue
            }
            let context = "\n\(timeout.key.provider.displayName) · session \(timeout.key.sessionID.prefix(80))"
            notices.append(text + context)
        }
        return (decision, notices)
    }

    func cancelQuestionSleep() {
        questionSleepGeneration &+= 1
        questionSleepTask?.cancel()
        questionSleepTask = nil
    }

    func clearQuestionWatch() {
        cancelQuestionSleep()
        questionRelay.invalidateAll()
        questionWaitPolicy.reset()
        questionDeadlines.removeAll()
        questionNewlyExpired.removeAll()
        questionUnansweredKeys.removeAll()
        questionCleared.removeAll()
        questionReleaseFailureReported = false
        stopQuestionSources()
        syncQuestionSources()
    }

    func resetQuestionWatchForNewArm() {
        clearQuestionWatch()
    }

    func attemptQuestionNotice(_ text: String) async {
        await withCheckedContinuation { continuation in
            let gate = QuestionNoticeGate(continuation)
            gate.sending = Task { [postQuestionNotice] in
                await postQuestionNotice(text)
                gate.finish()
            }
            gate.timeout = Task {
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                gate.finish()
            }
        }
    }
}
