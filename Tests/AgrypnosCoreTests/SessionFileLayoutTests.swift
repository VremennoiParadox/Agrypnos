import XCTest
@testable import AgrypnosCore

final class SessionFileLayoutTests: XCTestCase {
    let home = URL(fileURLWithPath: "/Users/ada")

    func testDefaultRoots() {
        let roots = SessionFileLayout.roots(home: home, env: [:])
        XCTAssertEqual(
            roots[.claudeCode],
            [URL(fileURLWithPath: "/Users/ada/.claude/projects")]
        )
        XCTAssertEqual(
            roots[.codex],
            [URL(fileURLWithPath: "/Users/ada/.codex/sessions")]
        )
        XCTAssertTrue(roots[.cursor]!.contains(URL(fileURLWithPath: "/Users/ada/.cursor/projects")))
        XCTAssertTrue(roots[.cursor]!.contains(URL(fileURLWithPath: "/Users/ada/.cursor/chats")))
    }

    func testHonorsClaudeAndCodexEnv() {
        let roots = SessionFileLayout.roots(
            home: home,
            env: [
                "CLAUDE_CONFIG_DIR": "/tmp/claude-home",
                "CODEX_HOME": "/tmp/codex-home",
            ]
        )
        XCTAssertEqual(roots[.claudeCode], [URL(fileURLWithPath: "/tmp/claude-home/projects")])
        XCTAssertEqual(roots[.codex], [URL(fileURLWithPath: "/tmp/codex-home/sessions")])
    }

    func testCursorXDGChatsAreIncluded() {
        let roots = SessionFileLayout.roots(
            home: home,
            env: ["XDG_CONFIG_HOME": "/Users/ada/.config"]
        )
        XCTAssertTrue(roots[.cursor]!.contains(URL(fileURLWithPath: "/Users/ada/.config/cursor/chats")))
    }

    func testRelevantFiles() {
        let claude = URL(fileURLWithPath: "/Users/ada/.claude/projects/-Users-ada-src/abc.jsonl")
        let rollout = URL(fileURLWithPath: "/Users/ada/.codex/sessions/2026/09/12/rollout-1-uuid.jsonl")
        let transcript = URL(fileURLWithPath: "/Users/ada/.cursor/projects/foo/agent-transcripts/t.jsonl")
        let store = URL(fileURLWithPath: "/Users/ada/.cursor/chats/id/uuid/store.db")
        let noise = URL(fileURLWithPath: "/Users/ada/.cursor/projects/foo/README.md")

        XCTAssertEqual(SessionFileLayout.classify(claude), .claudeCode)
        XCTAssertTrue(SessionFileLayout.isRelevantFile(claude, kind: .claudeCode))
        XCTAssertTrue(SessionFileLayout.isRelevantFile(rollout, kind: .codex))
        XCTAssertTrue(SessionFileLayout.isRelevantFile(transcript, kind: .cursor))
        XCTAssertTrue(SessionFileLayout.isRelevantFile(store, kind: .cursor))
        XCTAssertFalse(SessionFileLayout.isRelevantFile(noise, kind: .cursor))
        XCTAssertFalse(SessionFileLayout.isRelevantFile(URL(fileURLWithPath: "/tmp/other.jsonl"), kind: .codex))
    }

    func testCursorTerminalsAreRelevantAndNoiseIsNot() {
        let terminal = URL(fileURLWithPath: "/Users/ada/.cursor/projects/foo/terminals/1.txt")
        let modules = URL(fileURLWithPath: "/Users/ada/.cursor/projects/foo/node_modules/pkg/readme.md")
        XCTAssertTrue(SessionFileLayout.isRelevantFile(terminal, kind: .cursor))
        XCTAssertFalse(SessionFileLayout.isRelevantFile(modules, kind: .cursor))
        XCTAssertTrue(SessionFileLayout.shouldSkipDirectory("node_modules"))
        XCTAssertTrue(SessionFileLayout.shouldSkipDirectory(".git"))
        XCTAssertFalse(SessionFileLayout.shouldSkipDirectory("agent-transcripts"))
    }

    func testCursorWalkRootsAreTranscriptsAndTerminalsNotWholeProject() {
        let projects = URL(fileURLWithPath: "/Users/ada/.cursor/projects")
        let urls = SessionFileLayout.cursorWalkRoots(
            projectsRoot: projects,
            projectNames: ["Agrypnos", "Other"]
        )
        XCTAssertEqual(
            urls,
            [
                URL(fileURLWithPath: "/Users/ada/.cursor/projects/Agrypnos/agent-transcripts"),
                URL(fileURLWithPath: "/Users/ada/.cursor/projects/Agrypnos/terminals"),
                URL(fileURLWithPath: "/Users/ada/.cursor/projects/Other/agent-transcripts"),
                URL(fileURLWithPath: "/Users/ada/.cursor/projects/Other/terminals"),
            ]
        )
    }
}
