import Foundation

#if canImport(AgrypnosCore)
import AgrypnosCore
#endif

extension WatchRuntime {
    func makeQuestionRelay() -> QuestionRelayCoordinator {
        QuestionRelayCoordinator(settings: { [weak self] in
            self?.questionRelaySettings() ?? QuestionRelaySettings(enabled: false, includedKinds: [], telegram: nil, discord: nil)
        }, transport: { request in await TelegramInboundHTTP.exchangeQuestion(request) }, onChange: { [weak self] event in
            self?.questionRelayDidChange(event)
        })
    }

    func questionRelaySettings() -> QuestionRelaySettings {
        let secrets = NotifSecretsStore.load()
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
        questionRelay.invalidateAll()
        engine.preferences.forwardAgentQuestions = on
        store.save(engine.preferences)
        questionRelay.refreshSettings()
        delegate?.watchRuntimeDidChange(self)
    }

    @discardableResult
    func setNotifTelegramQuestionUserId(_ value: String?) -> Bool {
        questionRelay.invalidateAll()
        let saved = NotifSecretsStore.setTelegramQuestionUserId(value)
        questionRelay.refreshSettings()
        delegate?.watchRuntimeDidChange(self)
        return saved
    }

    @discardableResult
    func setNotifDiscordQuestionUserId(_ value: String?) -> Bool {
        questionRelay.invalidateAll()
        let saved = NotifSecretsStore.setDiscordQuestionUserId(value)
        questionRelay.refreshSettings()
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
        if ownsWakeHold, engine.engaged { poll() }
    }

    func questionWaitDecision(agents: AgentSnapshot, observeAgents: Bool) -> QuestionWaitDecision {
        guard engine.engaged else { return .normal }
        let decision = questionWaitPolicy.observe(pendingDeadlines: questionDeadlines,
            newlyExpired: questionNewlyExpired, cleared: questionCleared,
            now: questionUptime(),
            busy: observeAgents ? agents.anyBusy(included: engine.preferences.includedAgentKinds) : nil,
            grace: engine.preferences.agentSettleGrace)
        questionNewlyExpired.removeAll()
        questionCleared.removeAll()
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
            Task { await attemptQuestionNotice(text + context) }
        }
        return decision
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
