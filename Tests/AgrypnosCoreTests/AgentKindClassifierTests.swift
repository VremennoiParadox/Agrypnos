import XCTest
@testable import AgrypnosCore

final class AgentKindClassifierTests: XCTestCase {
    func testCursorMainAndHelpersClassifyAsCursor() {
        XCTAssertEqual(AgentKindClassifier.classify(processName: "Cursor"), .cursor)
        XCTAssertEqual(AgentKindClassifier.classify(processName: "Cursor Helper"), .cursor)
        XCTAssertEqual(AgentKindClassifier.classify(processName: "Cursor Helper (GPU)"), .cursor)
        XCTAssertEqual(AgentKindClassifier.classify(processName: "Cursor Helper (Plugin)"), .cursor)
    }

    func testClaudeAndCodexNames() {
        XCTAssertEqual(AgentKindClassifier.classify(processName: "claude"), .claudeCode)
        XCTAssertEqual(AgentKindClassifier.classify(processName: "Claude"), .claudeCode)
        XCTAssertEqual(AgentKindClassifier.classify(processName: "codex"), .codex)
        XCTAssertEqual(AgentKindClassifier.classify(processName: "codex-exec"), .codex)
    }

    func testUnrelatedProcessesAreIgnored() {
        XCTAssertNil(AgentKindClassifier.classify(processName: "Safari"))
        XCTAssertNil(AgentKindClassifier.classify(processName: "node"))
        XCTAssertNil(AgentKindClassifier.classify(processName: "WindowServer"))
    }

    func testClassifiesBasenameOfPathAndTruncatedComm() {
        XCTAssertEqual(AgentKindClassifier.classify(processName: "/opt/homebrew/bin/claude"), .claudeCode)
        XCTAssertEqual(
            AgentKindClassifier.classify(processName: "/Applications/Cursor.app/Contents/MacOS/Cursor"),
            .cursor
        )
        XCTAssertEqual(AgentKindClassifier.classify(processName: "Cursor Helper (G"), .cursor)
    }

    func testCursorCPUIsNeverABusySignal() {
        XCTAssertFalse(AgentKindClassifier.cpuCountsTowardBusy(processName: "Cursor"))
        XCTAssertFalse(AgentKindClassifier.cpuCountsTowardBusy(processName: "Cursor Helper (GPU)"))
        XCTAssertTrue(AgentKindClassifier.cpuCountsTowardBusy(processName: "claude"))
        XCTAssertTrue(AgentKindClassifier.cpuCountsTowardBusy(processName: "codex"))
    }
}
