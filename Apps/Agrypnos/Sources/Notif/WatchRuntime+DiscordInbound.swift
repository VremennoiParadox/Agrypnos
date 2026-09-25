import AppKit
import Foundation

#if canImport(AgrypnosCore)
import AgrypnosCore
#endif

extension WatchRuntime {
    func inboundNeedsLid() -> Bool {
        telegramInboundIsPolling() || discordInboundIsReceiving()
    }

    func discordInboundIsReceiving() -> Bool {
        let secrets = NotifSecretsStore.load()
        return DiscordInboundPolicy.shouldReceive(
            enabled: engine.preferences.discordInboundEnabled,
            botToken: secrets.discordBotToken,
            channelId: secrets.discordChannelId
        )
    }

    func beginDiscordInboundSession() {
        store.saveDiscordInboundCursor(store.loadDiscordInboundCursor().startingSession())
    }

    func beginDiscordInboundWakeMissSession() {
        store.saveDiscordInboundCursor(store.loadDiscordInboundCursor().startingWakeMiss())
    }

    func discordInboundSnapshot() -> DiscordInboundSnapshot {
        let secrets = NotifSecretsStore.load()
        return DiscordInboundSnapshot(
            enabled: engine.preferences.discordInboundEnabled,
            token: secrets.discordBotToken,
            channelId: secrets.discordChannelId,
            cursor: store.loadDiscordInboundCursor()
        )
    }

    func handleDiscordGatewayFrame(
        _ frame: DiscordGatewayFrame,
        generation: UInt64
    ) -> [DiscordGatewayEffect] {
        guard discordGateway.accepts(generation: generation) else { return [] }
        let secrets = NotifSecretsStore.load()
        guard DiscordInboundPolicy.sameBot(
            fetchedToken: secrets.discordBotToken,
            currentToken: secrets.discordBotToken
        ) else { return [] }
        var session = DiscordGatewaySession(cursor: store.loadDiscordInboundCursor())
        let effects = session.handle(frame)
        store.saveDiscordInboundCursor(session.cursor)
        return effects
    }

    func registerDiscordBotCommands(applicationId: String?) {
        let secrets = NotifSecretsStore.load()
        guard discordInboundIsReceiving(), let token = secrets.discordBotToken else { return }
        Task {
            var appId = applicationId
            if let request = DiscordInboundRequestFactory.currentApplication(botToken: token),
               let data = await TelegramInboundHTTP.fetch(request),
               let parsed = DiscordApplicationParser.id(from: data)
            {
                appId = parsed
            }
            guard let appId,
                  let put = DiscordInboundRequestFactory.bulkOverwriteCommands(
                      botToken: token,
                      applicationId: appId
                  )
            else { return }
            await TelegramInboundHTTP.send(put)
        }
    }

    func applyDiscordInbound(_ update: DiscordInboundUpdate) {
        let drain = store.loadDiscordInboundCursor().drain
        let secrets = NotifSecretsStore.load()
        let enabled = engine.preferences.discordInboundEnabled
        let intent = DiscordInboundPolicy.intent(
            enabled: enabled,
            botToken: secrets.discordBotToken,
            savedChannelId: secrets.discordChannelId,
            update: update
        )
        let effect = TelegramInboundDispatch.effect(drain: drain, intent: intent)
        let reply: String?
        switch effect {
        case .ignore:
            reply = update.source == .slash ? "\u{200b}" : nil
        case .missedWhileAsleep:
            reply = DiscordInboundCopy.missedWhileAsleep
        case .apply(.help):
            reply = DiscordInboundCopy.help
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
            reply = DiscordInboundCopy.reply(
                intent: .status,
                status: engine.telegramWatchStatus(
                    now: now,
                    agentsBusy: agents.anyBusy(included: engine.preferences.includedAgentKinds),
                    lowPowerMode: safety.lowPowerMode,
                    safety: safety
                ),
                now: now
            )
        case .apply(.arm):
            reply = applyDiscordArm()
        case .apply(.disarm):
            reply = applyDiscordDisarm()
        case .apply(.ignore):
            reply = update.source == .slash ? "\u{200b}" : nil
        }
        if let reply {
            sendDiscordInboundReply(reply, update: update, token: secrets.discordBotToken)
        }
    }

    func applyDiscordArm() -> String {
        if TelegramInboundIntent.arm.shouldSetEngaged(currentlyEngaged: engine.engaged) == true {
            setEngaged(true)
        }
        return engine.engaged ? DiscordInboundCopy.armed : TelegramInboundCopy.armFailed
    }

    func applyDiscordDisarm() -> String {
        pollLid()
        let confirmed = engine.lidCloseConfirmed
        if engine.engaged {
            setEngaged(false)
            if engine.engaged {
                return TelegramInboundCopy.disarmFailed
            }
        } else {
            _ = disarmKernel()
        }
        if TelegramInboundDisarm.shouldRequestSleep(lidCloseConfirmed: confirmed) {
            apply([.requestSleep])
        }
        return DiscordInboundCopy.disarmed
    }

    func sendDiscordInboundReply(_ text: String, update: DiscordInboundUpdate, token: String?) {
        if update.source == .slash,
           let interactionId = update.interactionId,
           let interactionToken = update.interactionToken,
           let request = DiscordInboundRequestFactory.interactionCallback(
               interactionId: interactionId,
               interactionToken: interactionToken,
               content: text
           )
        {
            Task { await TelegramInboundHTTP.send(request) }
            return
        }
        guard let token,
              let request = DiscordInboundRequestFactory.channelMessage(
                  botToken: token,
                  channelId: update.channelId,
                  content: text
              )
        else { return }
        Task { await TelegramInboundHTTP.send(request) }
    }
}
