import XCTest
@testable import AgrypnosCore

final class AgentProbeObservationTests: XCTestCase {
    private let t0 = Date(timeIntervalSince1970: 10_000)

    private func observation(complete: Bool = true, busy: AgentKind? = nil,
                             duration: TimeInterval = 1) -> AgentProbeObservation {
        let reports = busy.map { [AgentReport(kind: $0, processRunning: true, cpuBusy: false,
                                             recentSessionWrite: true, isBusy: true)] } ?? []
        return AgentProbeObservation(snapshot: AgentSnapshot(reports: reports), startedAt: t0,
                                     completedAt: t0.addingTimeInterval(duration), complete: complete)
    }

    func testCompleteIdleIsFalse() {
        XCTAssertEqual(observation().settleBusy(included: [.cursor], now: t0.addingTimeInterval(1)), false)
    }

    func testIncompleteIdleIsUnknown() {
        XCTAssertNil(observation(complete: false).settleBusy(included: [.cursor], now: t0.addingTimeInterval(1)))
    }

    func testPartialSelectedBusyStillProtectsWatch() {
        XCTAssertEqual(observation(complete: false, busy: .cursor)
            .settleBusy(included: [.cursor], now: t0.addingTimeInterval(1)), true)
    }

    func testUnselectedBusyDoesNotHideIncompleteSelectedProbe() {
        XCTAssertNil(observation(complete: false, busy: .codex)
            .settleBusy(included: [.cursor], now: t0.addingTimeInterval(1)))
    }

    func testDelayedProbeIsUnknownEvenWithBusyEvidence() {
        for busy in [nil, AgentKind.cursor] {
            XCTAssertNil(observation(busy: busy, duration: 20)
                .settleBusy(included: [.cursor], now: t0.addingTimeInterval(20)))
        }
    }

    func testInvalidTimeOrderingAndOldDeliveryAreUnknown() {
        XCTAssertNil(observation(duration: -1).settleBusy(included: [.cursor], now: t0))
        XCTAssertNil(observation().settleBusy(included: [.cursor], now: t0))
        XCTAssertNil(observation().settleBusy(included: [.cursor], now: t0.addingTimeInterval(6)))
        XCTAssertEqual(observation(duration: 15)
            .settleBusy(included: [.cursor], now: t0.addingTimeInterval(19.9)), false)
    }

    func testCacheRejectsClockReversal() {
        var cache = AgentSnapshotCache()
        cache.store(AgentSnapshot(reports: []), included: [.cursor], at: t0)
        XCTAssertNil(cache.reusable(at: t0.addingTimeInterval(-1), included: [.cursor]))
    }
}
