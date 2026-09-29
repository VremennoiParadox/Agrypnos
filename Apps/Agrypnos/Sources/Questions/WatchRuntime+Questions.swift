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

    func questionRelayDidChange(_ event: QuestionRelayEvent) {
        // WatchEngine consumes these observations when native adapters are wired in Task 9.
        _ = event
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
