import Foundation

public enum ClaudeHookSettingsMerge {
    public enum Error: Swift.Error { case unsupportedSettings }

    public static func enable(settingsJSON: Data, command: String, timeoutSeconds: Int) throws -> Data {
        var root = try object(settingsJSON)
        var hooks = root["hooks"] as? [String: Any] ?? [:]
        if root["hooks"] != nil, root["hooks"] is [String: Any] == false { throw Error.unsupportedSettings }
        var pre = groups(hooks["PreToolUse"])
        pre = stripped(pre)
        pre.append([
            "matcher": "AskUserQuestion",
            "hooks": [[
                "type": "command",
                "command": command,
                "timeout": timeoutSeconds
            ]]
        ])
        hooks["PreToolUse"] = pre
        root["hooks"] = hooks
        return try JSONSerialization.data(withJSONObject: root, options: [.prettyPrinted, .sortedKeys])
    }

    public static func disable(settingsJSON: Data) throws -> Data {
        var root = try object(settingsJSON)
        guard var hooks = root["hooks"] as? [String: Any] else { return settingsJSON }
        let pre = stripped(groups(hooks["PreToolUse"]))
        if pre.isEmpty { hooks.removeValue(forKey: "PreToolUse") } else { hooks["PreToolUse"] = pre }
        root["hooks"] = hooks
        return try JSONSerialization.data(withJSONObject: root, options: [.prettyPrinted, .sortedKeys])
    }

    private static func object(_ data: Data) throws -> [String: Any] {
        guard let parsed = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw Error.unsupportedSettings
        }
        return parsed
    }

    private static func groups(_ value: Any?) -> [[String: Any]] {
        value as? [[String: Any]] ?? []
    }

    private static func stripped(_ groups: [[String: Any]]) -> [[String: Any]] {
        groups.compactMap { group in
            let hooks = (group["hooks"] as? [[String: Any]] ?? []).filter { hook in
                !isAgrypnos(hook["command"] as? String)
            }
            if hooks.isEmpty { return nil }
            var next = group
            next["hooks"] = hooks
            return next
        }
    }

    private static func isAgrypnos(_ command: String?) -> Bool {
        guard let command else { return false }
        return command.split(whereSeparator: { $0.isWhitespace }).map(String.init)
            .contains(ClaudeAskUserQuestionPayload.flag)
    }
}
