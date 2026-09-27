import XCTest
@testable import AgrypnosCore

final class PmsetCommandOutcomeTests: XCTestCase {
    func testZeroExitIsOk() {
        XCTAssertEqual(PmsetCommandOutcome.from(exit: 0), .ok)
        XCTAssertNil(PmsetCommandCopy.notify(.sleepnow, outcome: .ok))
        XCTAssertNil(PmsetCommandCopy.notify(.displaysleepnow, outcome: .ok))
    }

    func testNonzeroSleepnowSurfacesWithoutSudoersTalk() {
        let outcome = PmsetCommandOutcome.from(exit: 1)
        XCTAssertEqual(outcome, .failed(exit: 1))
        let line = PmsetCommandCopy.notify(.sleepnow, outcome: outcome)
        XCTAssertEqual(line, "Couldn't send the Mac to sleep.")
        let lower = line!.lowercased()
        XCTAssertFalse(lower.contains("sudo"))
        XCTAssertFalse(lower.contains("watt"))
    }

    func testNonzeroDisplaySleepSurfacesPanelOnly() {
        let line = PmsetCommandCopy.notify(
            .displaysleepnow,
            outcome: .failed(exit: 127)
        )
        XCTAssertEqual(line, "Couldn't sleep the panel.")
        let lower = line!.lowercased()
        XCTAssertFalse(lower.contains("mac asleep"))
        XCTAssertFalse(lower.contains("sudo"))
        XCTAssertFalse(lower.contains("agents stopped"))
    }
}

final class KernelQuitPolicyTests: XCTestCase {
    func testHonorFailedKernelClearSkipsRestore() {
        XCTAssertFalse(KernelQuitPolicy.shouldRestoreHygiene(kernelCleared: false))
        XCTAssertTrue(KernelQuitPolicy.shouldRestoreHygiene(kernelCleared: true))
    }

    func testFailedClearPostsLeftoverHonesty() {
        XCTAssertEqual(
            KernelQuitPolicy.leftoverNotify(kernelCleared: false),
            "Couldn't drop SleepDisabled. The kernel flag is still on."
        )
        XCTAssertNil(KernelQuitPolicy.leftoverNotify(kernelCleared: true))
    }
}

final class HygieneCaptureTests: XCTestCase {
    func testArmWithLidAlreadyClosedCapturesBeforeHygiene() {
        XCTAssertTrue(LidCloseConfirm.shouldCaptureBeforeClosedHygiene(rawClosed: true))
        XCTAssertFalse(LidCloseConfirm.shouldCaptureBeforeClosedHygiene(rawClosed: false))
    }

    func testOpenLidStillUsesOpenRecaptureGate() {
        XCTAssertTrue(
            LidCloseConfirm.shouldRecaptureOpenBrightness(rawClosed: false, confirmedClosed: false)
        )
        XCTAssertFalse(
            LidCloseConfirm.shouldRecaptureOpenBrightness(rawClosed: true, confirmedClosed: false)
        )
    }
}

final class IsolatedFlagTests: XCTestCase {
    func testFlagRoundTripsUnderLock() {
        let flag = IsolatedFlag(true)
        XCTAssertTrue(flag.value)
        flag.value = false
        XCTAssertFalse(flag.value)
        flag.value = true
        XCTAssertTrue(flag.value)
    }
}
