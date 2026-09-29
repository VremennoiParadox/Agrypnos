import Foundation
import AgrypnosCore

func questionKey(_ request: String = "q", session: String = "s") -> QuestionKey {
    QuestionKey(provider: .cursor, instanceID: "i", sessionID: session, requestID: request)
}

func questionBatch(_ request: String = "q", count: Int = 1,
                   optionCount: Int = 2, multiple: Bool = false) -> QuestionBatch {
    QuestionBatch(key: questionKey(request), projectLabel: "Example",
        questions: (0..<count).map { index in
            AgentQuestion(id: "q\(index)", prompt: "Choose a mode?",
                options: (0..<optionCount).map {
                    QuestionOption(id: "o\($0)", label: "Choice \($0)", detail: "Detail \($0)")
                }, multiple: multiple)
        }, receivedUptime: 1000, deadlineUptime: 1600)
}

let telegramQuestionRef = QuestionMessageRef(destination: .telegram, destinationID: "chat", messageID: "1")
let discordQuestionRef = QuestionMessageRef(destination: .discord, destinationID: "channel", messageID: "2")

@discardableResult
func questionAction(_ action: QuestionAction, registry: inout QuestionRegistry, handle: UUID,
                    reference: QuestionMessageRef = telegramQuestionRef,
                    now: TimeInterval = 1100) -> QuestionEffect {
    guard let view = registry.view(handle: handle, reference: reference),
          let control = view.controls.first(where: { $0.action == action }) else { return .ignore }
    return registry.handle(QuestionCallback(reference: reference, senderID: "owner",
        actionToken: control.token, generation: view.generation), authorizedUserID: "owner", now: now)
}
