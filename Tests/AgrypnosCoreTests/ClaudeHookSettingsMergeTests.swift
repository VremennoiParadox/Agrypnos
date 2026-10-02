import Foundation
import XCTest
@testable import AgrypnosCore

final class ClaudeHookSettingsMergeTests: XCTestCase {
    private let brainrot = "/Users/test/.brainrot/brainrot-state.sh"
    private var existing: Data {
        Data(#"""
        {"permissions":{"allow":["mcp__x"]},"model":"opus","hooks":{"UserPromptSubmit":[{"hooks":[{"type":"command","command":"/Users/test/.brainrot/brainrot-state.sh"}]}],"Stop":[{"hooks":[{"type":"command","command":"/Users/test/.brainrot/brainrot-state.sh"}]}],"StopFailure":[{"hooks":[{"type":"command","command":"/Users/test/.brainrot/brainrot-state.sh"}]}]},"enableWorkflows":true}
        """#.utf8)
    }

    func testEnableKeepsBrainrotAndAddsAskUserQuestionMatcher() throws {
        let command = "/Applications/Agrypnos.app/Contents/MacOS/Agrypnos --claude-question-hook"
        let merged = try ClaudeHookSettingsMerge.enable(settingsJSON: existing, command: command, timeoutSeconds: 630)
        let root = try XCTUnwrap(JSONSerialization.jsonObject(with: merged) as? [String: Any])
        XCTAssertEqual(root["model"] as? String, "opus")
        XCTAssertEqual((root["permissions"] as? [String: Any])?["allow"] as? [String], ["mcp__x"])
        XCTAssertEqual(root["enableWorkflows"] as? Bool, true)
        let hooks = try XCTUnwrap(root["hooks"] as? [String: Any])
        XCTAssertEqual(self.command(in: hooks, event: "UserPromptSubmit"), brainrot)
        XCTAssertEqual(self.command(in: hooks, event: "Stop"), brainrot)
        XCTAssertEqual(self.command(in: hooks, event: "StopFailure"), brainrot)
        let pre = try XCTUnwrap(hooks["PreToolUse"] as? [[String: Any]])
        let ask = try XCTUnwrap(pre.first { $0["matcher"] as? String == "AskUserQuestion" })
        let hook = try XCTUnwrap((ask["hooks"] as? [[String: Any]])?.first)
        XCTAssertEqual(hook["type"] as? String, "command")
        XCTAssertEqual(hook["command"] as? String, command)
        XCTAssertEqual(hook["timeout"] as? Int, 630)
        XCTAssertTrue(command.contains(ClaudeAskUserQuestionPayload.flag))
    }

    func testDisableRemovesOnlyAgrypnosHook() throws {
        let command = "/tmp/Agrypnos --claude-question-hook"
        let withBash = try ClaudeHookSettingsMerge.enable(settingsJSON: existing, command: command, timeoutSeconds: 630)
        var root = try JSONSerialization.jsonObject(with: withBash) as! [String: Any]
        var hooks = root["hooks"] as! [String: Any]
        var pre = hooks["PreToolUse"] as! [[String: Any]]
        pre.insert(["matcher": "Bash", "hooks": [["type": "command", "command": "echo bash"]]], at: 0)
        hooks["PreToolUse"] = pre
        root["hooks"] = hooks
        let mixed = try JSONSerialization.data(withJSONObject: root)
        let disabled = try ClaudeHookSettingsMerge.disable(settingsJSON: mixed)
        let out = try XCTUnwrap(JSONSerialization.jsonObject(with: disabled) as? [String: Any])
        let outHooks = try XCTUnwrap(out["hooks"] as? [String: Any])
        XCTAssertEqual(self.command(in: outHooks, event: "UserPromptSubmit"), brainrot)
        XCTAssertEqual(self.command(in: outHooks, event: "Stop"), brainrot)
        XCTAssertEqual(self.command(in: outHooks, event: "StopFailure"), brainrot)
        let leftover = try XCTUnwrap(outHooks["PreToolUse"] as? [[String: Any]])
        XCTAssertEqual(leftover.count, 1)
        XCTAssertEqual(leftover.first?["matcher"] as? String, "Bash")
        XCTAssertFalse(String(data: disabled, encoding: .utf8)!.contains("--claude-question-hook"))
    }

    func testEnableIsIdempotentAndInvalidJSONIsRejected() throws {
        let command = "/tmp/Agrypnos --claude-question-hook"
        let once = try ClaudeHookSettingsMerge.enable(settingsJSON: existing, command: command, timeoutSeconds: 630)
        let twice = try ClaudeHookSettingsMerge.enable(settingsJSON: once, command: command, timeoutSeconds: 630)
        let hooks = try XCTUnwrap((JSONSerialization.jsonObject(with: twice) as? [String: Any])?["hooks"] as? [String: Any])
        let pre = try XCTUnwrap(hooks["PreToolUse"] as? [[String: Any]])
        XCTAssertEqual(pre.filter { $0["matcher"] as? String == "AskUserQuestion" }.count, 1)
        XCTAssertThrowsError(try ClaudeHookSettingsMerge.enable(settingsJSON: Data("not-json".utf8),
            command: command, timeoutSeconds: 630))
        XCTAssertThrowsError(try ClaudeHookSettingsMerge.disable(settingsJSON: Data("{".utf8)))
    }

    func testMissingClaudeHookPreferenceDefaultsOff() throws {
        var object = try JSONSerialization.jsonObject(with: JSONEncoder().encode(UserPreferences())) as! [String: Any]
        object.removeValue(forKey: "claudeQuestionHookEnabled")
        let decoded = try JSONDecoder().decode(UserPreferences.self, from: JSONSerialization.data(withJSONObject: object))
        XCTAssertFalse(decoded.claudeQuestionHookEnabled)
        XCTAssertFalse(UserPreferences().claudeQuestionHookEnabled)
        var on = decoded
        on.claudeQuestionHookEnabled = true
        XCTAssertTrue(try JSONDecoder().decode(UserPreferences.self, from: JSONEncoder().encode(on)).claudeQuestionHookEnabled)
    }

    private func command(in hooks: [String: Any], event: String) -> String? {
        let groups = hooks[event] as? [[String: Any]]
        let hooks = groups?.first?["hooks"] as? [[String: Any]]
        return hooks?.first?["command"] as? String
    }
}
