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
}
