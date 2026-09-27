import XCTest
@testable import AgrypnosCore

final class AgentSnapshotCacheTests: XCTestCase {
    let t0 = Date(timeIntervalSince1970: 10_000)

    func testReusesSnapshotYoungerThanOnePoll() {
        var cache = AgentSnapshotCache()
        let snap = AgentSnapshot(reports: [
            AgentReport(
                kind: .cursor,
                processRunning: true,
                cpuBusy: false,
                recentSessionWrite: true,
                isBusy: true
            )
        ])
        cache.store(snap, included: [.cursor], at: t0)
        XCTAssertEqual(
            cache.reusable(at: t0.addingTimeInterval(4.9), included: [.cursor]),
            snap
        )
    }

    func testDoesNotReuseAfterPollWindow() {
        var cache = AgentSnapshotCache()
        cache.store(AgentSnapshot(reports: []), included: [.cursor], at: t0)
        XCTAssertNil(cache.reusable(at: t0.addingTimeInterval(5), included: [.cursor]))
    }

    func testDoesNotReuseWhenIncludeSetChanged() {
        var cache = AgentSnapshotCache()
        cache.store(AgentSnapshot(reports: []), included: [.cursor], at: t0)
        XCTAssertNil(
            cache.reusable(at: t0.addingTimeInterval(1), included: [.cursor, .claudeCode])
        )
    }

    func testDoesNotReuseWhenTerminalsPreferenceChanged() {
        var cache = AgentSnapshotCache()
        cache.store(
            AgentSnapshot(reports: []),
            included: [.cursor],
            countTerminalSessionsAsBusy: false,
            at: t0
        )
        XCTAssertNil(
            cache.reusable(
                at: t0.addingTimeInterval(1),
                included: [.cursor],
                countTerminalSessionsAsBusy: true
            )
        )
        XCTAssertNotNil(
            cache.reusable(
                at: t0.addingTimeInterval(1),
                included: [.cursor],
                countTerminalSessionsAsBusy: false
            )
        )
    }

    func testInvalidateDropsSnapshot() {
        var cache = AgentSnapshotCache()
        cache.store(AgentSnapshot(reports: []), included: Set(AgentKind.allCases), at: t0)
        cache.invalidate()
        XCTAssertNil(
            cache.reusable(at: t0.addingTimeInterval(1), included: Set(AgentKind.allCases))
        )
    }

    func testInvalidateDropsBusySnapshotInsideReuseWindow() {
        var cache = AgentSnapshotCache()
        let busy = AgentSnapshot(reports: [
            AgentReport(
                kind: .cursor,
                processRunning: true,
                cpuBusy: false,
                recentSessionWrite: true,
                isBusy: true
            )
        ])
        cache.store(busy, included: Set(AgentKind.allCases), at: t0)
        XCTAssertEqual(
            cache.reusable(
                at: t0.addingTimeInterval(1),
                included: Set(AgentKind.allCases)
            )?.anyBusy,
            true
        )
        cache.invalidate()
        XCTAssertNil(
            cache.reusable(
                at: t0.addingTimeInterval(1),
                included: Set(AgentKind.allCases)
            )
        )
        XCTAssertEqual(AgentSnapshotCache.reuseWindow, 5)
    }

    func testReuseWindowMatchesFiveSecondPoll() {
        XCTAssertEqual(AgentSnapshotCache.reuseWindow, 5)
    }
}
