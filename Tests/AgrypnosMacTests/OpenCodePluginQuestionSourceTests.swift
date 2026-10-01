import Foundation
import XCTest
import AgrypnosCore
@testable import AgrypnosMac

@MainActor
final class OpenCodePluginQuestionSourceTests: XCTestCase {
    let original = Data(#"{"id":"que_abc","sessionID":"same","questions":[{"question":"Choose","options":[{"label":"A","description":"First"},{"label":"B","description":"Second"}],"custom":false}]}"#.utf8)
    func testTwoInstancesKeepOriginalOwnershipAndOnceOnlyReply() async throws {
        var batches: [QuestionBatch] = []
        var submissions: [(QuestionAnswer) async -> QuestionDelivery] = []
        var source: OpenCodePluginQuestionSource!
        let configuration = config()
        source = OpenCodePluginQuestionSource(configuration: configuration, uptime: { 10 }, receive: { batch, submit, _ in
            batches.append(batch); submissions.append(submit); return true
        }, resolved: { _ in })
        source.sendFrame = { message, id in
            if case let .reply(attempt, session, request, answers) = message {
                XCTAssertEqual(answers, [["B"]])
                source.ingest(.resolved(sessionID: session, requestID: request), from: id)
                source.ingest(.result(attemptID: attempt, delivery: .accepted), from: id)
            }
            return true
        }
        let ids = [OpenCodeBridgeConnectionID(), OpenCodeBridgeConnectionID()]
        for id in ids { source.ingest(hello(configuration), from: id); source.ingest(.asked(original: original), from: id) }
        XCTAssertEqual(batches.count, 2); XCTAssertNotEqual(batches[0].key, batches[1].key)
        let answer = answer(batches[0])
        let first = await submissions[0](answer), second = await submissions[0](answer)
        XCTAssertEqual(first, .accepted); XCTAssertEqual(second, .rejected)
        source.stop()
    }
    func testLostAcknowledgmentNeverRetriesAndSpoofedResultIsIgnored() async throws {
        var batch: QuestionBatch!, submit: ((QuestionAnswer) async -> QuestionDelivery)!
        let configuration = config(), id = OpenCodeBridgeConnectionID()
        let source = OpenCodePluginQuestionSource(configuration: configuration, uptime: { 10 }, receive: { b, s, _ in
            batch = b; submit = s; return true
        }, resolved: { _ in }, resultTimeout: 0.02)
        var attempts = 0
        source.sendFrame = { message, _ in
            if case let .reply(attempt, _, _, _) = message {
                attempts += 1
                source.ingest(.result(attemptID: attempt, delivery: .accepted), from: OpenCodeBridgeConnectionID())
            }
            return true
        }
        source.ingest(hello(configuration), from: id); source.ingest(.asked(original: original), from: id)
        let first = await submit(answer(batch)), second = await submit(answer(batch))
        XCTAssertEqual(first, .unconfirmed); XCTAssertEqual(second, .rejected); XCTAssertEqual(attempts, 1)
        source.stop()
    }
    func testDuplicateChangedExpiredAndUnknownSnapshotsDoNotExtendDeadline() async throws {
        var now = 10.0, batches: [QuestionBatch] = [], cleared: [QuestionKey] = []
        var submit: ((QuestionAnswer) async -> QuestionDelivery)!
        let configuration = config(), id = OpenCodeBridgeConnectionID()
        let source = OpenCodePluginQuestionSource(configuration: configuration, uptime: { now }, receive: { b, s, _ in
            batches.append(b); submit = s; return true
        }, resolved: { cleared.append($0) })
        source.sendFrame = { _, _ in true }
        source.ingest(hello(configuration), from: id)
        let old = Data(String(decoding: original, as: UTF8.self).replacingOccurrences(of: "que_abc", with: "que_Old").utf8)
        source.ingest(.snapshot(originals: [old]), from: id); XCTAssertTrue(batches.isEmpty)
        source.ingest(.asked(original: original), from: id)
        now = 20; source.ingest(.asked(original: original), from: id)
        XCTAssertEqual(batches.count, 1); XCTAssertEqual(batches[0].deadlineUptime, 610)
        now = 611
        let delivery = await submit(answer(batches[0])); XCTAssertEqual(delivery, .rejected)
        source.ingest(.resolved(sessionID: "same", requestID: "que_abc"), from: id)
        XCTAssertEqual(cleared, [batches[0].key])
        source.stop()
    }
    func testWrongGenerationAndLocalWinnerHaveNoReply() async throws {
        let configuration = config(), id = OpenCodeBridgeConnectionID()
        var batch: QuestionBatch!, submit: ((QuestionAnswer) async -> QuestionDelivery)!
        let source = OpenCodePluginQuestionSource(configuration: configuration, uptime: { 10 }, receive: { b, s, _ in
            batch = b; submit = s; return true
        }, resolved: { _ in })
        source.sendFrame = { _, _ in XCTFail("no reply"); return false }
        source.ingest(hello(config()), from: id); source.ingest(.asked(original: original), from: id)
        XCTAssertNil(batch)
        source.ingest(hello(configuration), from: id); source.ingest(.asked(original: original), from: id)
        source.ingest(.resolved(sessionID: "same", requestID: "que_abc"), from: id)
        let delivery = await submit(answer(batch)); XCTAssertEqual(delivery, .rejected)
        source.stop()
    }
    func testUnknownSnapshotCannotReplayLaterAsAsked() {
        let configuration = config(), id = OpenCodeBridgeConnectionID()
        var received = 0
        let source = OpenCodePluginQuestionSource(configuration: configuration, uptime: { 20 }, receive: { _, _, _ in
            received += 1; return true
        }, resolved: { _ in })
        source.ingest(hello(configuration), from: id)
        source.ingest(.snapshot(originals: [original]), from: id)
        source.ingest(.asked(original: original), from: id)
        XCTAssertEqual(received, 0)
        source.stop()
    }
    func testReconnectRetainsDeadlineAndNativeAnswerClearsExpiredIdentity() async throws {
        let configuration = config(), first = OpenCodeBridgeConnectionID(), second = OpenCodeBridgeConnectionID()
        let greeting = hello(configuration)
        var now = 0.0, batches: [QuestionBatch] = [], cleared: [QuestionKey] = []
        var local: (() async -> Void)!
        let source = OpenCodePluginQuestionSource(configuration: configuration, uptime: { now }, receive: { b, _, l in
            batches.append(b); local = l; return true
        }, resolved: { cleared.append($0) })
        source.sendFrame = { _, _ in true }
        source.ingest(greeting, from: first); source.ingest(.asked(original: original), from: first)
        source.disconnected(first); now = 200
        source.ingest(greeting, from: second); source.ingest(.snapshot(originals: [original]), from: second)
        XCTAssertEqual(batches.count, 2); XCTAssertEqual(batches[1].deadlineUptime, 600)
        await local(); now = 601
        source.disconnected(second)
        let third = OpenCodeBridgeConnectionID()
        source.ingest(greeting, from: third); source.ingest(.snapshot(originals: []), from: third)
        XCTAssertEqual(cleared.last, batches[0].key)
        XCTAssertEqual(batches.count, 2)
        source.stop()
    }
    private func answer(_ batch: QuestionBatch) -> QuestionAnswer {
        QuestionAnswer(key: batch.key, selections: [.init(questionID: "q0", optionIDs: ["o1"])])
    }
    private func config() -> OpenCodeBridgeConfiguration {
        .init(socketURL: URL(fileURLWithPath: "/private/tmp/ag-source-" + UUID().uuidString + "/s.sock"), token: String(repeating: "a", count: 64), generation: UUID())
    }
    private func hello(_ config: OpenCodeBridgeConfiguration) -> OpenCodeBridgeMessage {
        .hello(protocolVersion: 1, token: config.token, instanceID: UUID(), generation: config.generation,
            hostVersion: "1.18.32", directory: "/project", projectLabel: "project")
    }
}
