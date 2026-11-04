import XCTest
@testable import AgrypnosCore

final class HygieneRestoreTests: XCTestCase {
    func testKeyboardRestoreSkipsWhenCaptureFailed() {
        XCTAssertNil(HygieneRestore.keyboardBrightnessToRestore(captured: nil))
    }

    func testKeyboardRestoreKeepsCapturedZero() {
        XCTAssertEqual(HygieneRestore.keyboardBrightnessToRestore(captured: 0), 0)
    }

    func testKeyboardRestoreKeepsCapturedLevel() {
        XCTAssertEqual(HygieneRestore.keyboardBrightnessToRestore(captured: 0.42), 0.42)
    }

    func testLidOpenRampIsTwoSeconds() {
        XCTAssertEqual(HygieneRestore.lidOpenRampDuration, 2)
    }

    func testDisplayRestoreUsesSavedWhenAboveFloor() {
        XCTAssertEqual(HygieneRestore.displayBrightnessToRestore(captured: 0.6, floor: 0.15), 0.6)
    }

    func testDisplayRestoreKeepsCapturedBelowFloor() {
        XCTAssertEqual(HygieneRestore.displayBrightnessToRestore(captured: 0.05, floor: 0.15), 0.05)
    }

    func testDisplayRestoreDoesNotLiftCaptureToFloor() {
        XCTAssertNotEqual(
            HygieneRestore.displayBrightnessToRestore(captured: 0.08, floor: 0.15),
            0.15
        )
    }

    func testSkipRestoreWhenLidConfirmedClosedAndNextIsSleep() {
        XCTAssertFalse(
            HygieneRestore.shouldRestoreAfterDisengage(
                lidCloseConfirmed: true,
                nextCommandIsSleep: true
            )
        )
    }

    func testRestoreWhenLidOpenEvenIfSleepFollows() {
        XCTAssertTrue(
            HygieneRestore.shouldRestoreAfterDisengage(
                lidCloseConfirmed: false,
                nextCommandIsSleep: true
            )
        )
    }

    func testRestoreWhenLidClosedAndNoSleep() {
        XCTAssertTrue(
            HygieneRestore.shouldRestoreAfterDisengage(
                lidCloseConfirmed: true,
                nextCommandIsSleep: false
            )
        )
    }

    func testDisplayRestoreSkipsWhenCaptureFailed() {
        XCTAssertNil(HygieneRestore.displayBrightnessToRestore(captured: nil, floor: 0.15))
    }

    /// macOS often raises the panel itself when the lid opens. Only ramp back from the floor.
    func testRampBackOnlyWhenThePanelIsStillAtTheFloor() {
        XCTAssertTrue(HygieneRestore.shouldRampBack(current: 0.01, captured: 0.4375, floor: 0.01))
        XCTAssertTrue(HygieneRestore.shouldRampBack(current: 0.02, captured: 0.4375, floor: 0.01))
        // macOS raised it above what was captured.
        XCTAssertFalse(HygieneRestore.shouldRampBack(current: 0.5625, captured: 0.4375, floor: 0.01))
        XCTAssertFalse(HygieneRestore.shouldRampBack(current: 0.5625, captured: 0.5625, floor: 0.15))
        XCTAssertTrue(HygieneRestore.shouldRampBack(current: nil, captured: 0.5, floor: 0.15))
    }

    /// Asking for a 1% floor reads back the panel's lowest step (0.0625), not 0.01. That is still the floor.
    func testThePanelsLowestStepCountsAsTheFloor() {
        XCTAssertTrue(HygieneRestore.shouldRampBack(current: 0.0625, captured: 0.4375, floor: 0.01))
        XCTAssertTrue(HygieneRestore.shouldRampBack(current: 0.0625, captured: 0.625, floor: 0.01))
    }

    /// A floor above the captured level raised the panel, so restoring means going back down.
    func testRampBackFromAFloorAboveTheCapturedLevel() {
        XCTAssertTrue(HygieneRestore.shouldRampBack(current: 0.15, captured: 0.10, floor: 0.15))
    }

    /// Dimmer than what was captured is not "restored by macOS".
    func testRampBackWhenTheLevelIsClearlyBelowTheCapture() {
        XCTAssertTrue(HygieneRestore.shouldRampBack(current: 0.20, captured: 0.5, floor: 0.15))
    }
}
