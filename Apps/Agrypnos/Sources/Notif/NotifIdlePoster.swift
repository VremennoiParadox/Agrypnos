import Foundation

#if canImport(AgrypnosCore)
import AgrypnosCore
#endif

/// Best-effort one-shot POST. Bounded wait so lid-closed sleepnow does not kill the attempt.
enum NotifIdlePoster {
    static let waitBound: TimeInterval = 10

    static let session: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = waitBound
        config.timeoutIntervalForResource = waitBound
        config.waitsForConnectivity = true
        return URLSession(configuration: config)
    }()

    static func postIfNeeded(enabled: Bool) async {
        guard enabled else { return }
        let secrets = NotifSecretsStore.load()
        let channels = NotifIdlePostPolicy.destinations(
            discordWebhookURL: secrets.discordWebhookURL,
            telegramBotToken: secrets.telegramBotToken,
            telegramChatId: secrets.telegramChatId
        )
        let body = AgrypnosCopy.notifIdleBody
        var requests: [NotifOutboundRequest] = []
        if channels.contains(.discord),
           let url = secrets.discordWebhookURL,
           let request = NotifOutboundRequestFactory.discord(webhookURL: url, content: body)
        {
            requests.append(request)
        }
        if channels.contains(.telegram) {
            if let token = secrets.telegramBotToken,
               let chat = secrets.telegramChatId,
               let request = NotifOutboundRequestFactory.telegram(
                botToken: token,
                chatId: chat,
                text: body
               )
            {
                requests.append(request)
            } else {
                UserNotify.post(AgrypnosCopy.notifTelegramPostFailed)
            }
        }
        await withTaskGroup(of: Void.self) { group in
            for request in requests {
                group.addTask { await fire(request) }
            }
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
