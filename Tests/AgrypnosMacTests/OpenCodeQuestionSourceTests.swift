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

    func testNativeResolvedEventDuringOwnSendDoesNotDiscardTheHTTPOutcome() async throws {
        for (status, expected) in [(200, QuestionDelivery.accepted), (404, .rejected)] {
            let fixture = try Fixture()
            fixture.source.ingest(asked)
            let batch = try XCTUnwrap(fixture.observed.first)
            fixture.response = QuestionHTTPResponse(statusCode: status, body: Data("true".utf8))
            fixture.onRequest = { [weak fixture, resolved] in fixture?.source.ingest(resolved) }
            let result = await fixture.source.submit(key: batch.key, answer: QuestionAnswer(key: batch.key,
                selections: [QuestionSelection(questionID: "q0", optionIDs: ["o1"])]))
            XCTAssertEqual(result, expected)
            XCTAssertTrue(fixture.cleared.isEmpty)
        }
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
        XCTAssertEqual(fixture.requests.count, 1)
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

    func testLostEventStreamMakesPendingPhoneAnswerInert() async throws {
        let fixture = try Fixture()
        fixture.source.ingest(asked)
        let batch = try XCTUnwrap(fixture.observed.first)
        fixture.source.connectionLost()
        XCTAssertEqual(fixture.cleared, [batch.key])
        let answer = QuestionAnswer(key: batch.key, selections: [QuestionSelection(questionID: "q0", optionIDs: ["o1"])])
        let delivery = await fixture.source.submit(key: batch.key, answer: answer)
        XCTAssertEqual(delivery, .rejected)
        XCTAssertTrue(fixture.requests.isEmpty)
    }

    func testEventFramesPreserveBlankSeparatorsAcrossBytesAndMultilineData() {
        var frames = OpenCodeEventFrames()
        let stream = ": heartbeat\r\ndata: first\r\ndata: second\r\n\r\ndata: third\n\n"
        let result = stream.utf8.compactMap { frames.append($0) }
        XCTAssertEqual(result.map { String(decoding: $0, as: UTF8.self) }, ["first\nsecond", "third"])
    }

    func testOversizedEventIsDroppedUntilItsSeparator() {
        var frames = OpenCodeEventFrames()
        let oversized = "data: " + String(repeating: "x", count: 256 * 1024 + 1) + "\ndata: tail\n\n"
        XCTAssertTrue(oversized.utf8.compactMap { frames.append($0) }.isEmpty)
        let result = "data: valid\n\n".utf8.compactMap { frames.append($0) }
        XCTAssertEqual(result, [Data("valid".utf8)])
    }

    func testReconnectReissuesOnlyVerifiedOriginalQuestionWithoutExtendingDeadline() throws {
        let fixture = try Fixture()
        fixture.source.ingest(asked)
        let original = try XCTUnwrap(fixture.observed.first)
        fixture.source.connectionLost()
        fixture.now = 1300
        try fixture.source.reconcilePending(pending())
        XCTAssertEqual(fixture.observed, [original, original])
        XCTAssertEqual(fixture.observed.last?.deadlineUptime, 1600)
    }

    func testReconnectDoesNotForwardUnknownChangedExpiredOrAttemptedQuestions() async throws {
        let unknown = try Fixture()
        try unknown.source.reconcilePending(pending())
        XCTAssertTrue(unknown.observed.isEmpty)

        let changed = try Fixture()
        changed.source.ingest(asked)
        changed.source.connectionLost()
        try changed.source.reconcilePending(Data(String(decoding: pending(), as: UTF8.self)
            .replacingOccurrences(of: "Second", with: "Changed").utf8))
        XCTAssertEqual(changed.observed.count, 1)

        let expired = try Fixture()
        expired.source.ingest(asked)
        expired.source.connectionLost()
        expired.now = 1600
        try expired.source.reconcilePending(pending())
        XCTAssertEqual(expired.observed.count, 1)

        let attempted = try Fixture()
        attempted.source.ingest(asked)
        let batch = try XCTUnwrap(attempted.observed.first)
        attempted.response = QuestionHTTPResponse(statusCode: nil, body: Data())
        _ = await attempted.source.submit(key: batch.key, answer: QuestionAnswer(key: batch.key,
            selections: [QuestionSelection(questionID: "q0", optionIDs: ["o1"])]))
        attempted.source.connectionLost()
        try attempted.source.reconcilePending(pending())
        XCTAssertEqual(attempted.observed.count, 1)
    }

    private func pending() -> Data {
        let envelope = try! JSONSerialization.jsonObject(with: asked) as! [String: Any]
        let payload = envelope["payload"] as! [String: Any]
        return try! JSONSerialization.data(withJSONObject: [payload["properties"]!])
    }

    func testDroppingOwnerStopsBackgroundSource() async throws {
        let contacted = expectation(description: "health check started")
        var source: OpenCodeQuestionSource? = OpenCodeQuestionSource(configuration: try Fixture().config,
            exchange: { _ in
                contacted.fulfill()
                return QuestionHTTPResponse(statusCode: nil, body: Data())
            }, receive: { _ in true }, resolved: { _ in })
        weak var released = source
        source?.start()
        await fulfillment(of: [contacted], timeout: 1)
        source = nil
        XCTAssertNil(released)
        released?.stop()
    }

    func testRunningSourceReceivesQuestionFromFoundationByteStream() async throws {
        let observed = expectation(description: "native SSE question received")
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [OpenCodeStreamFixture.self]
        let session = URLSession(configuration: configuration)
        let source = OpenCodeQuestionSource(configuration: try Fixture().config, exchange: { request in
            let body = request.url?.path == "/global/health"
                ? Data(#"{"healthy":true,"version":"1.18.32"}"#.utf8) : Data("[]".utf8)
            return QuestionHTTPResponse(statusCode: 200, body: body)
        }, streamSession: session, receive: { batch in
            XCTAssertEqual(batch.key.requestID, "que_123")
            XCTAssertEqual(batch.questions.first?.prompt, "Which letter?")
            observed.fulfill()
            return true
        }, resolved: { _ in })
        source.start()
        await fulfillment(of: [observed], timeout: 1)
        source.stop()
    }
}

private final class OpenCodeStreamFixture: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "text/event-stream"])!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        let event = #"data: {"directory":"/project","payload":{"type":"question.asked","properties":{"id":"que_123","sessionID":"ses_456","questions":[{"question":"Which letter?","header":"Letter","options":[{"label":"A","description":"First"},{"label":"B","description":"Second"}]}]}}}"#
        client?.urlProtocol(self, didLoad: Data((event + "\n\n").utf8))
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}

@MainActor
private final class Fixture {
    var requests: [URLRequest] = []
    var observed: [QuestionBatch] = []
    var cleared: [QuestionKey] = []
    var response = QuestionHTTPResponse(statusCode: 200, body: Data("true".utf8))
    var now: TimeInterval = 1000
    var onRequest: (() -> Void)?
    let config: OpenCodeQuestionConfiguration
    lazy var source = OpenCodeQuestionSource(configuration: config, exchange: { [weak self] request in
        guard let self else { return QuestionHTTPResponse(statusCode: nil, body: Data()) }
        requests.append(request)
        onRequest?()
        return response
    }, uptime: { [weak self] in self?.now ?? 0 }, receive: { [weak self] batch in
        self?.observed.append(batch)
        return true
    }, resolved: { [weak self] key in self?.cleared.append(key) })

    init() throws {
        config = try OpenCodeQuestionConfiguration(endpoint: URL(string: "http://127.0.0.1:4096")!, directory: "/project", password: "fixture")
    }
}
