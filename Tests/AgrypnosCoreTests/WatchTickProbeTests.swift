import XCTest
@testable import AgrypnosCore

final class WatchTickProbeTests: XCTestCase {
    func testWatchOffSkipsSafetyAndAgentWalks() {
        XCTAssertEqual(
            WatchTickProbe.needed(engaged: false, mode: .idle),
            .none
        )
        XCTAssertFalse(WatchTickProbe.needed(engaged: false, mode: .indefinite).probesSafety)
        XCTAssertFalse(WatchTickProbe.needed(engaged: false, mode: .untilAgentsSettle).probesAgents)
        XCTAssertFalse(WatchTickProbe.needed(engaged: false, mode: .idle).probesKernelHold)
    }

    func testArmedNonAgentsProbesSafetyAndKernelNotSessionTrees() {
        let probe = WatchTickProbe.needed(engaged: true, mode: .indefinite)
        XCTAssertEqual(probe, .safety)
        XCTAssertTrue(probe.probesSafety)
        XCTAssertTrue(probe.probesKernelHold)
        XCTAssertFalse(probe.probesAgents)

        XCTAssertEqual(WatchTickProbe.needed(engaged: true, mode: .timed), .safety)
    }

    func testAgentsModeWalksLocalBusySignals() {
        let probe = WatchTickProbe.needed(engaged: true, mode: .untilAgentsSettle)
        XCTAssertEqual(probe, .safetyAndAgents)
        XCTAssertTrue(probe.probesAgents)
        XCTAssertTrue(probe.probesSafety)
    }

    func testLeftoverKernelReadIsSlowerThanTheFiveSecondTick() {
        XCTAssertEqual(WatchTickProbe.leftoverKernelIdleTicks, 12)
        XCTAssertGreaterThan(
            WatchTickProbe.leftoverKernelInterval,
            5
        )
    }

    func testLeftoverKernelReconcileSkipsWhileHoldingForIdlePost() {
        XCTAssertFalse(
            WatchTickProbe.leftoverReconcileDue(idleTicks: 11, holdingForIdlePost: false)
        )
        XCTAssertTrue(
            WatchTickProbe.leftoverReconcileDue(idleTicks: 12, holdingForIdlePost: false)
        )
        XCTAssertFalse(
            WatchTickProbe.leftoverReconcileDue(idleTicks: 12, holdingForIdlePost: true)
        )
        XCTAssertFalse(
            WatchTickProbe.leftoverReconcileDue(idleTicks: 99, holdingForIdlePost: true)
        )
    }
}
