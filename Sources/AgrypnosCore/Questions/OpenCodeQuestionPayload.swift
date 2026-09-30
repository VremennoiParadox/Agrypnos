import Foundation

public enum OpenCodeQuestionEvent: Equatable, Sendable {
    case asked(QuestionBatch, Data)
    case resolved(QuestionKey)
}

public enum OpenCodeQuestionPayload {
    public enum Error: Swift.Error {
        case invalidRequest
        case invalidAnswer
    }

    private struct NativeRequest: Decodable {
        let id: String
        let sessionID: String
        let questions: [NativeQuestion]
    }

    private struct NativeQuestion: Decodable {
        let question: String
        let options: [NativeOption]
        let multiple: Bool?
        let custom: Bool?
    }

    private struct NativeOption: Decodable {
        let label: String
        let description: String
    }

    private struct NativeReply: Encodable {
        let answers: [[String]]
    }

    public static func decode(_ data: Data, instanceID: String,
                              receivedUptime: TimeInterval) throws -> QuestionBatch {
        guard data.count <= 256 * 1024, !instanceID.isEmpty else { throw Error.invalidRequest }
        let native = try JSONDecoder().decode(NativeRequest.self, from: data)
        let questions = native.questions.enumerated().map { index, item in
            AgentQuestion(id: "q\(index)", prompt: item.question,
                options: item.options.enumerated().map { optionIndex, option in
                    QuestionOption(id: "o\(optionIndex)", label: option.label, detail: option.description)
                }, multiple: item.multiple ?? false, allowsFreeText: item.custom ?? true)
        }
        let batch = QuestionBatch(key: QuestionKey(provider: .openCode, instanceID: instanceID,
            sessionID: native.sessionID, requestID: native.id), questions: questions,
            receivedUptime: receivedUptime, deadlineUptime: receivedUptime + 600)
        guard batch.isValid else { throw Error.invalidRequest }
        return batch
    }

    public static func reply(original: Data, answer: QuestionAnswer,
                             instanceID: String) throws -> Data {
        let batch = try decode(original, instanceID: instanceID, receivedUptime: 0)
        guard answer.key == batch.key, answer.selections.count == batch.questions.count else {
            throw Error.invalidAnswer
        }
        var answers: [[String]] = []
        for (question, selection) in zip(batch.questions, answer.selections) {
            guard selection.questionID == question.id,
                  !selection.optionIDs.isEmpty,
                  Set(selection.optionIDs).count == selection.optionIDs.count,
                  question.multiple || selection.optionIDs.count == 1 else {
                throw Error.invalidAnswer
            }
            let selected = Set(selection.optionIDs)
            guard selected.isSubset(of: Set(question.options.map(\.id))) else { throw Error.invalidAnswer }
            answers.append(question.options.filter { selected.contains($0.id) }.map(\.label))
        }
        return try JSONEncoder().encode(NativeReply(answers: answers))
    }

    public static func event(_ data: Data, instanceID: String, directory: String,
                             receivedUptime: TimeInterval) throws -> OpenCodeQuestionEvent? {
        guard data.count <= 256 * 1024 else { throw Error.invalidRequest }
        guard let envelope = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let payload = envelope["payload"] as? [String: Any],
              let type = payload["type"] as? String else { throw Error.invalidRequest }
        guard ["question.asked", "question.replied", "question.rejected"].contains(type) else { return nil }
        guard let eventDirectory = envelope["directory"] as? String else { throw Error.invalidRequest }
        guard eventDirectory == directory else { return nil }
        switch type {
        case "question.asked":
            guard let properties = payload["properties"] as? [String: Any] else { throw Error.invalidRequest }
            let original = try JSONSerialization.data(withJSONObject: properties)
            return .asked(try decode(original, instanceID: instanceID,
                receivedUptime: receivedUptime), original)
        case "question.replied", "question.rejected":
            guard let properties = payload["properties"] as? [String: Any],
                  let sessionID = properties["sessionID"] as? String, !sessionID.isEmpty,
                  let requestID = properties["requestID"] as? String, !requestID.isEmpty,
                  !instanceID.isEmpty else { throw Error.invalidRequest }
            return .resolved(QuestionKey(provider: .openCode, instanceID: instanceID,
                sessionID: sessionID, requestID: requestID))
        default:
            return nil
        }
    }
}
