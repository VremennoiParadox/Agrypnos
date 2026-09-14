import XCTest
@testable import AgrypnosCore

final class ProcessTableParserTests: XCTestCase {
    func testParsesPidCpuAndSpacedCommand() {
        let stdout = """
          1234  3.2 Cursor Helper (GPU)
           221 12.50 claude
            18   0.0 WindowServer
        """
        let rows = ProcessTableParser.parse(stdout: stdout)
        XCTAssertEqual(rows.count, 3)
        XCTAssertEqual(rows[0], ProcessRecord(pid: 1234, cpuPercent: 3.2, name: "Cursor Helper (GPU)"))
        XCTAssertEqual(rows[1], ProcessRecord(pid: 221, cpuPercent: 12.5, name: "claude"))
        XCTAssertEqual(rows[2], ProcessRecord(pid: 18, cpuPercent: 0, name: "WindowServer"))
    }

    func testSkipsGarbageLines() {
        let stdout = """
        PID CPU COMMAND
        not-a-row
        """
        XCTAssertTrue(ProcessTableParser.parse(stdout: stdout).isEmpty)
    }

    func testParsesAbsoluteCommandPath() {
        let rows = ProcessTableParser.parse(stdout: "  4421  6.1 /opt/homebrew/bin/claude\n")
        XCTAssertEqual(rows.first?.name, "/opt/homebrew/bin/claude")
        XCTAssertEqual(AgentKindClassifier.classify(processName: rows[0].name), .claudeCode)
    }

    func testParsesArgsLineWithNodeWrapper() {
        let rows = ProcessTableParser.parse(
            stdout: "  4421  6.1 node /usr/local/lib/node_modules/@anthropic-ai/claude-code/cli.js --resume\n"
        )
        XCTAssertEqual(rows.count, 1)
        XCTAssertEqual(rows[0].pid, 4421)
        XCTAssertEqual(rows[0].cpuPercent, 6.1, accuracy: 0.01)
        XCTAssertEqual(AgentKindClassifier.classify(processName: rows[0].name), .claudeCode)
    }
}
