import XCTest
@testable import AgrypnosCore

final class AgentHeuristicEngineTests: XCTestCase {
    let now = Date(timeIntervalSince1970: 1_800_000_000)
    var engine: AgentHeuristicEngine {
        AgentHeuristicEngine(config: AgentHeuristicConfig(sessionFreshness: 45, claudeCodexCPUBusyThreshold: 5))
    }

    func testCursorOpenWithoutRecentTranscriptsIsNotBusy() {
        let snap = engine.evaluate(
            processes: [ProcessRecord(pid: 1, cpuPercent: 80, name: "Cursor Helper (GPU)")],
            sessionWrites: [
                SessionFileSignal(
                    url: URL(fileURLWithPath: "/Users/a/.cursor/projects/x/agent-transcripts/old.jsonl"),
                    modified: now.addingTimeInterval(-600),
                    kind: .cursor
                )
            ],
            now: now
        )
        XCTAssertFalse(snap.anyBusy)
        XCTAssertEqual(snap.report(.cursor)?.processRunning, true)
        XCTAssertEqual(snap.report(.cursor)?.isBusy, false)
    }

    func testCursorWithFreshAgentTranscriptIsBusy() {
        let snap = engine.evaluate(
            processes: [ProcessRecord(pid: 1, cpuPercent: 1, name: "Cursor")],
            sessionWrites: [
                SessionFileSignal(
                    url: URL(fileURLWithPath: "/Users/a/.cursor/projects/x/agent-transcripts/t.jsonl"),
                    modified: now.addingTimeInterval(-10),
                    kind: .cursor
                )
            ],
            now: now
        )
        XCTAssertTrue(snap.anyBusy)
        XCTAssertEqual(snap.report(.cursor)?.isBusy, true)
    }

    func testStaleSessionWithoutProcessIsNotBusy() {
        let snap = engine.evaluate(
            processes: [],
            sessionWrites: [
                SessionFileSignal(
                    url: URL(fileURLWithPath: "/Users/a/.claude/projects/p/s.jsonl"),
                    modified: now.addingTimeInterval(-1),
                    kind: .claudeCode
                )
            ],
            now: now
        )
        XCTAssertFalse(snap.anyBusy)
    }

    func testClaudeRecentJSONLIsBusy() {
        let snap = engine.evaluate(
            processes: [ProcessRecord(pid: 9, cpuPercent: 0.2, name: "claude")],
            sessionWrites: [
                SessionFileSignal(
                    url: URL(fileURLWithPath: "/Users/a/.claude/projects/p/s.jsonl"),
                    modified: now.addingTimeInterval(-8),
                    kind: .claudeCode
                )
            ],
            now: now
        )
        XCTAssertTrue(snap.report(.claudeCode)?.isBusy ?? false)
    }

    func testClaudeHighCPUWithoutFreshFilesIsBusy() {
        let snap = engine.evaluate(
            processes: [ProcessRecord(pid: 9, cpuPercent: 22, name: "claude")],
            sessionWrites: [
                SessionFileSignal(
                    url: URL(fileURLWithPath: "/Users/a/.claude/projects/p/s.jsonl"),
                    modified: now.addingTimeInterval(-10_000),
                    kind: .claudeCode
                )
            ],
            now: now
        )
        XCTAssertTrue(snap.report(.claudeCode)?.isBusy ?? false)
        XCTAssertTrue(snap.report(.claudeCode)?.cpuBusy ?? false)
    }

    func testClaudeIdlePromptIsNotBusy() {
        let snap = engine.evaluate(
            processes: [ProcessRecord(pid: 9, cpuPercent: 0.4, name: "claude")],
            sessionWrites: [
                SessionFileSignal(
                    url: URL(fileURLWithPath: "/Users/a/.claude/projects/p/s.jsonl"),
                    modified: now.addingTimeInterval(-120),
                    kind: .claudeCode
                )
            ],
            now: now
        )
        XCTAssertFalse(snap.report(.claudeCode)?.isBusy ?? true)
    }

    func testCodexMatchesClaudeRules() {
        let busy = engine.evaluate(
            processes: [ProcessRecord(pid: 3, cpuPercent: 1, name: "codex")],
            sessionWrites: [
                SessionFileSignal(
                    url: URL(fileURLWithPath: "/Users/a/.codex/sessions/2026/09/12/rollout-1.jsonl"),
                    modified: now.addingTimeInterval(-5),
                    kind: .codex
                )
            ],
            now: now
        )
        XCTAssertTrue(busy.report(.codex)?.isBusy ?? false)
    }

