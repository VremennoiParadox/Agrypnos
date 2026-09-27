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
}
