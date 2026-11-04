import XCTest
import AgrypnosCore
@testable import AgrypnosMac

@MainActor
final class KernelFailureTests: XCTestCase {
    func testAlreadyOffInboundDisarmReportsFailedClearWithoutSleeping() {
        let f = RuntimeFixture()
        f.kernelWriteSucceeds = false
        _ = f.runtime.engine.observeLid(closed: true, now: Date().addingTimeInterval(-1))
        _ = f.runtime.engine.observeLid(closed: true, now: Date())
        XCTAssertEqual(f.runtime.applyDiscordDisarm(), TelegramInboundCopy.disarmFailed)
        XCTAssertEqual(f.sleepRequests, 0)
        XCTAssertTrue(f.kernelHeld)
    }

    func testUnknownReadCannotReportDisarmSuccess() {
        let f = RuntimeFixture()
        f.kernelUnknown = true
        XCTAssertEqual(f.runtime.applyDiscordDisarm(), TelegramInboundCopy.disarmFailed)
        XCTAssertEqual(f.sleepRequests, 0)
    }

    func testFailedReassertionStopsPanelSleepAndEndsUnprotectedWatch() {
        let f = RuntimeFixture()
        f.runtime.engine.preferences.panelPowerMode = .displaySleep
        _ = f.runtime.engine.userSetEngaged(true, now: Date(), lidClosed: true)
        f.kernelHeld = false
        f.kernelWriteSucceeds = false
        f.runtime.apply([.assertSleepDisabled, .requestDisplaySleep])
        XCTAssertEqual(f.panelSleepRequests, 0)
        XCTAssertFalse(f.runtime.engaged)
        XCTAssertEqual(f.runtime.preferences.lastWatchEnd?.reason, .wakeHoldFailed)
        XCTAssertFalse(f.messages.isEmpty)
    }

    func testUnknownArmReadbackUndoesSetAndStaysArmedWhenClearUnconfirmed() {
        let f = RuntimeFixture()
        _ = f.runtime.engine.userSetEngaged(true, now: Date(), lidClosed: false)
        f.kernelHeld = true
        f.kernelUnknown = true
        var writes: [Bool] = []
        f.kernelWriteHook = { writes.append($0) }
        f.runtime.apply([.assertSleepDisabled])
        XCTAssertEqual(writes.first, true)
        XCTAssertTrue(writes.contains(false))
        XCTAssertTrue(f.runtime.engine.engaged)
        XCTAssertNil(f.runtime.preferences.lastWatchEnd)
    }

    func testUnknownLeftoverReconcileClearsWithoutAdopting() {
        let f = RuntimeFixture()
        XCTAssertFalse(f.runtime.engine.engaged)
        f.kernelHeld = true
        f.kernelUnknown = true
        f.runtime.reconcileKernel(preferClearLeftover: true)
        XCTAssertFalse(f.runtime.engine.engaged)
        XCTAssertFalse(f.runtime.engine.leftoverAdopted)
        XCTAssertFalse(f.kernelHeld)
    }
}
