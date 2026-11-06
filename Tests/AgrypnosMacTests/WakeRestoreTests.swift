import XCTest
import AgrypnosCore
@testable import AgrypnosMac

/// A disengage that sleeps the Mac with the lid closed does not light the panel first.
/// The captured brightness is put back once the Mac wakes with the lid open.
@MainActor
final class WakeRestoreTests: XCTestCase {
    private func fixtureAfterClosedLidSleep(current: Double) -> (RuntimeFixture, Box) {
        let f = RuntimeFixture()
        f.runtime.engine.preferences.panelPowerMode = .floor   // Dim panel: the floor path
        let box = Box(current: current)
        f.runtime.hygieneDevices = HygieneDevices(canSetBrightness: { true }, brightness: { box.current },
            setBrightness: { box.writes.append($0) }, keyboard: { nil }, setKeyboard: { _ in }, wakeDisplay: {})
        f.runtime.engine.preferences.applyBrightnessFloor = true
        f.runtime.savedBrightness = 0.625
        _ = f.runtime.engine.userSetEngaged(true, now: Date(), lidClosed: true)
        f.runtime.apply([.applyBrightnessFloor])
        box.writes.removeAll()
        f.runtime.finishDisengageHygiene(sleepResult: HygieneApplyResult(sleepnow: .ok))
        return (f, box)
    }

    final class Box { var current: Double; var writes: [Double] = []; init(current: Double) { self.current = current } }

    func testSleepnowKeepsTheCaptureAndWritesNothingBeforeSleeping() {
        let (f, box) = fixtureAfterClosedLidSleep(current: 0.15)
        XCTAssertTrue(box.writes.isEmpty)
        XCTAssertTrue(f.runtime.wakeRestorePending)
        XCTAssertEqual(f.runtime.savedBrightness, 0.625)
        XCTAssertTrue(f.runtime.hygieneEffects.floor)
    }

    func testWakeWithTheLidOpenRampsBackFromTheFloor() {
        let (f, _) = fixtureAfterClosedLidSleep(current: 0.15)
        f.lidClosed = false
        f.runtime.restoreHygieneAfterWake()
        XCTAssertTrue(f.runtime.brightnessRamp.isRunning)
        XCTAssertFalse(f.runtime.wakeRestorePending)
        XCTAssertFalse(f.runtime.hygieneEffects.floor)
        XCTAssertNil(f.runtime.savedBrightness)
        f.runtime.brightnessRamp.cancel()
    }

    func testWakeWithTheLidStillClosedWaitsForTheLidToOpen() {
        let (f, box) = fixtureAfterClosedLidSleep(current: 0.15)
        f.lidClosed = true
        f.runtime.restoreHygieneAfterWake()
        XCTAssertTrue(f.runtime.wakeRestorePending)
        XCTAssertFalse(f.runtime.brightnessRamp.isRunning)
        XCTAssertTrue(box.writes.isEmpty)
    }

    func testWakeRampsBackFromThePanelsLowestStepEvenWithA1PercentFloor() {
        let (f, _) = fixtureAfterClosedLidSleep(current: 0.0625)
        f.lidClosed = false
        f.runtime.restoreHygieneAfterWake()
        XCTAssertTrue(f.runtime.brightnessRamp.isRunning)
        f.runtime.brightnessRamp.cancel()
    }

    func testWakeLeavesBrightnessAloneWhenMacOSAlreadyRaisedIt() {
        let (f, box) = fixtureAfterClosedLidSleep(current: 0.75)
        f.lidClosed = false
        f.runtime.restoreHygieneAfterWake()
        XCTAssertFalse(f.runtime.brightnessRamp.isRunning)
        XCTAssertTrue(box.writes.isEmpty)
        XCTAssertFalse(f.runtime.wakeRestorePending)
        XCTAssertFalse(f.runtime.hygieneEffects.floor)
    }

    /// Armed with the lid confirmed closed, the lid is sampled at 4 Hz so an open is noticed at once.
    func testLidPulseKeepsRunningWhileArmedWithTheLidConfirmedClosed() {
        let f = RuntimeFixture()
        f.beginQuestionWatch()
        XCTAssertTrue(f.runtime.engine.lidCloseConfirmed)
        XCTAssertEqual(f.runtime.lidCadence(), .confirmPulse)
        f.runtime.syncLidPulse()
        XCTAssertTrue(f.runtime.lidTimer != nil)
        f.lidClosed = false
        f.runtime.pollLid()
        XCTAssertEqual(f.runtime.lidCadence(), .coarse)
        XCTAssertNil(f.runtime.lidTimer)
    }

    func testNothingRestoresWhenNoSleepnowWasPending() {
        let f = RuntimeFixture()
        f.lidClosed = false
        f.runtime.restoreHygieneAfterWake()
        XCTAssertFalse(f.runtime.brightnessRamp.isRunning)
    }
}
