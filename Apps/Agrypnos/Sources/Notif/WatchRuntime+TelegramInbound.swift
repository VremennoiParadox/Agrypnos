import AppKit
import Foundation

#if canImport(AgrypnosCore)
import AgrypnosCore
#endif

extension WatchRuntime {
    func telegramInboundIsPolling() -> Bool {
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
        if telegramInboundIsPolling() {
            store.saveTelegramInboundCursor(store.loadTelegramInboundCursor().startingWakeMiss())
        }
        if discordInboundIsReceiving() {
            store.saveDiscordInboundCursor(store.loadDiscordInboundCursor().startingWakeMiss())
        }
    }

    func noteMacDidWake() {
        inboundPoller.restartForWakeMiss()
        discordGateway.restartForWakeMiss()
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
                let agents = AgentProbeService.snapshot(
                    now: now,
                    freshness: engine.preferences.sessionFreshness
                )
                let battery = BatteryMonitor.reading()
                let safety = SafetyInputs(
                    batteryPercent: battery.percent,
                    onBatteryDischarging: battery.onBatteryDischarging,
                    thermalSerious: ThermalMonitor.isSerious(),
                    lowPowerMode: ProcessInfo.processInfo.isLowPowerModeEnabled
                )
                sendTelegramInboundReply(
                    TelegramInboundCopy.status(
                        engine.telegramWatchStatus(
                            now: now,
                            agentsBusy: agents.anyBusy(included: engine.preferences.includedAgentKinds),
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
        if TelegramInboundIntent.arm.shouldSetEngaged(currentlyEngaged: engine.engaged) == true {
            setEngaged(true)
        }
        let text = engine.engaged ? TelegramInboundCopy.armed : TelegramInboundCopy.armFailed
        sendTelegramInboundReply(text, token: token, chatId: chatId)
    }

    func applyTelegramDisarm(token: String?, chatId: String?) {
        pollLid()
        let confirmed = engine.lidCloseConfirmed
        if engine.engaged {
            setEngaged(false)
            if engine.engaged {
                sendTelegramInboundReply(TelegramInboundCopy.disarmFailed, token: token, chatId: chatId)
                return
            }
        } else {
            _ = disarmKernel()
        }
        if TelegramInboundDisarm.shouldRequestSleep(lidCloseConfirmed: confirmed) {
            apply([.requestSleep])
        }
        sendTelegramInboundReply(TelegramInboundCopy.disarmed, token: token, chatId: chatId)
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
