import XCTest
@testable import AgrypnosCore

final class KernelCrashGuardTests: XCTestCase {
    func testGuardOnlyRunsTheGrantedClearCommandAfterStdinCloses() {
        let script = KernelCrashGuard.script
        let lines = script.split(separator: "\n").map(String.init)
        XCTAssertEqual(lines.last, "exec /usr/bin/sudo -n /usr/bin/pmset -a disablesleep 0")
        XCTAssertTrue(lines.contains("read _"))
        XCTAssertLessThan(lines.firstIndex(of: "read _")!, lines.count - 1)
        XCTAssertFalse(script.contains("disablesleep 1"))
        XCTAssertFalse(script.contains("sleepnow"))
        XCTAssertEqual(script.components(separatedBy: "sudo").count - 1, 1)
    }

    func testGuardSurvivesTerminalAndGroupSignals() {
        XCTAssertEqual(KernelCrashGuard.script.split(separator: "\n").first, "trap '' HUP INT TERM")
    }
}
