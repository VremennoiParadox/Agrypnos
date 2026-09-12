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
}