    func testCursorThinkPauseFiveMinutesIsIdleWithDefaultFreshness() {
        let engine = AgentHeuristicEngine()
        let snap = engine.evaluate(
            processes: [ProcessRecord(pid: 1, cpuPercent: 1, name: "Cursor")],
            sessionWrites: [
                SessionFileSignal(
                    url: URL(fileURLWithPath: "/Users/a/.cursor/projects/x/agent-transcripts/t.jsonl"),
                    modified: now.addingTimeInterval(-300),
                    kind: .cursor
                )
            ],
            now: now
        )
        XCTAssertFalse(snap.anyBusy)
        XCTAssertEqual(snap.report(.cursor)?.recentSessionWrite, false)
        XCTAssertEqual(snap.report(.cursor)?.isBusy, false)
    }

    func testCursorTranscriptOlderThanDefaultFreshnessIsIdle() {
        let engine = AgentHeuristicEngine()
        let snap = engine.evaluate(
            processes: [ProcessRecord(pid: 1, cpuPercent: 80, name: "Cursor Helper (GPU)")],
            sessionWrites: [
                SessionFileSignal(
                    url: URL(fileURLWithPath: "/Users/a/.cursor/projects/x/agent-transcripts/old.jsonl"),
                    modified: now.addingTimeInterval(-46),
                    kind: .cursor
                )
            ],
            now: now
        )
        XCTAssertFalse(snap.anyBusy)
        XCTAssertEqual(snap.report(.cursor)?.processRunning, true)
        XCTAssertEqual(snap.report(.cursor)?.isBusy, false)
    }

    func testClaudeCodeNodeWrapperWithFreshJSONLIsBusy() {
        let snap = engine.evaluate(
            processes: [
                ProcessRecord(
                    pid: 9,
                    cpuPercent: 0.2,
                    name: "node /usr/local/lib/node_modules/@anthropic-ai/claude-code/cli.js"
                )
            ],
            sessionWrites: [
                SessionFileSignal(
                    url: URL(fileURLWithPath: "/Users/a/.claude/projects/p/s.jsonl"),
                    modified: now.addingTimeInterval(-8),
                    kind: .claudeCode
                )
            ],
            now: now
        )
        XCTAssertTrue(snap.report(.claudeCode)?.isBusy ?? false)
    }

    func testClaudeDesktopAppIsNotClaudeCodeBusy() {
        let snap = engine.evaluate(
            processes: [
                ProcessRecord(
                    pid: 2,
                    cpuPercent: 40,
                    name: "/Applications/Claude.app/Contents/MacOS/Claude"
                )
            ],
            sessionWrites: [
                SessionFileSignal(
                    url: URL(fileURLWithPath: "/Users/a/.claude/projects/p/s.jsonl"),
                    modified: now.addingTimeInterval(-1),
                    kind: .claudeCode
                )
            ],
            now: now
        )
        XCTAssertEqual(snap.report(.claudeCode)?.processRunning, false)
        XCTAssertFalse(snap.report(.claudeCode)?.isBusy ?? true)
    }

    func testCursorParentStaleSubagentTranscriptWithinSubagentWindowIsBusy() {
        let engine = AgentHeuristicEngine()
        let snap = engine.evaluate(
            processes: [ProcessRecord(pid: 1, cpuPercent: 1, name: "Cursor")],
            sessionWrites: [
                SessionFileSignal(
                    url: URL(fileURLWithPath: "/Users/a/.cursor/projects/x/agent-transcripts/p/p.jsonl"),
                    modified: now.addingTimeInterval(-600),
                    kind: .cursor
                ),
                SessionFileSignal(
                    url: URL(fileURLWithPath: "/Users/a/.cursor/projects/x/agent-transcripts/p/subagents/c.jsonl"),
                    modified: now.addingTimeInterval(-600),
                    kind: .cursor
                )
            ],
            now: now
        )
        XCTAssertTrue(snap.anyBusy)
        XCTAssertEqual(snap.report(.cursor)?.recentSessionWrite, true)
        XCTAssertEqual(snap.report(.cursor)?.isBusy, true)
    }

    func testClaudeParentStaleSubagentJSONLWithinSubagentWindowIsBusy() {
        let engine = AgentHeuristicEngine()
        let snap = engine.evaluate(
            processes: [ProcessRecord(pid: 9, cpuPercent: 0.2, name: "claude")],
            sessionWrites: [
                SessionFileSignal(
                    url: URL(fileURLWithPath: "/Users/a/.claude/projects/p/s.jsonl"),
                    modified: now.addingTimeInterval(-600),
                    kind: .claudeCode
                ),
                SessionFileSignal(
                    url: URL(fileURLWithPath: "/Users/a/.claude/projects/p/s/subagents/agent-1.jsonl"),
                    modified: now.addingTimeInterval(-600),
                    kind: .claudeCode
                )
            ],
            now: now
        )
        XCTAssertTrue(snap.report(.claudeCode)?.isBusy ?? false)
        XCTAssertEqual(snap.report(.claudeCode)?.cpuBusy, false)
        XCTAssertEqual(snap.report(.claudeCode)?.recentSessionWrite, true)
    }
}

private extension AgentSnapshot {
    func report(_ kind: AgentKind) -> AgentReport? {
        reports.first { $0.kind == kind }
    }
}
