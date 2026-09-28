import XCTest
@testable import AgrypnosMac

final class ProcessRunnerTests: XCTestCase {
    func testCommandDeadlineReturnsFailureWithoutWaitingForFullSleep() {
        let start = Date()
        let result = ProcessRunner.run("/bin/sleep", ["1.5"], timeout: 0.05)
        XCTAssertNotEqual(result.exit, 0)
        XCTAssertLessThan(Date().timeIntervalSince(start), 0.8)
        XCTAssertTrue(result.err.contains("timed out"))
    }

    func testBothOutputStreamsDrainWithoutPipeDeadlock() {
        let result = ProcessRunner.run("/usr/bin/awk", [
            "BEGIN { for (i=0; i<10000; i++) { print \"out\"; print \"err\" > \"/dev/stderr\" } }",
        ], timeout: 3)
        XCTAssertEqual(result.exit, 0, result.err)
        XCTAssertEqual(result.out.split(separator: "\n").count, 10000)
        XCTAssertEqual(result.err.split(separator: "\n").count, 10000)
    }

    func testChildIgnoringTerminateIsKilledAtDeadline() {
        let result = ProcessRunner.run("/bin/sh", ["-c", "trap '' TERM; exec /bin/sleep 1.5"], timeout: 0.05)
        XCTAssertNotEqual(result.exit, 0)
        XCTAssertTrue(result.err.contains("timed out"))
    }
}
