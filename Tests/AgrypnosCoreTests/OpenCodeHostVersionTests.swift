import XCTest
@testable import AgrypnosCore

final class OpenCodeHostVersionTests: XCTestCase {
    func testMacCheckedVersionAndNewerAreSupported() {
        for version in ["1.18.32", "1.18.34", "1.19.0", "2.0.0", "1.18.40-beta.1"] {
            XCTAssertTrue(OpenCodeHostVersion.isSupported(version), version)
        }
    }

    func testOlderOrMalformedVersionsAreRefused() {
        for version in ["1.18.31", "1.17.99", "0.9.0", "", "1.18", "latest", "1.x.32"] {
            XCTAssertFalse(OpenCodeHostVersion.isSupported(version), version)
        }
    }
}
