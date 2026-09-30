import Foundation
import XCTest
@testable import AgrypnosCore

final class ClaudeQuestionPayloadTests: XCTestCase {
    // Documented hook shape, not a captured live Claude event.
    private let input = Data(#"{"hook_event_name":"PreToolUse","tool_name":"AskUserQuestion","session_id":"session-fixture","tool_use_id":"tool-fixture","tool_input":{"questions":[{"question":"Which letter?","header":"Letter","options":[{"label":"A","description":"First"},{"label":"B","description":"Second"}],"multiSelect":false},{"question":"Which colors?","header":"Colors","options":[{"label":"Red","description":"Warm"},{"label":"Blue","description":"Cool"}],"multiSelect":true}],"metadata":{"fixture":true}}}"#.utf8)

    func testDocumentedHookShapePreservesIdentityChoicesAndDeadline() throws {
        let batch = try ClaudeQuestionPayload.decode(input, instanceID: "hook", receivedUptime: 1000)
        XCTAssertEqual(batch.key, QuestionKey(provider: .claudeCode, instanceID: "hook",
            sessionID: "session-fixture", requestID: "tool-fixture"))
        XCTAssertEqual(batch.receivedUptime, 1000)
        XCTAssertEqual(batch.deadlineUptime, 1600)
        XCTAssertEqual(batch.questions.map(\.prompt), ["Which letter?", "Which colors?"])
        XCTAssertEqual(batch.questions[0].options.map(\.label), ["A", "B"])
        XCTAssertEqual(batch.questions[0].options[1].detail, "Second")
        XCTAssertFalse(batch.questions[0].multiple)
        XCTAssertTrue(batch.questions[1].multiple)
        XCTAssertTrue(batch.questions.allSatisfy(\.allowsFreeText))
    }

    func testReplyPreservesEntireOriginalInputAndAddsCompleteNativeAnswers() throws {
        let batch = try ClaudeQuestionPayload.decode(input, instanceID: "hook", receivedUptime: 1000)
        let answer = QuestionAnswer(key: batch.key, selections: [
            QuestionSelection(questionID: "q0", optionIDs: ["o1"]),
            QuestionSelection(questionID: "q1", optionIDs: ["o1", "o0"])
        ])
        let data = try ClaudeQuestionPayload.reply(original: input, answer: answer, instanceID: "hook")
        let output = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let specific = try XCTUnwrap(output["hookSpecificOutput"] as? [String: Any])
        XCTAssertEqual(specific["hookEventName"] as? String, "PreToolUse")
        XCTAssertEqual(specific["permissionDecision"] as? String, "allow")
        let updated = try XCTUnwrap(specific["updatedInput"] as? [String: Any])
        XCTAssertEqual(updated["answers"] as? [String: String], ["Which letter?": "B", "Which colors?": "Red, Blue"])
        var originalInput = try toolInput(input)
        originalInput["answers"] = updated["answers"]
        XCTAssertEqual(updated as NSDictionary, originalInput as NSDictionary)
        XCTAssertNil(output["systemMessage"])
    }

    func testOtherToolsAndHookEventsCannotProduceQuestionApproval() {
        for (old, new) in [("AskUserQuestion", "Bash"), ("PreToolUse", "PermissionRequest"),
                           ("tool-fixture", ""), ("session-fixture", "")] {
            let changed = Data(String(decoding: input, as: UTF8.self).replacingOccurrences(of: old, with: new).utf8)
            XCTAssertThrowsError(try ClaudeQuestionPayload.decode(changed, instanceID: "hook", receivedUptime: 1000))
        }
    }

    func testExistingAnswersAreNeverOverwritten() throws {
        var original = try toolInput(input)
        original["answers"] = ["Which letter?": "A"]
        XCTAssertThrowsError(try ClaudeQuestionPayload.decode(replacingInput(original), instanceID: "hook", receivedUptime: 1000))
    }

    func testAmbiguousPromptKeysAndCommaDelimitedChoicesStayLocal() throws {
        var original = try toolInput(input)
        var questions = original["questions"] as! [[String: Any]]
        questions[1]["question"] = "Which letter?"
        original["questions"] = questions
        XCTAssertThrowsError(try ClaudeQuestionPayload.decode(replacingInput(original), instanceID: "hook", receivedUptime: 1000))
        let comma = Data(String(decoding: input, as: UTF8.self).replacingOccurrences(of: "\"Red\"", with: "\"Red, amber\"").utf8)
        XCTAssertThrowsError(try ClaudeQuestionPayload.decode(comma, instanceID: "hook", receivedUptime: 1000))
    }

    func testWrongIdentityIncompleteDuplicateOrUnknownSelectionsCannotAnswer() throws {
        let batch = try ClaudeQuestionPayload.decode(input, instanceID: "hook", receivedUptime: 1000)
        let first = QuestionSelection(questionID: "q0", optionIDs: ["o1"])
        let last = QuestionSelection(questionID: "q1", optionIDs: ["o0"])
        let wrong = QuestionKey(provider: .claudeCode, instanceID: "other", sessionID: "session-fixture", requestID: "tool-fixture")
        for answer in [QuestionAnswer(key: wrong, selections: [first, last]),
                       QuestionAnswer(key: batch.key, selections: [first]),
                       QuestionAnswer(key: batch.key, selections: [first, first]),
                       QuestionAnswer(key: batch.key, selections: [first, QuestionSelection(questionID: "q1", optionIDs: ["missing"])]),
                       QuestionAnswer(key: batch.key, selections: [QuestionSelection(questionID: "q0", optionIDs: ["o0", "o1"]), last]),
                       QuestionAnswer(key: batch.key, selections: [first, QuestionSelection(questionID: "q1", optionIDs: ["o0", "o0"])])] {
            XCTAssertThrowsError(try ClaudeQuestionPayload.reply(original: input, answer: answer, instanceID: "hook"))
        }
    }

    func testOversizedFrameAndPanelAreRejectedWithoutTruncating() {
        XCTAssertThrowsError(try ClaudeQuestionPayload.decode(Data(repeating: 32, count: 256 * 1024 + 1), instanceID: "hook", receivedUptime: 1000))
        let long = Data(String(decoding: input, as: UTF8.self).replacingOccurrences(of: "First", with: String(repeating: "x", count: 1801)).utf8)
        XCTAssertThrowsError(try ClaudeQuestionPayload.decode(long, instanceID: "hook", receivedUptime: 1000))
    }

    func testAnswerCannotExpandPreservedInputPastTheHookFrameLimit() throws {
        var original = try toolInput(input)
        var questions = original["questions"] as! [[String: Any]]
        questions[0]["question"] = String(repeating: "a", count: 500)
        questions[1]["question"] = String(repeating: "b", count: 500)
        original["questions"] = questions
        original["padding"] = ""
        let overhead = try replacingInput(original).count
        original["padding"] = String(repeating: "x", count: 256 * 1024 - overhead - 16)
        let preserved = try replacingInput(original)
        let batch = try ClaudeQuestionPayload.decode(preserved, instanceID: "hook", receivedUptime: 1000)
        let answer = QuestionAnswer(key: batch.key, selections: [
            QuestionSelection(questionID: "q0", optionIDs: ["o1"]),
            QuestionSelection(questionID: "q1", optionIDs: ["o0"])
        ])
        XCTAssertThrowsError(try ClaudeQuestionPayload.reply(original: preserved, answer: answer, instanceID: "hook"))
    }

    private func toolInput(_ data: Data) throws -> [String: Any] {
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        return try XCTUnwrap(object["tool_input"] as? [String: Any])
    }

    private func replacingInput(_ value: [String: Any]) throws -> Data {
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: input) as? [String: Any])
        object["tool_input"] = value
        return try JSONSerialization.data(withJSONObject: object)
    }
}
