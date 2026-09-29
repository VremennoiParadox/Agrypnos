import XCTest
import SQLite3
import AgrypnosCore
@testable import AgrypnosMac

final class SessionCollectorTests: XCTestCase {
    func testWALCommitCountsWhenMainDatabaseIsStale() throws {
        let home = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let data = home.appendingPathComponent(".local/share/opencode")
        try FileManager.default.createDirectory(at: data, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: home) }
        let dbURL = data.appendingPathComponent("opencode.db")
        var db: OpaquePointer?
        XCTAssertEqual(sqlite3_open(dbURL.path, &db), SQLITE_OK)
        defer { sqlite3_close(db) }
        XCTAssertEqual(sqlite3_exec(db, "PRAGMA journal_mode=WAL; CREATE TABLE event (id INTEGER); PRAGMA wal_checkpoint(TRUNCATE);", nil, nil, nil), SQLITE_OK)
        try FileManager.default.setAttributes([.modificationDate: Date().addingTimeInterval(-300)], ofItemAtPath: dbURL.path)
        XCTAssertEqual(sqlite3_exec(db, "INSERT INTO event VALUES (1);", nil, nil, nil), SQLITE_OK)
        let now = Date()
        let files = SessionFileWalker.signals(home: home, env: [:], countTerminalSessions: false,
            included: [.openCode], now: now, freshness: 45)
        let snapshot = AgentHeuristicEngine().evaluate(
            processes: [ProcessRecord(pid: 1, cpuPercent: 0, name: "opencode")],
            sessionWrites: files.values, now: now)
        XCTAssertTrue(snapshot.anyBusy(included: [.openCode]))
        XCTAssertTrue(files.values.contains { $0.url.lastPathComponent == "opencode.db-wal" })
    }

    func testFutureFileCannotEstablishACompleteIdleObservation() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let file = root.appendingPathComponent("agent-transcripts/session.jsonl")
        try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try Data("{}".utf8).write(to: file)
        try FileManager.default.setAttributes([.modificationDate: Date().addingTimeInterval(3600)], ofItemAtPath: file.path)
        let now = Date()
        let files = SessionFileWalker.walk(root: root, kind: .cursor, now: now, freshness: 45, countTerminalSessions: false)
        XCTAssertFalse(files.complete)
        let snapshot = AgentHeuristicEngine().evaluate(
            processes: [ProcessRecord(pid: 1, cpuPercent: 0, name: "Cursor")], sessionWrites: files.values, now: now)
        let observation = AgentProbeObservation(snapshot: snapshot, startedAt: now, completedAt: now, complete: files.complete)
        XCTAssertNil(observation.settleBusy(included: [.cursor], now: now))
    }
}
