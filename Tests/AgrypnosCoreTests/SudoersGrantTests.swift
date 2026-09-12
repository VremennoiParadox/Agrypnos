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

final class GrantLaunchTests: XCTestCase {
    func testSafeUsernameProducesOsascript() {
        let source = GrantLaunch.osascriptSource(username: "ada", scriptPath: "/tmp/grant.sh")
        XCTAssertNotNil(source)
        XCTAssertTrue(source?.contains("AGRYPNOS_USER='ada'") == true)
        XCTAssertTrue(source?.contains("/tmp/grant.sh") == true)
        XCTAssertTrue(source?.contains("with administrator privileges") == true)
    }

    func testUnsafeUsernameDoesNotBuildOsascript() {
        XCTAssertNil(GrantLaunch.osascriptSource(username: "ada; rm -rf /", scriptPath: "/tmp/grant.sh"))
        XCTAssertNil(GrantLaunch.osascriptSource(username: "ada' ; true", scriptPath: "/tmp/grant.sh"))
        XCTAssertNil(GrantLaunch.osascriptSource(username: "ada ALL=(root) NOPASSWD: /bin/sh", scriptPath: "/tmp/grant.sh"))
        XCTAssertNil(GrantLaunch.osascriptSource(username: "", scriptPath: "/tmp/grant.sh"))
    }

    func testQuotedScriptPathRejected() {
        XCTAssertNil(GrantLaunch.osascriptSource(username: "ada", scriptPath: "/tmp/gra'nt.sh"))
        XCTAssertNil(GrantLaunch.osascriptSource(username: "ada", scriptPath: "/tmp/gra\"nt.sh"))
    }
}
