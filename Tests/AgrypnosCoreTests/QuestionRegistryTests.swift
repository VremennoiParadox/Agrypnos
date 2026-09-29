import Foundation
import XCTest
@testable import AgrypnosCore

final class QuestionRegistryTests: XCTestCase {
    func bound(_ batch: QuestionBatch = questionBatch()) -> (QuestionRegistry, UUID) {
        var registry = QuestionRegistry()
        let handle = UUID()
        XCTAssertTrue(registry.insert(batch, handle: handle))
        registry.bindMessage(handle: handle, reference: telegramQuestionRef)
        registry.bindMessage(handle: handle, reference: discordQuestionRef)
        return (registry, handle)
    }

    func selectAndReview(_ registry: inout QuestionRegistry, handle: UUID,
                         reference: QuestionMessageRef = telegramQuestionRef,
                         option: String = "o1", now: TimeInterval = 1100) {
        questionAction(.choose(questionID: "q0", optionID: option), registry: &registry,
            handle: handle, reference: reference, now: now)
        questionAction(.next, registry: &registry, handle: handle, reference: reference, now: now)
    }

    func testFirstCompleteSubmissionWinsAcrossBots() {
        var (registry, handle) = bound()
        selectAndReview(&registry, handle: handle)
        selectAndReview(&registry, handle: handle, reference: discordQuestionRef, option: "o0")
        guard case let .submit(submittedHandle, answer) = questionAction(.send,
            registry: &registry, handle: handle) else { return XCTFail("No submission") }
        XCTAssertEqual(submittedHandle, handle)
        XCTAssertEqual(answer.key, questionKey())
        XCTAssertEqual(answer.selections.first?.optionIDs, ["o1"])
        XCTAssertEqual(questionAction(.send, registry: &registry, handle: handle,
            reference: discordQuestionRef), .ignore)
    }

    func testDraftsNeverMixChannels() {
        var (registry, handle) = bound(questionBatch(count: 2))
        selectAndReview(&registry, handle: handle)
        questionAction(.choose(questionID: "q0", optionID: "o0"), registry: &registry,
            handle: handle, reference: discordQuestionRef)
        XCTAssertEqual(questionAction(.send, registry: &registry, handle: handle), .ignore)
        XCTAssertEqual(registry.view(handle: handle, reference: discordQuestionRef)?.page, 0)
        XCTAssertEqual(registry.view(handle: handle, reference: telegramQuestionRef)?.page, 1)
    }

    func testWrongUserMessageGenerationOrOptionIsIgnored() throws {
        var (registry, handle) = bound()
        let view = try XCTUnwrap(registry.view(handle: handle, reference: telegramQuestionRef))
        let token = try XCTUnwrap(view.controls.first?.token)
        let wrongMessage = QuestionMessageRef(destination: .telegram, destinationID: "chat", messageID: "999")
        for (ref, user, generation, action) in [
            (telegramQuestionRef, "stranger", view.generation, token),
            (wrongMessage, "owner", view.generation, token),
            (telegramQuestionRef, "owner", view.generation + 1, token),
            (telegramQuestionRef, "owner", view.generation, "bogus")
        ] {
            XCTAssertEqual(registry.handle(QuestionCallback(reference: ref, senderID: user,
                actionToken: action, generation: generation), authorizedUserID: "owner", now: 1100), .ignore)
        }
        XCTAssertEqual(questionAction(.choose(questionID: "q0", optionID: "absent"),
            registry: &registry, handle: handle), .ignore)
    }

    func testDuplicateEventDoesNotExtendDeadline() {
        var (registry, handle) = bound()
        let replay = QuestionBatch(key: questionKey(), projectLabel: "Example",
            questions: questionBatch().questions, receivedUptime: 1500, deadlineUptime: 2100)
        XCTAssertFalse(registry.insert(replay, handle: UUID()))
        XCTAssertEqual(registry.view(handle: handle, reference: telegramQuestionRef)?.batch.deadlineUptime, 1600)
        XCTAssertEqual(registry.expire(now: 1600), [questionKey()])
        XCTAssertTrue(registry.expire(now: 1601).isEmpty)
    }

    func testChangedPayloadMakesOldControlsInert() {
        var (registry, handle) = bound()
        let changed = QuestionBatch(key: questionKey(), questions: [AgentQuestion(id: "q0",
            prompt: "Different?", options: [QuestionOption(id: "x", label: "Different")])],
            receivedUptime: 1000, deadlineUptime: 1600)
        XCTAssertFalse(registry.insert(changed, handle: UUID()))
        XCTAssertEqual(questionAction(.returnLocal, registry: &registry, handle: handle), .ignore)
        XCTAssertTrue(registry.pendingDeadlines.isEmpty)
    }

