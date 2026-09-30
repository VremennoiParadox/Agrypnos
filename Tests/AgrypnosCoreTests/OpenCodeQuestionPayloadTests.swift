import Foundation
import XCTest
@testable import AgrypnosCore

final class OpenCodeQuestionPayloadTests: XCTestCase {
    private let request = Data(#"{"id":"que_123","sessionID":"ses_456","questions":[{"question":"Which letter?","header":"Letter","options":[{"label":"A","description":"First"},{"label":"B","description":"Second"}],"custom":true},{"question":"Which colors?","header":"Colors","multiple":true,"options":[{"label":"Red","description":"Warm"},{"label":"Blue","description":"Cool"}]}],"tool":{"messageID":"msg_1","callID":"call_2"}}"#.utf8)

    func testDecodeObservedRequestPreservesQuestionAndChoiceOrder() throws {
        let batch = try OpenCodeQuestionPayload.decode(request, instanceID: "server+directory", receivedUptime: 1000)
        XCTAssertEqual(batch.key, QuestionKey(provider: .openCode, instanceID: "server+directory",
            sessionID: "ses_456", requestID: "que_123"))
        XCTAssertEqual(batch.deadlineUptime, 1600)
        XCTAssertEqual(batch.questions.map(\.id), ["q0", "q1"])
        XCTAssertEqual(batch.questions[0].prompt, "Which letter?")
        XCTAssertEqual(batch.questions[0].options.map(\.id), ["o0", "o1"])
        XCTAssertEqual(batch.questions[0].options.map(\.label), ["A", "B"])
        XCTAssertEqual(batch.questions[0].options[1].detail, "Second")
        XCTAssertTrue(batch.questions[0].allowsFreeText)
        XCTAssertFalse(batch.questions[0].multiple)
        XCTAssertTrue(batch.questions[1].multiple)
        XCTAssertTrue(batch.questions[1].allowsFreeText) // OpenCode defaults custom input to true.
    }

    func testReplyUsesNativeLabelsInQuestionOrder() throws {
        let batch = try OpenCodeQuestionPayload.decode(request, instanceID: "server+directory", receivedUptime: 1000)
        let answer = QuestionAnswer(key: batch.key, selections: [
            QuestionSelection(questionID: "q0", optionIDs: ["o1"]),
            QuestionSelection(questionID: "q1", optionIDs: ["o0", "o1"])
        ])
        let body = try OpenCodeQuestionPayload.reply(original: request, answer: answer,
            instanceID: "server+directory")
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
        XCTAssertEqual(object["answers"] as? [[String]], [["B"], ["Red", "Blue"]])
    }

    func testRejectsWrongIdentityAndPartialOrAmbiguousAnswers() throws {
        let batch = try OpenCodeQuestionPayload.decode(request, instanceID: "server+directory", receivedUptime: 1000)
        let wrong = QuestionAnswer(key: QuestionKey(provider: .openCode, instanceID: "other",
            sessionID: batch.key.sessionID, requestID: batch.key.requestID),
            selections: [QuestionSelection(questionID: "q0", optionIDs: ["o1"])])
        XCTAssertThrowsError(try OpenCodeQuestionPayload.reply(original: request, answer: wrong,
            instanceID: "server+directory"))
        let partial = QuestionAnswer(key: batch.key, selections: [QuestionSelection(questionID: "q0", optionIDs: ["o1"])])
        XCTAssertThrowsError(try OpenCodeQuestionPayload.reply(original: request, answer: partial,
            instanceID: "server+directory"))
        let invalid = QuestionAnswer(key: batch.key, selections: [
            QuestionSelection(questionID: "q0", optionIDs: ["o1"]),
            QuestionSelection(questionID: "q1", optionIDs: ["missing"])
        ])
        XCTAssertThrowsError(try OpenCodeQuestionPayload.reply(original: request, answer: invalid,
            instanceID: "server+directory"))
    }

    func testRejectsDuplicateLabelsAndUnsupportedEmptyChoiceQuestion() {
        for json in [
            #"{"id":"que_1","sessionID":"ses_1","questions":[{"question":"Which?","header":"Choice","options":[{"label":"Same","description":"A"},{"label":"Same","description":"B"}]}]}"#,
            #"{"id":"que_1","sessionID":"ses_1","questions":[{"question":"Type something","header":"Text","options":[]}]}"#
        ] {
            XCTAssertThrowsError(try OpenCodeQuestionPayload.decode(Data(json.utf8),
                instanceID: "server+directory", receivedUptime: 1000))
        }
    }

    func testGlobalEventFiltersDirectoryAndKeepsNativeRequest() throws {
        let event = Data(#"{"directory":"/project","payload":{"type":"question.asked","properties":{"id":"que_123","sessionID":"ses_456","questions":[{"question":"Which letter?","header":"Letter","options":[{"label":"A","description":"First"},{"label":"B","description":"Second"}]}]}}}"#.utf8)
        let observed = try OpenCodeQuestionPayload.event(event, instanceID: "instance",
            directory: "/project", receivedUptime: 1000)
        guard case let .asked(batch, original) = observed else { return XCTFail("Missing question") }
        XCTAssertEqual(batch.key.requestID, "que_123")
        XCTAssertEqual(try OpenCodeQuestionPayload.decode(original, instanceID: "instance",
            receivedUptime: 1000), batch)
        XCTAssertNil(try OpenCodeQuestionPayload.event(event, instanceID: "instance",
            directory: "/other", receivedUptime: 1000))
    }

    func testGlobalResolvedEventUsesOriginalRequestIdentity() throws {
        for type in ["question.replied", "question.rejected"] {
            let event = Data(#"{"directory":"/project","payload":{"type":"\#(type)","properties":{"sessionID":"ses_456","requestID":"que_123"}}}"#.utf8)
            let observed = try OpenCodeQuestionPayload.event(event, instanceID: "instance",
                directory: "/project", receivedUptime: 1000)
            XCTAssertEqual(observed, .resolved(QuestionKey(provider: .openCode,
                instanceID: "instance", sessionID: "ses_456", requestID: "que_123")))
        }
    }

    func testIgnoresGlobalHeartbeatWithoutDirectory() throws {
        let heartbeat = Data(#"{"payload":{"type":"server.heartbeat","properties":{}}}"#.utf8)
        XCTAssertNil(try OpenCodeQuestionPayload.event(heartbeat, instanceID: "instance",
            directory: "/project", receivedUptime: 1000))
    }
}
