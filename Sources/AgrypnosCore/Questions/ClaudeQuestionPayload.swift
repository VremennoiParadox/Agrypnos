import Foundation

/// Codec for the documented PreToolUse/AskUserQuestion contract; live hook support is unverified.
public enum ClaudeQuestionPayload {
    public enum Error: Swift.Error { case invalidRequest, invalidAnswer }

    private struct Hook: Decodable {
        let hook_event_name: String
        let tool_name: String
        let session_id: String
        let tool_use_id: String
        let tool_input: Input
    }

    private struct Input: Decodable { let questions: [Question] }
    private struct Question: Decodable {
        let question: String
        let options: [Option]
        let multiSelect: Bool?
    }
    private struct Option: Decodable {
        let label: String
        let description: String?
    }

    public static func decode(_ data: Data, instanceID: String,
                              receivedUptime: TimeInterval) throws -> QuestionBatch {
        let (hook, _) = try parse(data)
        return try batch(hook, instanceID: instanceID, receivedUptime: receivedUptime)
    }

    public static func reply(original: Data, answer: QuestionAnswer,
                             instanceID: String) throws -> Data {
        let (hook, input) = try parse(original)
        let batch = try batch(hook, instanceID: instanceID, receivedUptime: 0)
        guard answer.key == batch.key, answer.selections.count == batch.questions.count
        else { throw Error.invalidAnswer }
        var answers: [String: String] = [:]
        for (question, selection) in zip(batch.questions, answer.selections) {
            let selected = Set(selection.optionIDs)
            guard selection.questionID == question.id, !selected.isEmpty,
                  selected.count == selection.optionIDs.count,
                  question.multiple || selected.count == 1,
                  selected.isSubset(of: Set(question.options.map(\.id)))
            else { throw Error.invalidAnswer }
            answers[question.prompt] = question.options.filter { selected.contains($0.id) }
                .map(\.label).joined(separator: ", ")
        }
        var updated = input
        updated["answers"] = answers
        // Only this exact question tool can reach here; hook coexistence still needs live verification.
        let data = try JSONSerialization.data(withJSONObject: ["hookSpecificOutput": [
            "hookEventName": "PreToolUse", "permissionDecision": "allow", "updatedInput": updated
        ]])
        guard data.count <= 256 * 1024 else { throw Error.invalidAnswer }
        return data
    }

    private static func parse(_ data: Data) throws -> (Hook, [String: Any]) {
        guard data.count <= 256 * 1024,
              let object = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let input = object["tool_input"] as? [String: Any], input["answers"] == nil
        else { throw Error.invalidRequest }
        let hook = try JSONDecoder().decode(Hook.self, from: data)
        guard hook.hook_event_name == "PreToolUse", hook.tool_name == "AskUserQuestion"
        else { throw Error.invalidRequest }
        return (hook, input)
    }

    private static func batch(_ hook: Hook, instanceID: String,
                              receivedUptime: TimeInterval) throws -> QuestionBatch {
        let questions = hook.tool_input.questions.enumerated().map { index, item in
            AgentQuestion(id: "q\(index)", prompt: item.question,
                options: item.options.enumerated().map { optionIndex, option in
                    QuestionOption(id: "o\(optionIndex)", label: option.label, detail: option.description)
                }, multiple: item.multiSelect ?? false, allowsFreeText: true)
        }
        // Claude maps by prompt text and joins multi-select labels with commas, without escaping.
        guard Set(questions.map(\.prompt)).count == questions.count,
              !questions.contains(where: { $0.multiple && $0.options.contains(where: { $0.label.contains(",") }) })
        else { throw Error.invalidRequest }
        let batch = QuestionBatch(key: QuestionKey(provider: .claudeCode, instanceID: instanceID,
            sessionID: hook.session_id, requestID: hook.tool_use_id), questions: questions,
            receivedUptime: receivedUptime, deadlineUptime: receivedUptime + 600)
        guard batch.isValid else { throw Error.invalidRequest }
        return batch
    }
}