    func testExpiryDoesNotSelectDefaultOrSubmitPartialDraft() {
        var (registry, handle) = bound()
        questionAction(.choose(questionID: "q0", optionID: "o0"), registry: &registry, handle: handle)
        XCTAssertEqual(registry.expire(now: 1600), [questionKey()])
        XCTAssertEqual(questionAction(.send, registry: &registry, handle: handle, now: 1601), .ignore)
        XCTAssertTrue(registry.view(handle: handle, reference: telegramQuestionRef)?.controls.isEmpty == true)
    }

    func testAnswerBeforeDeadlineStopsTimeoutWhileDeliveryIsUnconfirmed() {
        var (registry, handle) = bound()
        selectAndReview(&registry, handle: handle, now: 1599.9)
        guard case .submit = questionAction(.send, registry: &registry, handle: handle,
            now: 1599.9) else { return XCTFail("Submission was not reserved") }
        XCTAssertTrue(registry.pendingDeadlines.isEmpty)
        XCTAssertTrue(registry.expire(now: 1600).isEmpty)
        registry.complete(handle: handle, result: .unconfirmed)
        XCTAssertEqual(registry.view(handle: handle, reference: telegramQuestionRef)?.state, .delivered(.unconfirmed))
        XCTAssertEqual(questionAction(.send, registry: &registry, handle: handle, now: 1601), .ignore)
    }

    func testCancellationAndSleepMakeCapturedTokensInert() throws {
        for sleep in [false, true] {
            var (registry, handle) = bound()
            let view = try XCTUnwrap(registry.view(handle: handle, reference: telegramQuestionRef))
            let token = try XCTUnwrap(view.controls.first?.token)
            if sleep { registry.invalidateAll() } else { registry.cancel(key: questionKey()) }
            XCTAssertEqual(registry.handle(QuestionCallback(reference: telegramQuestionRef,
                senderID: "owner", actionToken: token, generation: view.generation),
                authorizedUserID: "owner", now: 1100), .ignore)
        }
    }

    func testMultiSelectionUsesOriginalOptionOrder() {
        var (registry, handle) = bound(questionBatch(optionCount: 3, multiple: true))
        for option in ["o2", "o0"] {
            questionAction(.choose(questionID: "q0", optionID: option), registry: &registry, handle: handle)
        }
        questionAction(.next, registry: &registry, handle: handle)
        guard case let .submit(_, answer) = questionAction(.send, registry: &registry,
            handle: handle) else { return XCTFail("No submission") }
        XCTAssertEqual(answer.selections.first?.optionIDs, ["o0", "o2"])
    }

    func testLimitsKeepOverflowLocalIncludingTerminalRecords() {
        var registry = QuestionRegistry()
        XCTAssertTrue(registry.insert(questionBatch(count: 4, optionCount: 20), handle: UUID()))
        XCTAssertFalse(registry.insert(questionBatch("too-many-questions", count: 5), handle: UUID()))
        XCTAssertFalse(registry.insert(questionBatch("too-many-options", optionCount: 21), handle: UUID()))
        for index in 1..<32 { XCTAssertTrue(registry.insert(questionBatch("q\(index)"), handle: UUID())) }
        _ = registry.expire(now: 1600)
        XCTAssertFalse(registry.insert(questionBatch("overflow"), handle: UUID()))
        registry.cancel(key: questionKey())
        XCTAssertTrue(registry.insert(questionBatch("reclaimed"), handle: UUID()))
    }

    func testAmbiguousLabelsAndEmptyIDsAreRejected() {
        for options in [
            [QuestionOption(id: "a", label: "Same"), QuestionOption(id: "b", label: "Same")],
            [QuestionOption(id: "", label: "A")],
            [QuestionOption(id: "a", label: "A"), QuestionOption(id: "a", label: "B")]
        ] {
            var registry = QuestionRegistry()
            XCTAssertFalse(registry.insert(QuestionBatch(key: questionKey(), questions: [
                AgentQuestion(id: "q0", prompt: "Choose?", options: options)],
                receivedUptime: 1000, deadlineUptime: 1600), handle: UUID()))
        }
    }

