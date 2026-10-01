import Foundation

public enum ClaudeAskUserQuestionPayload {
    public enum Error: Swift.Error { case invalidRequest, invalidAnswer }

    public static let nativeFallback = Data("{}".utf8)
    public static let flag = "--claude-question-hook"
    public static let commandTimeoutSeconds = 630
    public static let unavailableFallbackSeconds: TimeInterval = 2

    public static func decode(_ data: Data, receivedUptime: TimeInterval) throws -> QuestionBatch {
        let request = try request(data, receivedUptime: receivedUptime)
        return request.batch
    }

    static func request(_ data: Data, receivedUptime: TimeInterval = 0) throws -> (batch: QuestionBatch, originalQuestions: Any) {
        guard data.count <= 256 * 1024 else { throw Error.invalidRequest }
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw Error.invalidRequest
        }
        let event = (root["hook_event_name"] as? String) ?? (root["hookEventName"] as? String)
        guard event == "PreToolUse" else { throw Error.invalidRequest }
        guard root["tool_name"] as? String == "AskUserQuestion" else { throw Error.invalidRequest }
        let session = (root["session_id"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let cwd = (root["cwd"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let toolUse = (root["tool_use_id"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !session.isEmpty, !cwd.isEmpty, !toolUse.isEmpty else { throw Error.invalidRequest }
        guard let input = root["tool_input"] as? [String: Any],
              let questions = input["questions"] as? [[String: Any]], !questions.isEmpty else {
            throw Error.invalidRequest
        }
        let agents: [AgentQuestion] = try questions.map { item in
            guard let prompt = item["question"] as? String,
                  !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  let options = item["options"] as? [[String: Any]], !options.isEmpty else {
                throw Error.invalidRequest
            }
            let mapped = try options.map { option -> QuestionOption in
                guard let label = option["label"] as? String,
                      !label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    throw Error.invalidRequest
                }
                return QuestionOption(id: label, label: label, detail: option["description"] as? String)
            }
            return AgentQuestion(id: prompt, prompt: prompt, options: mapped,
                multiple: item["multiSelect"] as? Bool ?? false, allowsFreeText: true)
        }
        let key = QuestionKey(provider: .claudeCode, instanceID: cwd, sessionID: session, requestID: toolUse)
        let label = URL(fileURLWithPath: cwd).lastPathComponent
        let batch = QuestionBatch(key: key, projectLabel: label.isEmpty ? nil : label,
            questions: agents, receivedUptime: receivedUptime, deadlineUptime: receivedUptime + 600)
        guard batch.isValid else { throw Error.invalidRequest }
        return (batch, questions)
    }
}
