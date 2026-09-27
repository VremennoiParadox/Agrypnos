import XCTest
@testable import AgrypnosCore

final class SessionWalkBudgetTests: XCTestCase {
    let now = Date(timeIntervalSince1970: 1_800_000_000)

    func testDoesNotWalkUnselectedTools() {
        XCTAssertTrue(SessionWalkBudget.walksKind(.cursor, included: [.cursor]))
        XCTAssertFalse(SessionWalkBudget.walksKind(.openCode, included: [.cursor, .claudeCode]))
        XCTAssertTrue(SessionWalkBudget.walksKind(.claudeCode, included: [.claudeCode, .codex]))
    }

    func testStopsWhenAFreshBusyFileIsFound() {
        let stale = signal("stale.jsonl", kind: .cursor, age: 600)
        let fresh = signal("fresh.jsonl", kind: .cursor, age: 5)
        let older = signal("older.jsonl", kind: .cursor, age: 20)
        let picked = SessionWalkBudget.selectNewest(
            [stale, fresh, older],
            now: now,
            freshness: 45,
            cap: 4000
        )
        XCTAssertEqual(picked.map(\.url.lastPathComponent), ["fresh.jsonl"])
    }

    func testNewerTerminalDoesNotHideFreshTranscriptWhenI3Off() {
        let terminal = SessionFileSignal(
            url: URL(fileURLWithPath: "/Users/a/.cursor/chats/x/terminals/1.txt"),
            modified: now.addingTimeInterval(-1),
            kind: .cursor
        )
        let transcript = SessionFileSignal(
            url: URL(fileURLWithPath: "/Users/a/.cursor/chats/x/chat.json"),
            modified: now.addingTimeInterval(-10),
            kind: .cursor
        )
        let picked = SessionWalkBudget.selectNewest(
            [terminal, transcript],
            now: now,
            freshness: 45,
            countTerminalSessions: false
        )
        XCTAssertEqual(picked.map(\.url.lastPathComponent), ["chat.json"])
        XCTAssertFalse(
            SessionWalkBudget.hasFreshBusy(
                [terminal],
                now: now,
                freshness: 45,
                countTerminalSessions: false
            )
        )
        XCTAssertTrue(
            SessionWalkBudget.hasFreshBusy(
                [terminal, transcript],
                now: now,
                freshness: 45,
                countTerminalSessions: false
            )
        )
        XCTAssertTrue(
            SessionWalkBudget.hasFreshBusy(
                [terminal],
                now: now,
                freshness: 45,
                countTerminalSessions: true
            )
        )
        let withI3 = SessionWalkBudget.selectNewest(
            [terminal, transcript],
            now: now,
            freshness: 45,
            countTerminalSessions: true
        )
        XCTAssertEqual(withI3.map(\.url.lastPathComponent), ["1.txt"])
    }

    func testCapKeepsNewestMtimeNotDirectoryOrder() {
        var files: [SessionFileSignal] = []
        for i in 0..<50 {
            files.append(signal("old-\(i).jsonl", kind: .cursor, age: 10_000 - TimeInterval(i)))
        }
        files.append(signal("live.jsonl", kind: .cursor, age: 2))
        let picked = SessionWalkBudget.selectNewest(
            files,
            now: now,
            freshness: 45,
            cap: 10
        )
        XCTAssertEqual(picked.first?.url.lastPathComponent, "live.jsonl")
        XCTAssertLessThanOrEqual(picked.count, 10)
    }

    func testCapWithoutFreshKeepsNewestUnderBudget() {
        var files: [SessionFileSignal] = []
        for i in 0..<20 {
            files.append(signal("f-\(i).jsonl", kind: .cursor, age: TimeInterval(100 + i)))
        }
        let picked = SessionWalkBudget.selectNewest(
            files,
            now: now,
            freshness: 45,
            cap: 3
        )
        XCTAssertEqual(picked.count, 3)
        XCTAssertEqual(picked.map(\.url.lastPathComponent), ["f-0.jsonl", "f-1.jsonl", "f-2.jsonl"])
    }

    func testRootsOnlyIncludeSelectedKinds() {
        let home = URL(fileURLWithPath: "/Users/ada")
        let all = SessionFileLayout.roots(home: home, included: Set(AgentKind.allCases))
        XCTAssertEqual(Set(all.keys), Set(AgentKind.allCases))
        let cursorOnly = SessionFileLayout.roots(home: home, included: [.cursor])
        XCTAssertEqual(Set(cursorOnly.keys), [.cursor])
        XCTAssertFalse(cursorOnly.keys.contains(.openCode))
    }

    func testWalksOnlyIncludedKindsThatHaveAMatchingProcess() {
        let included = Set(AgentKind.allCases)
        XCTAssertEqual(
            SessionWalkBudget.kindsToWalk(included: included, processes: []),
            []
        )
        XCTAssertEqual(
            SessionWalkBudget.kindsToWalk(
                included: included,
                processes: [ProcessRecord(pid: 1, cpuPercent: 1, name: "Cursor")]
            ),
            [.cursor]
        )
        XCTAssertEqual(
            SessionWalkBudget.kindsToWalk(
                included: included,
                processes: [
                    ProcessRecord(pid: 9, cpuPercent: 0.2, name: "claude"),
                    ProcessRecord(pid: 3, cpuPercent: 1, name: "codex"),
                ]
            ),
            [.claudeCode, .codex]
        )
        XCTAssertEqual(
            SessionWalkBudget.kindsToWalk(
                included: [.codex],
                processes: [
                    ProcessRecord(
                        pid: 7,
                        cpuPercent: 22,
                        name: "node /Users/ada/src/codex-docs/build.js"
                    )
                ]
            ),
            []
        )
        XCTAssertEqual(
            SessionWalkBudget.kindsToWalk(
                included: [.openCode],
                processes: [
                    ProcessRecord(
                        pid: 8,
                        cpuPercent: 1,
                        name: "node /Users/ada/src/opencode-tools/index.js"
                    )
                ]
            ),
            []
        )
        XCTAssertEqual(
            SessionWalkBudget.kindsToWalk(
                included: [.openCode],
                processes: [ProcessRecord(pid: 11, cpuPercent: 0.2, name: "opencode")]
            ),
            [.openCode]
        )
    }

    private func signal(_ name: String, kind: AgentKind, age: TimeInterval) -> SessionFileSignal {
        SessionFileSignal(
            url: URL(fileURLWithPath: "/Users/a/.cursor/projects/x/agent-transcripts/\(name)"),
            modified: now.addingTimeInterval(-age),
            kind: kind
        )
    }
}
