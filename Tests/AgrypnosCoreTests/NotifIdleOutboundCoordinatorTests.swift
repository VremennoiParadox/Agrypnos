import XCTest
@testable import AgrypnosCore

final class NotifIdleOutboundCoordinatorTests: XCTestCase {
    func testInFlightPostPlusTerminateRequiresCleanupAndKernelClear() {
        var gate = NotifIdleOutboundCoordinator()
        gate.noteUserArm()
        _ = gate.beginPost()
        XCTAssertTrue(gate.postInFlight)

        let plan = gate.terminatePlan(engineEngaged: false, kernelSleepDisabled: true)
        XCTAssertTrue(plan.cleanupRequired)
        XCTAssertTrue(plan.clearKernel)
        XCTAssertTrue(gate.shouldSkipPoll(engineEngaged: false))
        XCTAssertFalse(gate.shouldSkipPoll(engineEngaged: true))
    }

    func testTerminateStillClearsKernelWhenEngineAlreadyDisengaged() {
        var gate = NotifIdleOutboundCoordinator()
        gate.noteUserArm()
        _ = gate.beginPost()
        let plan = gate.terminatePlan(engineEngaged: false, kernelSleepDisabled: true)
        XCTAssertTrue(plan.clearKernel)
        XCTAssertFalse(
            gate.terminatePlan(engineEngaged: false, kernelSleepDisabled: false).clearKernel
        )
    }

    func testIdleQuitWithKernelClearNeedsNoCleanup() {
        let gate = NotifIdleOutboundCoordinator()
        let plan = gate.terminatePlan(engineEngaged: false, kernelSleepDisabled: false)
        XCTAssertFalse(plan.cleanupRequired)
        XCTAssertFalse(plan.clearKernel)
    }

    func testEngagedQuitRequiresCleanupEvenWithoutPost() {
        let gate = NotifIdleOutboundCoordinator()
        let plan = gate.terminatePlan(engineEngaged: true, kernelSleepDisabled: true)
        XCTAssertTrue(plan.cleanupRequired)
        XCTAssertTrue(plan.clearKernel)
    }

    func testMatchingCompletionAppliesDisengage() {
        var gate = NotifIdleOutboundCoordinator()
        gate.noteUserArm()
        let token = gate.beginPost()
        XCTAssertTrue(gate.postInFlight)
        XCTAssertTrue(gate.completePost(token: token))
        XCTAssertFalse(gate.postInFlight)
    }

    func testStaleCompletionAfterRearmIsIgnored() {
        var gate = NotifIdleOutboundCoordinator()
        gate.noteUserArm()
        let stale = gate.beginPost()
        gate.noteUserArm()
        XCTAssertFalse(gate.postInFlight)
        XCTAssertFalse(gate.shouldSkipPoll(engineEngaged: false))
        XCTAssertFalse(gate.completePost(token: stale), "stale POST must not disarm the new arm")

        let fresh = gate.beginPost()
        XCTAssertTrue(gate.completePost(token: fresh))
    }

    func testCancelInFlightThenCompletionIsIgnored() {
        var gate = NotifIdleOutboundCoordinator()
        gate.noteUserArm()
        let token = gate.beginPost()
        XCTAssertTrue(gate.shouldSkipPoll(engineEngaged: false))
        gate.cancelInFlight()
        XCTAssertFalse(gate.postInFlight)
        XCTAssertFalse(gate.completePost(token: token))
        let afterCancel = gate.terminatePlan(engineEngaged: false, kernelSleepDisabled: true)
        XCTAssertTrue(afterCancel.cleanupRequired)
        XCTAssertTrue(afterCancel.clearKernel)
    }
}
