import XCTest
@testable import AgrypnosCore

final class GrantCopyTests: XCTestCase {
    /// After "Not now" or a failed install, the banner must not promise that macOS will ask.
    func testDeclinedOrFailedGrantSaysHowToRetry() {
        XCTAssertFalse(AgrypnosCopy.grantMissing.contains("will ask"))
        XCTAssertTrue(AgrypnosCopy.grantMissing.contains("Keep awake"))
        XCTAssertTrue(AgrypnosCopy.grantMissing.contains("again"))
    }
}
