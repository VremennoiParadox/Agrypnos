import Foundation

public enum TelegramQuestionMessage {
    public static func initial(batch: QuestionBatch, botToken: String, chatID: String) -> NotifOutboundRequest? {
        let chat: Any = Int64(chatID).map { $0 as Any } ?? chatID
        return make(botToken: botToken, method: "sendMessage", object: [
            "chat_id": chat, "text": batch.panelText(at: 0) + "\n\nPreparing controls…",
            "link_preview_options": ["is_disabled": true]
        ])
    }

    public static func requests(view: QuestionView, botToken: String, chatID: String) -> [NotifOutboundRequest] {
        guard let request = make(botToken: botToken, method: "sendMessage", object: body(view: view, chatID: chatID)) else { return [] }
        return [request]
    }

    public static func edit(view: QuestionView, botToken: String, reference: QuestionMessageRef) -> NotifOutboundRequest? {
        guard reference.destination == .telegram, let id = Int64(reference.messageID), id > 0 else { return nil }
        var object = body(view: view, chatID: reference.destinationID)
        object["message_id"] = id
        return make(botToken: botToken, method: "editMessageText", object: object)
    }

    public static func acknowledge(id: String, botToken: String, text: String? = nil) -> NotifOutboundRequest? {
        guard !id.isEmpty else { return nil }
        var object: [String: Any] = ["callback_query_id": id]
        if let text { object["text"] = text }
        return make(botToken: botToken, method: "answerCallbackQuery", object: object)
    }

    static func body(view: QuestionView, chatID: String) -> [String: Any] {
        let question = view.batch.questions[view.questionIndex]
        var rows: [[[String: String]]] = []
        var choices: [[String: String]] = []
        var navigation: [[String: String]] = []
        for control in view.controls {
            let label: String
            switch control.action {
            case let .choose(_, optionID):
                guard let index = question.options.firstIndex(where: { $0.id == optionID }) else { continue }
                let checked = view.selections[question.id]?.contains(optionID) == true
                label = "\(checked ? "✓ " : "")\(index + 1)"
            case .next: label = view.isReview ? "Next review" : "Review / next"
            case .back: label = "Back"
            case .send: label = "Send answers"
            case .returnLocal: label = "Answer on Mac"
            }
            let button = ["text": label, "callback_data": "aq:" + control.token]
            if case .choose = control.action { choices.append(button) } else { navigation.append(button) }
        }
        for offset in stride(from: 0, to: choices.count, by: 5) {
            rows.append(Array(choices[offset..<min(offset + 5, choices.count)]))
        }
        if !navigation.isEmpty { rows.append(navigation) }
        return ["chat_id": Int64(chatID).map { $0 as Any } ?? chatID,
            "text": QuestionMessageText.render(view), "link_preview_options": ["is_disabled": true],
            "reply_markup": ["inline_keyboard": rows]]
    }

    static func make(botToken: String, method: String, object: [String: Any]) -> NotifOutboundRequest? {
        guard let url = NotifOutboundRequestFactory.telegramAPIURL(botToken: botToken, method: method),
              let data = try? JSONSerialization.data(withJSONObject: object) else { return nil }
        return NotifOutboundRequest(url: url, httpMethod: "POST", headers: ["Content-Type": "application/json"], body: data)
    }
}

public enum QuestionMessageText {
    public static func render(_ view: QuestionView) -> String {
        var text = view.batch.panelText(at: view.questionIndex)
        switch view.state {
        case .pending:
            let count = view.batch.questions.count
            text += "\n\n\(view.isReview ? "Review" : "Question") \(view.questionIndex + 1)/\(count)"
            if view.isReview {
                let question = view.batch.questions[view.questionIndex]
                let numbers = question.options.enumerated().filter { view.selections[question.id]?.contains($0.element.id) == true }.map { String($0.offset + 1) }
                text += "\nSelected: " + (numbers.isEmpty ? "none" : numbers.joined(separator: ", "))
            } else { text += "\nChoose by number. Review all questions before sending." }
            text += "\nAnswer on Mac for free text or local input."
        case .submitting: text += "\n\nSending your answers…"
        case .delivered(.accepted): text += "\n\nThe agent accepted the answers."
        case .delivered(.returnedToHook): text += "\n\nAnswers went to the agent's hook. The agent hasn't confirmed it used them."
        case .delivered(.rejected): text += "\n\nThe agent rejected the answers. Check the question on your Mac."
        case .delivered(.unconfirmed): text += "\n\nCouldn't confirm the answers arrived. Check the question on your Mac. Agrypnos won't resend them."
        case .local: text += "\n\nThis one is waiting on your Mac now. The buttons here no longer work."
        case .expired: text += "\n\nThe time to answer here is up. Check the question on your Mac."
        case .invalid: text += "\n\nThis question can't be answered from here any more."
        }
        return text
    }
}
