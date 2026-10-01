import Foundation
import XCTest
@testable import AgrypnosCore

final class ClaudeAskUserQuestionPayloadTests: XCTestCase {
    private let fixture = Data(#"""
    {"session_id":"sess_test","transcript_path":"/tmp/t.jsonl","cwd":"/Users/test/project","hook_event_name":"PreToolUse","tool_name":"AskUserQuestion","tool_use_id":"toolu_01","tool_input":{"questions":[{"question":"Which framework?","header":"Framework","options":[{"label":"React","description":"SPA"},{"label":"Vue","description":"Also SPA"}],"multiSelect":false}]}}
    """#.utf8)

    func testDecodeMapsQuestionTextAndOptionLabels() throws {
        let batch = try ClaudeAskUserQuestionPayload.decode(fixture, receivedUptime: 1000)
        XCTAssertEqual(batch.key, QuestionKey(provider: .claudeCode, instanceID: "/Users/test/project",
            sessionID: "sess_test", requestID: "toolu_01"))
        XCTAssertEqual(batch.projectLabel, "project")
        XCTAssertEqual(batch.deadlineUptime, 1600)
        XCTAssertEqual(batch.questions.count, 1)
        XCTAssertEqual(batch.questions[0].id, "Which framework?")
        XCTAssertEqual(batch.questions[0].prompt, "Which framework?")
        XCTAssertEqual(batch.questions[0].options.map(\.id), ["React", "Vue"])
        XCTAssertEqual(batch.questions[0].options.map(\.label), ["React", "Vue"])
        XCTAssertEqual(batch.questions[0].options[0].detail, "SPA")
        XCTAssertFalse(batch.questions[0].multiple)
        XCTAssertTrue(batch.questions[0].allowsFreeText)
        XCTAssertTrue(batch.isValid)
    }

    func testRejectsPermissionRequestAndWrongTool() {
        let permission = Data(#"""
        {"session_id":"sess_test","cwd":"/Users/test/project","hook_event_name":"PermissionRequest","tool_name":"AskUserQuestion","tool_input":{"questions":[{"question":"Which?","header":"Q","options":[{"label":"A","description":"a"},{"label":"B","description":"b"}],"multiSelect":false}]}}
        """#.utf8)
        XCTAssertThrowsError(try ClaudeAskUserQuestionPayload.decode(permission, receivedUptime: 1))
        let bash = Data(#"""
        {"session_id":"sess_test","cwd":"/Users/test/project","hook_event_name":"PreToolUse","tool_name":"Bash","tool_use_id":"toolu_01","tool_input":{"command":"ls"}}
        """#.utf8)
        XCTAssertThrowsError(try ClaudeAskUserQuestionPayload.decode(bash, receivedUptime: 1))
    }
}
