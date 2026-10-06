import XCTest
@testable import AgrypnosCore

final class CodexAlertHookTests: XCTestCase {
    func testQuestionNotice() {
        let data = Data("""
        {"hook_event_name":"PreToolUse","tool_name":"request_user_input","tool_input":{"questions":[{"id":"q","question":"Which?","options":[{"label":"A"},{"label":"B"}]}]}}
        """.utf8)
        XCTAssertEqual(CodexAlertHook.notice(data), "Codex is waiting on you.\n\nWhich?")
    }

    func testSecretOmitsTheQuestionText() {
        let data = Data("""
        {"hook_event_name":"PreToolUse","tool_name":"request_user_input","tool_input":{"questions":[{"question":"Token?","isSecret":true}]}}
        """.utf8)
        XCTAssertEqual(CodexAlertHook.notice(data), "Codex is waiting on you.")
    }

    func testApprovalIsNotAQuestion() {
        let data = Data("""
        {"hook_event_name":"PermissionRequest","tool_name":"Bash","tool_input":{"command":"rm x"}}
        """.utf8)
        XCTAssertEqual(CodexAlertHook.notice(data), "Codex is waiting for an approval.")
    }

    func testStopIsSilent() {
        let data = Data(#"{"hook_event_name":"Stop","tool_name":"request_user_input"}"#.utf8)
        XCTAssertNil(CodexAlertHook.notice(data))
    }

    func testMergeKeepsBrainrotAndDisableRemovesOnlyAgrypnos() throws {
        let original = Data("""
        {"hooks":{"UserPromptSubmit":[{"hooks":[{"type":"command","command":"/Users/me/.brainrot/brainrot-state.sh"}]}],"Stop":[{"hooks":[{"type":"command","command":"/Users/me/.brainrot/brainrot-state.sh"}]}]}}
        """.utf8)
        let enabled = try CodexAlertHook.enable(hooksJSON: original, command: "/Applications/Agrypnos.app/Contents/MacOS/Agrypnos --codex-alert-hook")
        let text = String(decoding: enabled, as: UTF8.self)
        XCTAssertTrue(text.contains("brainrot-state.sh"))
        XCTAssertTrue(text.contains("--codex-alert-hook"))
        XCTAssertTrue(text.contains("request_user_input"))
        XCTAssertTrue(text.contains("\"async\":true") || text.contains("\"async\" : true"))
        let disabled = try CodexAlertHook.disable(hooksJSON: enabled)
        let after = String(decoding: disabled, as: UTF8.self)
        XCTAssertTrue(after.contains("UserPromptSubmit"))
        XCTAssertTrue(after.contains("Stop"))
        XCTAssertFalse(after.contains("--codex-alert-hook"))
    }
}
