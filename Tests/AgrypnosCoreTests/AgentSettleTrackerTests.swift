import XCTest
@testable import AgrypnosCore

final class AgentSettleTrackerTests: XCTestCase {
    let t0 = Date(timeIntervalSince1970: 1_000)

    func testDefaultGraceIsTwoMinutes() {
        XCTAssertEqual(AgentSettleTracker().grace, 120)
        XCTAssertEqual(AgentSettleTracker().grace, UserPreferences.defaultAgentSettleGrace)
    }

    func testQuietUntilFirstBusy() {
        var tracker = AgentSettleTracker(grace: 90)
        XCTAssertEqual(tracker.observe(busy: false, now: t0), .quiet)
    }

    func testBusyThenGraceThenSettled() {
        var tracker = AgentSettleTracker(grace: 90)
        XCTAssertEqual(tracker.observe(busy: true, now: t0), .busy)
        XCTAssertEqual(tracker.observe(busy: false, now: t0.addingTimeInterval(89)), .settling)
        XCTAssertEqual(tracker.observe(busy: false, now: t0.addingTimeInterval(90)), .settled)
    }

    func testResetForgetsBusyHistory() {
        var tracker = AgentSettleTracker(grace: 90)
        _ = tracker.observe(busy: true, now: t0)
        tracker.reset()
        XCTAssertEqual(tracker.observe(busy: false, now: t0.addingTimeInterval(1_000)), .quiet)
    }

    func testActivityPeekDoesNotRecordBusy() {
        var tracker = AgentSettleTracker(grace: 90)
        XCTAssertEqual(tracker.activity(busy: true, now: t0), .busy)
        XCTAssertFalse(tracker.sawBusy)
        XCTAssertEqual(tracker.observe(busy: true, now: t0), .busy)
        XCTAssertTrue(tracker.sawBusy)
        XCTAssertEqual(tracker.activity(busy: false, now: t0.addingTimeInterval(89)), .settling)
        XCTAssertEqual(tracker.observe(busy: false, now: t0.addingTimeInterval(89)), .settling)
    }
}
