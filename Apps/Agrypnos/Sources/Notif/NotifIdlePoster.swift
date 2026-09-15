import Foundation

#if canImport(AgrypnosCore)
import AgrypnosCore
#endif

/// Best-effort one-shot POST. Does not block disarm. At most one Discord + one Telegram.
enum NotifIdlePoster {
    static func postIfNeeded() {
        let secrets = NotifSecretsStore.load()
        let channels = NotifIdlePostPolicy.channels(
            enabled: true,
            reason: .agentsSettled,
            sawBusy: true,
            discordWebhookURL: secrets.discordWebhookURL,
            telegramBotToken: secrets.telegramBotToken,
            telegramChatId: secrets.telegramChatId
        )
        let body = AgrypnosCopy.notifIdleBody
        if channels.contains(.discord),
           let url = secrets.discordWebhookURL,
           let request = NotifOutboundRequestFactory.discord(webhookURL: url, content: body)
        {
            fire(request)
        }
        if channels.contains(.telegram),
           let token = secrets.telegramBotToken,
           let chat = secrets.telegramChatId,
           let request = NotifOutboundRequestFactory.telegram(
            botToken: token,
            chatId: chat,
            text: body
           )
        {
            fire(request)
        }
    }

    static func fire(_ request: NotifOutboundRequest) {
        var urlRequest = URLRequest(url: request.url)
        urlRequest.httpMethod = request.httpMethod
        urlRequest.httpBody = request.body
        urlRequest.timeoutInterval = 15
        for (header, value) in request.headers {
            urlRequest.setValue(value, forHTTPHeaderField: header)
        }
        URLSession.shared.dataTask(with: urlRequest) { _, _, _ in }.resume()
    }
}
