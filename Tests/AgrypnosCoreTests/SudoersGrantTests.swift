import XCTest
@testable import AgrypnosCore

final class SudoersGrantTests: XCTestCase {
    func testAcceptsNormalMacShortNames() {
        XCTAssertEqual(
            SudoersGrant.line(username: "ada"),
            "ada ALL=(root) NOPASSWD: /usr/bin/pmset -a disablesleep 0, /usr/bin/pmset -a disablesleep 1"
        )
        XCTAssertNotNil(SudoersGrant.line(username: "Ada.Lovelace_1"))
    }

    func testRejectsInjection() {
        XCTAssertNil(SudoersGrant.line(username: "ada,root"))
        XCTAssertNil(SudoersGrant.line(username: "ada ALL=(root) NOPASSWD: /bin/sh"))
        XCTAssertNil(SudoersGrant.line(username: "ada\nroot"))
        XCTAssertNil(SudoersGrant.line(username: ""))
    }
}
