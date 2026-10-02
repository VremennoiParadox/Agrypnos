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

    func testStdoutAllowEchoesQuestionsAndMapsLabels() throws {
        let batch = try ClaudeAskUserQuestionPayload.decode(fixture, receivedUptime: 1000)
        let answer = QuestionAnswer(key: batch.key, selections: [
            QuestionSelection(questionID: "Which framework?", optionIDs: ["Vue"])
        ])
        let body = try ClaudeAskUserQuestionPayload.stdout(original: fixture, answer: answer)
        XCTAssertTrue(ClaudeAskUserQuestionPayload.isSufficientAskUserQuestionOutput(body))
        let root = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
        let specific = try XCTUnwrap(root["hookSpecificOutput"] as? [String: Any])
        XCTAssertEqual(specific["hookEventName"] as? String, "PreToolUse")
        XCTAssertEqual(specific["permissionDecision"] as? String, "allow")
        let updated = try XCTUnwrap(specific["updatedInput"] as? [String: Any])
        let questions = try XCTUnwrap(updated["questions"] as? [[String: Any]])
        XCTAssertEqual(questions.first?["question"] as? String, "Which framework?")
        XCTAssertEqual(questions.first?["header"] as? String, "Framework")
        XCTAssertEqual(updated["answers"] as? [String: String], ["Which framework?": "Vue"])
    }

    func testAllowAloneIsNotSufficient() throws {
        let allowAlone = Data(#"""
        {"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"allow"}}
        """#.utf8)
        XCTAssertFalse(ClaudeAskUserQuestionPayload.isSufficientAskUserQuestionOutput(allowAlone))
        XCTAssertFalse(ClaudeAskUserQuestionPayload.isSufficientAskUserQuestionOutput(
            ClaudeAskUserQuestionPayload.nativeFallback))
    }

    func testMultiSelectJoinsLabelsWithComma() throws {
        let multi = Data(#"""
        {"session_id":"sess_test","cwd":"/Users/test/project","hook_event_name":"PreToolUse","tool_name":"AskUserQuestion","tool_use_id":"toolu_02","tool_input":{"questions":[{"question":"Which colors?","header":"Colors","options":[{"label":"Red","description":"Warm"},{"label":"Blue","description":"Cool"}],"multiSelect":true}]}}
        """#.utf8)
        let batch = try ClaudeAskUserQuestionPayload.decode(multi, receivedUptime: 10)
        XCTAssertTrue(batch.questions[0].multiple)
        let answer = QuestionAnswer(key: batch.key, selections: [
            QuestionSelection(questionID: "Which colors?", optionIDs: ["Red", "Blue"])
        ])
        let body = try ClaudeAskUserQuestionPayload.stdout(original: multi, answer: answer)
        let root = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
        let specific = try XCTUnwrap(root["hookSpecificOutput"] as? [String: Any])
        let updated = try XCTUnwrap(specific["updatedInput"] as? [String: Any])
        XCTAssertEqual(updated["answers"] as? [String: String], ["Which colors?": "Red, Blue"])
    }

    func testHelperStdoutWritesAnswersFromExchange() throws {
        let batch = try ClaudeAskUserQuestionPayload.decode(fixture, receivedUptime: 0)
        let answer = QuestionAnswer(key: batch.key, selections: [
            QuestionSelection(questionID: "Which framework?", optionIDs: ["Vue"])
        ])
        let expected = try ClaudeAskUserQuestionPayload.stdout(original: fixture, answer: answer)
        let out = ClaudeAskUserQuestionPayload.helperStdout(stdin: fixture) { stdin in
            XCTAssertEqual(stdin, fixture)
            return expected
        }
        XCTAssertEqual(out, expected)
        XCTAssertTrue(ClaudeAskUserQuestionPayload.isSufficientAskUserQuestionOutput(out))
    }

    func testHelperStdoutFallsBackWhenAgrypnosUnavailable() {
        let out = ClaudeAskUserQuestionPayload.helperStdout(stdin: fixture) { _ in
            throw ClaudeAskUserQuestionPayload.Error.invalidRequest
        }
        XCTAssertEqual(out, ClaudeAskUserQuestionPayload.nativeFallback)
        XCTAssertFalse(ClaudeAskUserQuestionPayload.isSufficientAskUserQuestionOutput(out))
    }

    func testHelperStdoutRejectsAllowAloneFromExchange() {
        let allowAlone = Data(#"""
        {"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"allow"}}
        """#.utf8)
        let out = ClaudeAskUserQuestionPayload.helperStdout(stdin: fixture) { _ in allowAlone }
        XCTAssertEqual(out, ClaudeAskUserQuestionPayload.nativeFallback)
    }

    func testHelperStdoutFallsBackOnUnparseableStdin() {
        let out = ClaudeAskUserQuestionPayload.helperStdout(stdin: Data("not-json".utf8)) { _ in
            XCTFail("must not contact Agrypnos")
            return Data()
        }
        XCTAssertEqual(out, ClaudeAskUserQuestionPayload.nativeFallback)
    }
}
