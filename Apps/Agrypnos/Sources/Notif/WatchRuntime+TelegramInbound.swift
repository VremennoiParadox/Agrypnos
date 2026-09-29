import AppKit
import Foundation

#if canImport(AgrypnosCore)
import AgrypnosCore
#endif

extension WatchRuntime {
    func telegramInboundIsPolling() -> Bool {
        guard engine.preferences.telegramInboundEnabled else { return false }
        let secrets = NotifSecretsStore.load()
        return TelegramInboundPolicy.shouldPoll(
            enabled: engine.preferences.telegramInboundEnabled,
            botToken: secrets.telegramBotToken,
            chatId: secrets.telegramChatId
        )
    }

    func beginTelegramInboundPollSession() {
        store.saveTelegramInboundCursor(store.loadTelegramInboundCursor().startingSession())
    }

    func beginTelegramInboundWakeMissSession() {
        store.saveTelegramInboundCursor(store.loadTelegramInboundCursor().startingWakeMiss())
    }

    func noteMacWillSleep() {
        WatchDiagnostics.event("lifecycle willSleep")
        invalidateAgentProbe()
        clearQuestionWatch()
        if telegramInboundIsPolling() {
            store.saveTelegramInboundCursor(store.loadTelegramInboundCursor().startingWakeMiss())
        }
        if discordInboundIsReceiving() {
            store.saveDiscordInboundCursor(store.loadDiscordInboundCursor().startingWakeMiss())
            discordGateway.bumpSlashEpoch()
        }
    }

    func noteMacDidWake() {
        WatchDiagnostics.event("lifecycle didWake")
        invalidateAgentProbe()
        inboundPoller.restartForWakeMiss()
        discordGateway.restartForWakeMiss()
        poll()
    }

    func telegramInboundPollSnapshot() -> TelegramInboundPollSnapshot {
        let secrets = NotifSecretsStore.load()
        return TelegramInboundPollSnapshot(
            enabled: engine.preferences.telegramInboundEnabled,
            token: secrets.telegramBotToken,
            chatId: secrets.telegramChatId,
            cursor: store.loadTelegramInboundCursor()
        )
    }

    func registerTelegramBotCommands() {
        let secrets = NotifSecretsStore.load()
        guard telegramInboundIsPolling(), let token = secrets.telegramBotToken else { return }
        guard let request = NotifOutboundRequestFactory.telegramSetMyCommands(botToken: token) else { return }
        Task { await TelegramInboundHTTP.send(request) }
    }

    func finishTelegramInboundPoll(
        generation: UInt64,
        fetchedToken: String?,
        cursor: TelegramInboundCursor,
        updates: [TelegramInboundUpdate]
    ) {
        guard inboundPoller.accepts(generation: generation) else { return }
        let secrets = NotifSecretsStore.load()
        guard TelegramInboundPolicy.sameBot(
            fetchedToken: fetchedToken,
            currentToken: secrets.telegramBotToken
        ) else { return }
        let stored = store.loadTelegramInboundCursor()
        let drain = TelegramInboundDrain.effective(stored: stored, fetched: cursor)
        applyTelegramUpdates(updates, drain: drain)
        store.saveTelegramInboundCursor(cursor.acknowledging(updates))
    }

    func applyTelegramUpdates(_ updates: [TelegramInboundUpdate], drain: TelegramInboundDrain) {
        let secrets = NotifSecretsStore.load()
        let enabled = engine.preferences.telegramInboundEnabled
        for update in updates {
            if update.isCallback {
                if let callback = update.callback { questionRelay.handleTelegram(callback, drain: drain) }
                continue
            }
            let intent = TelegramInboundPolicy.intent(
                enabled: enabled,
                botToken: secrets.telegramBotToken,
                savedChatId: secrets.telegramChatId,
                update: update
            )
            switch TelegramInboundDispatch.effect(drain: drain, intent: intent) {
            case .ignore:
                continue
            case .missedWhileAsleep:
                sendTelegramInboundReply(
                    TelegramInboundCopy.missedWhileAsleep,
                    token: secrets.telegramBotToken,
                    chatId: secrets.telegramChatId
                )
            case .apply(.help):
                sendTelegramInboundReply(
                    TelegramInboundCopy.help,
                    token: secrets.telegramBotToken,
                    chatId: secrets.telegramChatId
                )
            case .apply(.status):
                pollLid()
                let now = Date()
                let agentsBusy = cachedAgentsBusy(now: now)
                let safety = liveStatusSafety()
                sendTelegramInboundReply(
                    TelegramInboundCopy.status(
                        engine.telegramWatchStatus(
                            now: now,
                            agentsBusy: agentsBusy,
                            lowPowerMode: safety.lowPowerMode,
                            safety: safety
                        ),
                        now: now
                    ),
                    token: secrets.telegramBotToken,
                    chatId: secrets.telegramChatId
                )
            case .apply(.arm):
                applyTelegramArm(
                    token: secrets.telegramBotToken,
                    chatId: secrets.telegramChatId
                )
            case .apply(.disarm):
                applyTelegramDisarm(
                    token: secrets.telegramBotToken,
                    chatId: secrets.telegramChatId
                )
            case .apply(.ignore):
                continue
            }
        }
    }

    func applyTelegramArm(token: String?, chatId: String?) {
        if TelegramInboundIntent.arm.shouldSetEngaged(currentlyEngaged: engaged) == true {
            setEngaged(true)
        }
        let text = engaged ? TelegramInboundCopy.armed : TelegramInboundCopy.armFailed
        sendTelegramInboundReply(text, token: token, chatId: chatId)
    }

    func applyTelegramDisarm(token: String?, chatId: String?) {
        guard let sleepResult = disarmWatch() else {
            sendTelegramInboundReply(TelegramInboundCopy.disarmFailed, token: token, chatId: chatId)
            return
        }
        sendTelegramInboundReply(
            inboundDisarmReply(TelegramInboundCopy.disarmed, sleepResult: sleepResult),
            token: token,
            chatId: chatId
        )
    }

    func sendTelegramInboundReply(_ text: String, token: String?, chatId: String?) {
        guard
            let token,
            let chatId,
            let request = NotifOutboundRequestFactory.telegram(
                botToken: token,
                chatId: chatId,
                text: text
            )
        else { return }
        Task { await TelegramInboundHTTP.send(request) }
    }
}
