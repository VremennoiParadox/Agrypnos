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

    func testDisplayRestoreRaisesSavedBelowFloor() {
        XCTAssertEqual(HygieneRestore.displayBrightnessToRestore(captured: 0.05, floor: 0.15), 0.15)
    }

    func testDisplayRestoreUsesFloorWhenCaptureFailed() {
        XCTAssertEqual(HygieneRestore.displayBrightnessToRestore(captured: nil, floor: 0.15), 0.15)
    }
}
