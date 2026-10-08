import Foundation

#if canImport(AgrypnosCore)
import AgrypnosCore
#endif

/// Best-effort one-shot POST. Bounded wait so lid-closed sleepnow is not blocked.
enum NotifIdlePoster {
    static let waitBound: TimeInterval = 3

    static let session: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = waitBound
        config.timeoutIntervalForResource = waitBound
        config.waitsForConnectivity = false
        return URLSession(configuration: config)
    }()

    static func postIfNeeded(enabled: Bool, reason: DisengageReason?, willSleep: Bool) async {
        guard enabled else { return }
        let requests = requests(secrets: NotifSecretsStore.load(), reason: reason, willSleep: willSleep)
        await withTaskGroup(of: Void.self) { group in
            for request in requests {
                group.addTask { await fire(request) }
            }
        }
    }

    static func requests(
        secrets: NotifSecrets,
        reason: DisengageReason?,
        willSleep: Bool
    ) -> [NotifOutboundRequest] {
        let channels = NotifIdlePostPolicy.destinations(
            discordBotToken: secrets.discordBotToken,
            discordChannelId: secrets.discordChannelId,
            telegramBotToken: secrets.telegramBotToken,
            telegramChatId: secrets.telegramChatId
        )
        var requests: [NotifOutboundRequest] = []
        if channels.contains(.discord),
           let token = secrets.discordBotToken,
           let channel = secrets.discordChannelId,
           let text = DiscordBotOutbound.body(reason: reason, willSleep: willSleep),
           let request = DiscordInboundRequestFactory.channelMessage(
               botToken: token, channelId: channel, content: text)
        {
            requests.append(request)
        }
        if channels.contains(.telegram),
           let telegramBody = Self.telegramBody(reason: reason)
        {
            if let token = secrets.telegramBotToken,
               let chat = secrets.telegramChatId,
               let request = NotifOutboundRequestFactory.telegram(
                botToken: token,
                chatId: chat,
                text: telegramBody
               )
            {
                requests.append(request)
            } else {
                UserNotify.post(AgrypnosCopy.notifTelegramPostFailed)
            }
        }
        return requests
    }

    private static func telegramBody(reason: DisengageReason?) -> String? {
        switch reason {
        case .timerExpired:
            return "Agrypnos: your watch timer ended."
        case .agentsSettled:
            return AgrypnosCopy.notifIdleBody
        default:
            return nil
        }
    }

    static func fire(_ request: NotifOutboundRequest) async {
        var urlRequest = URLRequest(url: request.url)
        urlRequest.httpMethod = request.httpMethod
        urlRequest.httpBody = request.body
        urlRequest.timeoutInterval = waitBound
        for (header, value) in request.headers {
            urlRequest.setValue(value, forHTTPHeaderField: header)
        }
        do {
            let (data, response) = try await session.data(for: urlRequest)
            let status = (response as? HTTPURLResponse)?.statusCode
            let channel = NotifOutboundPostChrome.channel(for: request.url)
            let detail = channel == .telegram ? NotifOutboundPostChrome.telegramDetail(body: data) : nil
            let outcome = NotifOutboundPostChrome.outcome(
                channel: channel,
                statusCode: status,
                body: data
            )
            if let copy = NotifOutboundPostChrome.notifyCopy(
                channel: channel,
                outcome: outcome,
                detail: detail
            ) {
                UserNotify.post(copy)
            }
        } catch {
            let channel = NotifOutboundPostChrome.channel(for: request.url)
            if let copy = NotifOutboundPostChrome.notifyCopy(channel: channel, outcome: .unreachable) {
                UserNotify.post(copy)
            }
        }
    }
}
