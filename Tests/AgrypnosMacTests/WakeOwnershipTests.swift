import XCTest
@testable import AgrypnosMac

final class WakeOwnershipTests: XCTestCase {
    func testCleanupHelperRetainsExclusiveOwnershipAfterAppClosesItsHandle() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent("owner.lock")
        let owner = try XCTUnwrap(SleepDisabledCrashGuard.acquireOwnership(at: url))
        XCTAssertNil(SleepDisabledCrashGuard.acquireOwnership(at: url))
        let pipe = Pipe()
        let child = Process()
        child.executableURL = URL(fileURLWithPath: "/bin/sh")
        child.arguments = ["-c", "read _"]
        child.standardInput = pipe
        child.standardOutput = owner
        child.standardError = FileHandle.nullDevice
        try child.run()
        try owner.close()
        XCTAssertNil(SleepDisabledCrashGuard.acquireOwnership(at: url))
        try pipe.fileHandleForWriting.write(contentsOf: Data("done\n".utf8))
        child.waitUntilExit()
        let nextOwner = try XCTUnwrap(SleepDisabledCrashGuard.acquireOwnership(at: url))
        try nextOwner.close()
    }
}