    func testUnicodePanelIsPreservedAndOversizedBatchRejectedWhole() {
        let question = AgentQuestion(id: "q0", prompt: "選ぶ 🌙?",
            options: [QuestionOption(id: "a", label: "はい", detail: "Résumé 👨‍👩‍👧‍👦")])
        let batch = QuestionBatch(key: questionKey(), questions: [question],
            receivedUptime: 1000, deadlineUptime: 1600)
        let (registry, handle) = bound(batch)
        let panel = registry.view(handle: handle, reference: telegramQuestionRef)?.batch.panelText(at: 0)
        XCTAssertTrue(panel?.contains("選ぶ 🌙?") == true)
        XCTAssertTrue(panel?.contains("Résumé 👨‍👩‍👧‍👦") == true)
        var other = QuestionRegistry()
        let huge = AgentQuestion(id: "big", prompt: String(repeating: "🌙", count: 901), options: question.options)
        XCTAssertFalse(other.insert(QuestionBatch(key: questionKey(), questions: [question, huge],
            receivedUptime: 1000, deadlineUptime: 1600), handle: UUID()))
    }
    func testSameBotMessageCannotBindTwoSourceRequests() {
        var (registry, _) = bound()
        let other = UUID()
        XCTAssertTrue(registry.insert(questionBatch("other"), handle: other))
        XCTAssertFalse(registry.bindMessage(handle: other, reference: telegramQuestionRef))
        XCTAssertNil(registry.view(handle: other, reference: telegramQuestionRef))
    }

    func testEarlierNativeDeadlineShortensAnExistingRequest() {
        var (registry, handle) = bound()
        let shortened = QuestionBatch(key: questionKey(), projectLabel: "Example",
            questions: questionBatch().questions, receivedUptime: 1000, deadlineUptime: 1500)
        XCTAssertFalse(registry.insert(shortened, handle: UUID()))
        XCTAssertEqual(registry.view(handle: handle, reference: telegramQuestionRef)?.batch.deadlineUptime, 1500)
        XCTAssertEqual(registry.expire(now: 1500), [questionKey()])
    }

    func testWholeBatchReviewRequiredBeforeSending() {
        var (registry, handle) = bound(questionBatch(count: 2))
        selectAndReview(&registry, handle: handle)
        questionAction(.choose(questionID: "q1", optionID: "o0"), registry: &registry, handle: handle)
        questionAction(.next, registry: &registry, handle: handle)
        XCTAssertEqual(questionAction(.send, registry: &registry, handle: handle), .ignore)
        questionAction(.next, registry: &registry, handle: handle)
        guard case let .submit(_, answer) = questionAction(.send, registry: &registry,
            handle: handle) else { return XCTFail("Batch review did not submit") }
        XCTAssertEqual(answer.selections.map(\.optionIDs), [["o1"], ["o0"]])
    }

    func testQuestionWindowNeverExceedsTenMinutes() {
        let batch = QuestionBatch(key: questionKey(), questions: questionBatch().questions,
            receivedUptime: 1000, deadlineUptime: 9000)
        var (registry, handle) = bound(batch)
        selectAndReview(&registry, handle: handle, now: 1599)
        XCTAssertEqual(questionAction(.send, registry: &registry, handle: handle, now: 1600), .ignore)
        XCTAssertEqual(registry.expire(now: 1600), [questionKey()])
    }

    func testClockAndIdentityValidationLeaveMalformedBatchLocal() {
        for (received, deadline) in [(Double.nan, 1600), (1000, Double.nan),
                                     (-1, 500), (1000, 1000), (1000, Double.infinity)] {
            var registry = QuestionRegistry()
            XCTAssertFalse(registry.insert(QuestionBatch(key: questionKey(), questions: questionBatch().questions,
                receivedUptime: received, deadlineUptime: deadline), handle: UUID()))
        }
        var registry = QuestionRegistry()
        let empty = QuestionKey(provider: .cursor, instanceID: "", sessionID: "s", requestID: "q")
        XCTAssertFalse(registry.insert(QuestionBatch(key: empty, questions: questionBatch().questions,
            receivedUptime: 1000, deadlineUptime: 1600), handle: UUID()))
    }

    func testSourceClearedBeforeDeliveryCannotBecomeAccepted() {
        var (registry, handle) = bound()
        selectAndReview(&registry, handle: handle)
        guard case .submit = questionAction(.send, registry: &registry, handle: handle)
        else { return XCTFail("No submission") }
        registry.cancel(key: questionKey())
        registry.complete(handle: handle, result: .accepted)
        XCTAssertNil(registry.view(handle: handle, reference: telegramQuestionRef))
    }

    func testMalformedChangedPayloadAlsoInvalidatesOldControls() {
        var (registry, handle) = bound()
        let changed = QuestionBatch(key: questionKey(), questions: [],
            receivedUptime: 1000, deadlineUptime: 1600)
        XCTAssertFalse(registry.insert(changed, handle: UUID()))
        XCTAssertEqual(questionAction(.returnLocal, registry: &registry, handle: handle), .ignore)
    }

}
