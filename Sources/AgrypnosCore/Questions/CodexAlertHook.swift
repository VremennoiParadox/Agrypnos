import Foundation

public enum CodexAlertHook {
    public enum Error: Swift.Error { case unsupportedHooks }

    public static let flag = "--codex-alert-hook"
    public static let commandTimeoutSeconds = 5

    public static func notice(_ data: Data) -> String? {
        guard data.count <= 256 * 1024,
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let event = root["hook_event_name"] as? String else { return nil }
        let tool = root["tool_name"] as? String ?? ""
        if event == "PreToolUse", tool == "request_user_input" {
            var text = "Codex is waiting on you."
            let input = root["tool_input"] as? [String: Any]
            let questions = input?["questions"] as? [[String: Any]] ?? []
            if questions.contains(where: { $0["isSecret"] as? Bool == true }) { return text }
            let lines = questions.compactMap { $0["question"] as? String }.filter { !$0.isEmpty }
            if !lines.isEmpty { text += "\n\n" + lines.joined(separator: "\n") }
            return text
        }
        if event == "PermissionRequest", tool == "Bash" || tool == "apply_patch" {
            return "Codex is waiting for an approval."
        }
        return nil
    }

    public static func enable(hooksJSON: Data, command: String) throws -> Data {
        var root = try object(hooksJSON)
        var hooks = root["hooks"] as? [String: Any] ?? [:]
        hooks["PreToolUse"] = stripped(groups(hooks["PreToolUse"])) + [questionGroup(command)]
        hooks["PermissionRequest"] = stripped(groups(hooks["PermissionRequest"])) + [approvalGroup(command)]
        root["hooks"] = hooks
        return try JSONSerialization.data(withJSONObject: root, options: [.prettyPrinted, .sortedKeys])
    }

    public static func disable(hooksJSON: Data) throws -> Data {
        var root = try object(hooksJSON)
        guard var hooks = root["hooks"] as? [String: Any] else { return hooksJSON }
        for key in ["PreToolUse", "PermissionRequest"] {
            let kept = stripped(groups(hooks[key]))
            if kept.isEmpty { hooks.removeValue(forKey: key) } else { hooks[key] = kept }
        }
        root["hooks"] = hooks
        return try JSONSerialization.data(withJSONObject: root, options: [.prettyPrinted, .sortedKeys])
    }

    private static func questionGroup(_ command: String) -> [String: Any] {
        ["matcher": "^request_user_input$", "hooks": [hook(command)]]
    }

    private static func approvalGroup(_ command: String) -> [String: Any] {
        ["matcher": "Bash|apply_patch", "hooks": [hook(command)]]
    }

    private static func hook(_ command: String) -> [String: Any] {
        ["type": "command", "command": command, "timeout": commandTimeoutSeconds, "async": true]
    }

    private static func groups(_ value: Any?) -> [[String: Any]] {
        value as? [[String: Any]] ?? []
    }

    private static func stripped(_ groups: [[String: Any]]) -> [[String: Any]] {
        groups.filter { group in
            let hooks = group["hooks"] as? [[String: Any]] ?? []
            return !hooks.contains { ($0["command"] as? String)?.contains(flag) == true }
        }
    }

    private static func object(_ data: Data) throws -> [String: Any] {
        if data.isEmpty { return [:] }
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw Error.unsupportedHooks
        }
        return root
    }
}
