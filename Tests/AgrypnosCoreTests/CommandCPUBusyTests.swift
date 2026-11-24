import XCTest
@testable import AgrypnosCore

/// Commands an agent runs (a shell child and everything under it) count toward its CPU.
/// A long build or test run leaves the agent itself quiet while the command works.
final class CommandCPUBusyTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_000_000)

    private func busy(_ kind: AgentKind, _ processes: [ProcessRecord]) -> Bool {
        AgentHeuristicEngine().evaluate(processes: processes, sessionWrites: [], now: now)
            .anyBusy(included: [kind])
    }

    func testTestRunUnderAQuietClaudeCodeCountsAsBusy() {
        XCTAssertTrue(busy(.claudeCode, [
            ProcessRecord(pid: 100, cpuPercent: 0.7, name: "/Users/u/.local/bin/claude", parentPID: 1),
            ProcessRecord(pid: 200, cpuPercent: 0, name: "/bin/zsh -c npm test", parentPID: 100),
            ProcessRecord(pid: 300, cpuPercent: 99, name: "node jest", parentPID: 200),
        ]))
    }

    func testDesktopBundledClaudeCodeCommandsCount() {
        let agent = "/Users/u/Library/Application Support/Claude/claude-code/2.1.321/abc/claude.app/Contents/MacOS/claude"
        XCTAssertTrue(busy(.claudeCode, [
            ProcessRecord(pid: 100, cpuPercent: 0.1, name: agent, parentPID: 1),
            ProcessRecord(pid: 200, cpuPercent: 100, name: "/bin/zsh -c swift test", parentPID: 100),
        ]))
    }

    func testServersStartedWithoutAShellDoNotCount() {
        XCTAssertFalse(busy(.claudeCode, [
            ProcessRecord(pid: 100, cpuPercent: 0.7, name: "claude", parentPID: 1),
            ProcessRecord(pid: 200, cpuPercent: 50, name: "node /Users/u/mcp/server.js", parentPID: 100),
            ProcessRecord(pid: 300, cpuPercent: 40, name: "typescript-language-server --stdio", parentPID: 100),
        ]))
    }

    func testQuietCommandDoesNotCount() {
        XCTAssertFalse(busy(.claudeCode, [
            ProcessRecord(pid: 100, cpuPercent: 0.7, name: "claude", parentPID: 1),
            ProcessRecord(pid: 200, cpuPercent: 0, name: "/bin/zsh -c sleep 300", parentPID: 100),
            ProcessRecord(pid: 300, cpuPercent: 0, name: "sleep 300", parentPID: 200),
        ]))
    }

    func testCodexAndOpenCodeCommandsCount() {
        XCTAssertTrue(busy(.codex, [
            ProcessRecord(pid: 100, cpuPercent: 0.2, name: "codex", parentPID: 1),
            ProcessRecord(pid: 200, cpuPercent: 0, name: "-bash -lc cargo test", parentPID: 100),
            ProcessRecord(pid: 300, cpuPercent: 80, name: "cargo test", parentPID: 200),
        ]))
        XCTAssertTrue(busy(.openCode, [
            ProcessRecord(pid: 100, cpuPercent: 0.2, name: "opencode", parentPID: 1),
            ProcessRecord(pid: 200, cpuPercent: 60, name: "/bin/zsh -c swift build", parentPID: 100),
        ]))
    }

    func testOpenCodeOwnCPUStillDoesNotCount() {
        XCTAssertFalse(busy(.openCode, [ProcessRecord(pid: 100, cpuPercent: 90, name: "opencode", parentPID: 1)]))
    }

    func testCursorAndDesktopAppTreesDoNotCount() {
        XCTAssertFalse(busy(.cursor, [
            ProcessRecord(pid: 100, cpuPercent: 1, name: "/Applications/Cursor.app/Contents/MacOS/Cursor", parentPID: 1),
            ProcessRecord(pid: 200, cpuPercent: 90, name: "/bin/zsh -il", parentPID: 100),
        ]))
        XCTAssertFalse(busy(.claudeCode, [
            ProcessRecord(pid: 100, cpuPercent: 1, name: "/Applications/Claude.app/Contents/MacOS/Claude", parentPID: 1),
            ProcessRecord(pid: 200, cpuPercent: 90, name: "/bin/zsh -c make", parentPID: 100),
        ]))
    }
}
