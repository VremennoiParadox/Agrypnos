import XCTest
@testable import AgrypnosCore

final class QuestionWaitPolicyTests: XCTestCase {
    func testTenMinuteDeadline() {
        let key = questionKey()
        var policy = QuestionWaitPolicy()
        XCTAssertEqual(policy.observe(pendingDeadlines: [key: 1600], newlyExpired: [],
            cleared: [], now: 1599, busy: false, grace: 120).action, .hold)
        let end = policy.observe(pendingDeadlines: [:], newlyExpired: [key],
            cleared: [], now: 1600, busy: false, grace: 120)
        XCTAssertEqual(end.action, .endUnanswered)
        XCTAssertEqual(end.timeouts.map(\.key), [key])
        XCTAssertTrue(policy.observe(pendingDeadlines: [:], newlyExpired: [key],
            cleared: [], now: 1601, busy: false, grace: 120).timeouts.isEmpty)
    }

    func testBusyAndUnknownDeferEnd() {
        for busy: Bool? in [true, nil] {
            var policy = QuestionWaitPolicy()
            let deferred = policy.observe(pendingDeadlines: [:], newlyExpired: [questionKey()],
                cleared: [], now: 1600, busy: busy, grace: 120)
            XCTAssertEqual(deferred.action, .deferTimeout)
            XCTAssertEqual(deferred.timeouts.first?.reason, busy == true ? .busy : .unknown)
            for now in stride(from: 1605.0, through: 1720.0, by: 5) {
                XCTAssertEqual(policy.observe(pendingDeadlines: [:], newlyExpired: [],
                    cleared: [], now: now, busy: false, grace: 120).action, .deferTimeout)
            }
            XCTAssertEqual(policy.observe(pendingDeadlines: [:], newlyExpired: [],
                cleared: [], now: 1725, busy: false, grace: 120).action, .endUnanswered)
        }
    }

    func testMissingObservationsRestartQuietWait() {
        var policy = QuestionWaitPolicy()
        _ = policy.observe(pendingDeadlines: [:], newlyExpired: [questionKey()],
            cleared: [], now: 1600, busy: true, grace: 120)
        _ = policy.observe(pendingDeadlines: [:], newlyExpired: [],
            cleared: [], now: 1605, busy: false, grace: 120)
        for now in stride(from: 1700.0, through: 1815.0, by: 5) {
            XCTAssertEqual(policy.observe(pendingDeadlines: [:], newlyExpired: [],
                cleared: [], now: now, busy: false, grace: 120).action, .deferTimeout)
        }
        XCTAssertEqual(policy.observe(pendingDeadlines: [:], newlyExpired: [],
            cleared: [], now: 1820, busy: false, grace: 120).action, .endUnanswered)
    }

    func testUnknownResetsExistingQuietWait() {
        var policy = QuestionWaitPolicy()
        _ = policy.observe(pendingDeadlines: [:], newlyExpired: [questionKey()],
            cleared: [], now: 1600, busy: nil, grace: 120)
        _ = policy.observe(pendingDeadlines: [:], newlyExpired: [],
            cleared: [], now: 1605, busy: false, grace: 120)
        _ = policy.observe(pendingDeadlines: [:], newlyExpired: [],
            cleared: [], now: 1610, busy: nil, grace: 120)
        for now in stride(from: 1615.0, through: 1730.0, by: 5) {
            XCTAssertEqual(policy.observe(pendingDeadlines: [:], newlyExpired: [],
                cleared: [], now: now, busy: false, grace: 120).action, .deferTimeout)
        }
        XCTAssertEqual(policy.observe(pendingDeadlines: [:], newlyExpired: [],
            cleared: [], now: 1735, busy: false, grace: 120).action, .endUnanswered)
    }

    func testOtherQuestionKeepsOwnDeadline() {
        var policy = QuestionWaitPolicy()
        let first = questionKey(), second = questionKey("other")
        let result = policy.observe(pendingDeadlines: [second: 1700], newlyExpired: [first],
            cleared: [], now: 1600, busy: false, grace: 120)
        XCTAssertEqual(result.action, .hold)
        XCTAssertEqual(result.timeouts.first?.reason, .anotherQuestion)
        XCTAssertEqual(policy.observe(pendingDeadlines: [second: 1700], newlyExpired: [],
            cleared: [], now: 1699, busy: false, grace: 120).action, .hold)
        XCTAssertEqual(policy.observe(pendingDeadlines: [second: 1700], newlyExpired: [],
            cleared: [], now: 1700, busy: false, grace: 120).action, .endUnanswered)
    }

    func testFreshBusyProtectsEvenSameProvider() {
        var policy = QuestionWaitPolicy()
        XCTAssertEqual(policy.observe(pendingDeadlines: [:], newlyExpired: [questionKey()],
            cleared: [], now: 1600, busy: true, grace: 120).action, .deferTimeout)
    }

    func testLocalAnswerClearsOnlyMatchingDeferredTimeout() {
        var policy = QuestionWaitPolicy()
        let first = questionKey(), second = questionKey("other")
        _ = policy.observe(pendingDeadlines: [:], newlyExpired: [first, second],
            cleared: [], now: 1600, busy: true, grace: 120)
        XCTAssertEqual(policy.observe(pendingDeadlines: [:], newlyExpired: [],
            cleared: [first], now: 1601, busy: nil, grace: 120).action, .deferTimeout)
        XCTAssertEqual(policy.observe(pendingDeadlines: [:], newlyExpired: [],
            cleared: [second], now: 1602, busy: nil, grace: 120).action, .normal)
    }

    func testDeferredEndUsesTheSameSettleRangeAsTheSlider() {
        var low = QuestionWaitPolicy()
        _ = low.observe(pendingDeadlines: [:], newlyExpired: [questionKey()],
            cleared: [], now: 1600, busy: true, grace: 90)
        for now in stride(from: 1605.0, through: 1690.0, by: 5) {
            XCTAssertEqual(low.observe(pendingDeadlines: [:], newlyExpired: [],
                cleared: [], now: now, busy: false, grace: 90).action, .deferTimeout)
        }
        XCTAssertEqual(low.observe(pendingDeadlines: [:], newlyExpired: [],
            cleared: [], now: 1695, busy: false, grace: 90).action, .endUnanswered)

        var high = QuestionWaitPolicy()
        _ = high.observe(pendingDeadlines: [:], newlyExpired: [questionKey()],
            cleared: [], now: 1600, busy: true, grace: 900)
        for now in stride(from: 1605.0, through: 2190.0, by: 15) {
            XCTAssertEqual(high.observe(pendingDeadlines: [:], newlyExpired: [],
                cleared: [], now: now, busy: false, grace: 900).action, .deferTimeout)
        }
        XCTAssertEqual(high.observe(pendingDeadlines: [:], newlyExpired: [],
            cleared: [], now: 2205, busy: false, grace: 900).action, .endUnanswered)
    }

    func testResetDropsPreviousArmTimeout() {
        var policy = QuestionWaitPolicy()
        _ = policy.observe(pendingDeadlines: [:], newlyExpired: [questionKey()],
            cleared: [], now: 1600, busy: nil, grace: 120)
        policy.reset()
        XCTAssertEqual(policy.observe(pendingDeadlines: [:], newlyExpired: [],
            cleared: [], now: 2000, busy: false, grace: 120), .normal)
    }
}
