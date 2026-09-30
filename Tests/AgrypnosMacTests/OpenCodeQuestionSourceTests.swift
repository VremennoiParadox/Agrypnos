import Foundation
import XCTest
import AgrypnosCore
@testable import AgrypnosMac

@MainActor
final class OpenCodeQuestionSourceTests: XCTestCase {
    private let asked = Data(#"{"directory":"/project","payload":{"type":"question.asked","properties":{"id":"que_123","sessionID":"ses_456","questions":[{"question":"Which letter?","header":"Letter","options":[{"label":"A","description":"First"},{"label":"B","description":"Second"}]}]}}}"#.utf8)
    private let resolved = Data(#"{"directory":"/project","payload":{"type":"question.replied","properties":{"sessionID":"ses_456","requestID":"que_123"}}}"#.utf8)

    func testConfigurationRequiresExplicitLoopbackServerAndAbsoluteDirectory() throws {
        XCTAssertNoThrow(try OpenCodeQuestionConfiguration(endpoint: URL(string: "http://127.0.0.1:4096")!, directory: "/project", password: "fixture"))
        for endpoint in ["http://example.com:4096", "https://127.0.0.1:4096", "http://127.0.0.1:4096/other", "http://user@127.0.0.1:4096"] {
            XCTAssertThrowsError(try OpenCodeQuestionConfiguration(endpoint: URL(string: endpoint)!, directory: "/project"))
        }
        XCTAssertThrowsError(try OpenCodeQuestionConfiguration(endpoint: URL(string: "http://127.0.0.1:4096")!, directory: "relative"))
    }

    func testObservedQuestionPostsNativeLabelsToTheSameServerAndDirectory() async throws {
        let fixture = try Fixture()
        fixture.source.ingest(asked)
        let batch = try XCTUnwrap(fixture.observed.first)
        let answer = QuestionAnswer(key: batch.key, selections: [QuestionSelection(questionID: "q0", optionIDs: ["o1"])])
        let delivery = await fixture.source.submit(key: batch.key, answer: answer)
        XCTAssertEqual(delivery, .accepted)
        XCTAssertEqual(fixture.requests.count, 1)
        let request = try XCTUnwrap(fixture.requests.first)
        XCTAssertEqual(request.url?.host, "127.0.0.1")
        XCTAssertEqual(request.url?.path, "/question/que_123/reply")
        XCTAssertEqual(URLComponents(url: try XCTUnwrap(request.url), resolvingAgainstBaseURL: false)?.queryItems?.first?.value, "/project")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Basic " + Data("opencode:fixture".utf8).base64EncodedString())
        XCTAssertEqual(request.httpMethod, "POST")
        let body = try XCTUnwrap(request.httpBody)
        XCTAssertEqual((try JSONSerialization.jsonObject(with: body) as? [String: Any])?["answers"] as? [[String]], [["B"]])
    }

    func testLocalResolutionMakesStalePhoneAnswerInert() async throws {
        let fixture = try Fixture()
        fixture.source.ingest(asked)
        let batch = try XCTUnwrap(fixture.observed.first)
        fixture.source.ingest(resolved)
        XCTAssertEqual(fixture.cleared, [batch.key])
        let answer = QuestionAnswer(key: batch.key, selections: [QuestionSelection(questionID: "q0", optionIDs: ["o1"])])
        let delivery = await fixture.source.submit(key: batch.key, answer: answer)
        XCTAssertEqual(delivery, .rejected)
        XCTAssertTrue(fixture.requests.isEmpty)
    }

    func testAmbiguousOrStaleHTTPResultIsNeverAcceptedOrRetried() async throws {
        let fixture = try Fixture()
        fixture.source.ingest(asked)
        let batch = try XCTUnwrap(fixture.observed.first)
        let answer = QuestionAnswer(key: batch.key, selections: [QuestionSelection(questionID: "q0", optionIDs: ["o1"])])
        fixture.response = QuestionHTTPResponse(statusCode: nil, body: Data())
        let uncertain = await fixture.source.submit(key: batch.key, answer: answer)
        XCTAssertEqual(uncertain, .unconfirmed)
        fixture.response = QuestionHTTPResponse(statusCode: 404, body: Data())
        let stale = await fixture.source.submit(key: batch.key, answer: answer)
        XCTAssertEqual(stale, .rejected)
        XCTAssertEqual(fixture.requests.count, 2)
        let another = try Fixture()
        another.source.ingest(asked)
        another.response = QuestionHTTPResponse(statusCode: 200, body: Data("false".utf8))
        let falseSuccess = await another.source.submit(key: answer.key, answer: answer)
        XCTAssertEqual(falseSuccess, .unconfirmed)
        XCTAssertEqual(another.requests.count, 1)
    }

    func testDuplicateAndChangedNativeEventsDoNotExtendOrReplaceOriginalControls() throws {
        let fixture = try Fixture()
        fixture.source.ingest(asked)
        fixture.now = 1300
        fixture.source.ingest(asked)
        XCTAssertEqual(fixture.observed.count, 1)
        XCTAssertEqual(fixture.observed.first?.receivedUptime, 1000)
        let changed = Data(String(decoding: asked, as: UTF8.self)
            .replacingOccurrences(of: "Second", with: "Changed").utf8)
        fixture.source.ingest(changed)
        XCTAssertEqual(fixture.cleared, [fixture.observed[0].key])
        XCTAssertEqual(fixture.observed.count, 1)
    }

    func testStoppingSourceClearsPendingControls() async throws {
        let fixture = try Fixture()
        fixture.source.ingest(asked)
        let batch = try XCTUnwrap(fixture.observed.first)
        fixture.source.stop()
        XCTAssertEqual(fixture.cleared, [batch.key])
        let answer = QuestionAnswer(key: batch.key, selections: [QuestionSelection(questionID: "q0", optionIDs: ["o1"])])
        let delivery = await fixture.source.submit(key: batch.key, answer: answer)
        XCTAssertEqual(delivery, .rejected)
        XCTAssertTrue(fixture.requests.isEmpty)
    }
}

@MainActor
private final class Fixture {
    var requests: [URLRequest] = []
    var observed: [QuestionBatch] = []
    var cleared: [QuestionKey] = []
    var response = QuestionHTTPResponse(statusCode: 200, body: Data("true".utf8))
    var now: TimeInterval = 1000
    let config: OpenCodeQuestionConfiguration
    lazy var source = OpenCodeQuestionSource(configuration: config, exchange: { [weak self] request in
        guard let self else { return QuestionHTTPResponse(statusCode: nil, body: Data()) }
        requests.append(request)
        return response
    }, uptime: { [weak self] in self?.now ?? 0 }, receive: { [weak self] batch in
        self?.observed.append(batch)
        return true
    }, resolved: { [weak self] key in self?.cleared.append(key) })

    init() throws {
        config = try OpenCodeQuestionConfiguration(endpoint: URL(string: "http://127.0.0.1:4096")!, directory: "/project", password: "fixture")
    }
}
