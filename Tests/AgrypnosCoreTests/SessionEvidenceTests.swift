import XCTest
@testable import AgrypnosCore

final class SessionEvidenceTests: XCTestCase {
    func testFutureTimestampIsNeitherBusyNorAWalkShortcut() {
        let now = Date()
        let future = SessionFileSignal(url: URL(fileURLWithPath: "/a/.cursor/chats/x.json"),
                                       modified: now.addingTimeInterval(3600), kind: .cursor)
        let fresh = SessionFileSignal(url: URL(fileURLWithPath: "/a/.cursor/chats/y.json"),
                                      modified: now.addingTimeInterval(-1), kind: .cursor)
        let snapshot = AgentHeuristicEngine().evaluate(
            processes: [ProcessRecord(pid: 1, cpuPercent: 0, name: "Cursor")],
            sessionWrites: [future], now: now)
        XCTAssertFalse(snapshot.anyBusy)
        XCTAssertFalse(SessionWalkBudget.hasFreshBusy([future], now: now, freshness: 45,
                                                       countTerminalSessions: false))
        XCTAssertEqual(SessionWalkBudget.selectNewest([future, fresh], now: now, freshness: 45).count, 2)
    }

    func testOnlyKnownOpenCodeWALSidecarIsRelevant() {
        let root = URL(fileURLWithPath: "/a/.local/share/opencode")
        XCTAssertTrue(SessionFileLayout.isRelevantFile(root.appendingPathComponent("opencode.db-wal"), kind: .openCode))
        for name in ["opencode.db-shm", "unrelated.db-wal", "opencode.db-journal"] {
            XCTAssertFalse(SessionFileLayout.isRelevantFile(root.appendingPathComponent(name), kind: .openCode))
        }
        XCTAssertEqual(SessionFileLayout.openCodeDataRootFiles(dataHome: root).map(\.lastPathComponent),
                       ["opencode.db", "opencode.db-wal"])
    }
}
