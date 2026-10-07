import Foundation

#if canImport(AgrypnosCore)
import AgrypnosCore
#endif

/// Best effort through the same user-owned bots. No extra connection or idle POST opt-in.
@MainActor
enum QuestionNoticeSender {
    static func send(_ text: String) async {
        let preferences = PreferencesStore().load()
        guard preferences.forwardAgentQuestions else { return }
        let secrets = NotifSecretsStore.load()
        var requests: [NotifOutboundRequest] = []
        if preferences.telegramInboundEnabled,
           let token = secrets.telegramBotToken, let chatID = secrets.telegramChatId,
           secrets.telegramQuestionUserId != nil,
           let request = NotifOutboundRequestFactory.telegram(botToken: token, chatId: chatID, text: text) {
            requests.append(request)
        }
        if preferences.discordInboundEnabled,
           let token = secrets.discordBotToken, let channelID = secrets.discordChannelId,
           secrets.discordQuestionUserId != nil,
           let request = DiscordQuestionMessage.notice(text, botToken: token, channelID: channelID) {
            requests.append(request)
        }
        await deliver(requests)
    }

    static func deliver(_ requests: [NotifOutboundRequest]) async {
        await withTaskGroup(of: Void.self) { group in
            for request in requests {
                group.addTask { await NotifIdlePoster.fire(request) }
            }
        }
    }
}

@MainActor
final class QuestionNoticeGate {
    private var continuation: CheckedContinuation<Void, Never>?
    var sending: Task<Void, Never>?
    var timeout: Task<Void, Never>?

    init(_ continuation: CheckedContinuation<Void, Never>) { self.continuation = continuation }

    func finish() {
        guard let continuation else { return }
        self.continuation = nil
        sending?.cancel()
        timeout?.cancel()
        continuation.resume()
    }
}
