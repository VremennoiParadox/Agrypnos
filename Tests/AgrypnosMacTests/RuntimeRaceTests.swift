import XCTest
import Darwin
import AgrypnosCore
@testable import AgrypnosMac

@MainActor
final class RuntimeRaceTests: XCTestCase {
    func testDisarmDoesNotReassertWhileConfirmingPendingClose() {
        let f = RuntimeFixture()
        _ = f.runtime.engine.userSetEngaged(true, now: Date(), lidClosed: false)
        _ = f.runtime.engine.observeLid(closed: true, now: Date().addingTimeInterval(-1))
        XCTAssertFalse(f.runtime.engine.lidCloseConfirmed)
        XCTAssertNotNil(f.runtime.disarmWatch())
        XCTAssertFalse(f.kernelHeld, "Shared disarm silently reasserted SleepDisabled after successful clear")
        XCTAssertFalse(f.runtime.engaged)
    }
    func testDelayedPostDoesNotUseConfirmationFromBeforeOpenReclose() async {
        let f = RuntimeFixture()
        f.beginClosedLidSettle()
        await f.waitForPost()
        f.lidClosed = false
        f.runtime.pollLid()
        f.lidClosed = true
        XCTAssertFalse(f.runtime.engine.lidCloseConfirmed)
        f.completePost()
        await f.waitForCompletion()
        XCTAssertEqual(f.sleepRequests, 0, "A single raw reclose reused pre-POST confirmation")
    }
    func testDisplaySleepIsVetoedWhenLidOpensDuringReassertion() {
        let f = RuntimeFixture()
        f.runtime.engine.preferences.panelPowerMode = .displaySleep
        _ = f.runtime.engine.userSetEngaged(true, now: Date(), lidClosed: false)
        _ = f.runtime.engine.observeLid(closed: true, now: Date().addingTimeInterval(-1))
        f.kernelWriteHook = { on in if on { f.lidClosed = false } }
        f.runtime.pollLid()
        XCTAssertEqual(f.panelSleepRequests, 0, "Power B sleeps open panel after blocking reassertion")
    }
    func testLidOpenWhileKernelClearRunsDoesNotSleep() async {
        let f = RuntimeFixture()
        f.beginClosedLidSettle()
        await f.waitForPost()
        f.kernelWriteHook = { on in if !on { f.lidClosed = false } }
        f.completePost()
        await f.waitForCompletion()
        XCTAssertEqual(f.sleepRequests, 0)
    }
}

final class ProcessDescendantTests: XCTestCase {
    func testTerminatingLeaderDoesNotLeaveIgnoringDescendantRunning() throws {
        let pidFile = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: pidFile) }
        let result = ProcessRunner.run("/bin/sh", ["-c", "(trap '' TERM; exec /bin/sleep 5) & echo $! > \"$1\"; wait", "test", pidFile.path], timeout: 0.1)
        XCTAssertNotEqual(result.exit, 0)
        let pid = try XCTUnwrap(Int32(try String(contentsOf: pidFile).trimmingCharacters(in: .whitespacesAndNewlines)))
        defer { _ = kill(pid, SIGKILL) }
        XCTAssertNotEqual(kill(pid, 0), 0, "Descendant survived command deadline after leader exited")
    }

}
