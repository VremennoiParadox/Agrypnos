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
        XCTAssertEqual(
            roots[.openCode],
            [URL(fileURLWithPath: "/Users/ada/.local/share/opencode")]
        )
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

    func testOpenCodeHonorsXDGDataHome() {
        let roots = SessionFileLayout.roots(
            home: home,
            env: ["XDG_DATA_HOME": "/tmp/xdg-data"]
        )
        XCTAssertEqual(
            roots[.openCode],
            [URL(fileURLWithPath: "/tmp/xdg-data/opencode")]
        )
    }

    func testOpenCodeSessionFilesAreRelevantAndAuthLogAreNot() {
        let session = URL(
            fileURLWithPath: "/Users/ada/.local/share/opencode/project/demo/storage/session/ses_1.json"
        )
        let legacy = URL(
            fileURLWithPath: "/Users/ada/.local/share/opencode/storage/session/ses_2.json"
        )
        let sqlite = URL(fileURLWithPath: "/Users/ada/.local/share/opencode/storage/opencode.db")
        let dataRootDB = URL(fileURLWithPath: "/Users/ada/.local/share/opencode/opencode.db")
        let xdgDB = URL(fileURLWithPath: "/tmp/xdg-data/opencode/opencode.db")
        let auth = URL(fileURLWithPath: "/Users/ada/.local/share/opencode/auth.json")
        let log = URL(fileURLWithPath: "/Users/ada/.local/share/opencode/log/2026-09-22T123456.log")
        let config = URL(fileURLWithPath: "/Users/ada/.config/opencode/opencode.json")

        XCTAssertEqual(SessionFileLayout.classify(session), .openCode)
        XCTAssertEqual(SessionFileLayout.classify(legacy), .openCode)
        XCTAssertTrue(SessionFileLayout.isRelevantFile(session, kind: .openCode))
        XCTAssertTrue(SessionFileLayout.isRelevantFile(legacy, kind: .openCode))
        XCTAssertTrue(SessionFileLayout.isRelevantFile(sqlite, kind: .openCode))
        XCTAssertEqual(SessionFileLayout.classify(dataRootDB), .openCode)
        XCTAssertTrue(SessionFileLayout.isRelevantFile(dataRootDB, kind: .openCode))
        XCTAssertEqual(SessionFileLayout.classify(xdgDB), .openCode)
        XCTAssertTrue(SessionFileLayout.isRelevantFile(xdgDB, kind: .openCode))
        XCTAssertFalse(SessionFileLayout.isRelevantFile(auth, kind: .openCode))
        XCTAssertFalse(SessionFileLayout.isRelevantFile(log, kind: .openCode))
        XCTAssertNil(SessionFileLayout.classify(config))
        XCTAssertFalse(SessionFileLayout.isRelevantFile(config, kind: .openCode))
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
        XCTAssertTrue(SessionFileLayout.shouldSkipDirectory("log"))
        XCTAssertFalse(SessionFileLayout.shouldSkipDirectory("agent-transcripts"))
    }

    func testOpenCodeWalkRootsAreStorageTreesPlusDataRootDB() {
        let dataHome = URL(fileURLWithPath: "/Users/ada/.local/share/opencode")
        XCTAssertEqual(
            SessionFileLayout.openCodeDataRootFiles(dataHome: dataHome),
            [URL(fileURLWithPath: "/Users/ada/.local/share/opencode/opencode.db")]
        )
        XCTAssertEqual(
            SessionFileLayout.openCodeWalkRoots(dataHome: dataHome, projectNames: ["demo", "global"]),
            [
                URL(fileURLWithPath: "/Users/ada/.local/share/opencode/storage"),
                URL(fileURLWithPath: "/Users/ada/.local/share/opencode/project/demo/storage"),
                URL(fileURLWithPath: "/Users/ada/.local/share/opencode/project/global/storage"),
            ]
        )
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

    func testSubagentSessionPathIsNestedSubagentsDirectory() {
        XCTAssertTrue(
            SessionFileLayout.isSubagentSessionPath(
                URL(fileURLWithPath: "/Users/ada/.cursor/projects/foo/agent-transcripts/p/subagents/c.jsonl")
            )
        )
        XCTAssertTrue(
            SessionFileLayout.isSubagentSessionPath(
                URL(fileURLWithPath: "/Users/ada/.claude/projects/p/s/subagents/agent-1.jsonl")
            )
        )
        XCTAssertFalse(
            SessionFileLayout.isSubagentSessionPath(
                URL(fileURLWithPath: "/Users/ada/.cursor/projects/foo/agent-transcripts/p/p.jsonl")
            )
        )
        XCTAssertFalse(
            SessionFileLayout.isSubagentSessionPath(
                URL(fileURLWithPath: "/Users/ada/.codex/sessions/2026/09/21/rollout-1.jsonl")
            )
        )
    }

    func testNestedSubagentJSONLIsARelevantSessionFile() {
        let cursorChild = URL(
            fileURLWithPath: "/Users/ada/.cursor/projects/foo/agent-transcripts/p/subagents/c.jsonl"
        )
        let claudeChild = URL(
            fileURLWithPath: "/Users/ada/.claude/projects/p/s/subagents/agent-1.jsonl"
        )
        XCTAssertTrue(SessionFileLayout.isRelevantFile(cursorChild, kind: .cursor))
        XCTAssertEqual(SessionFileLayout.classify(cursorChild), .cursor)
        XCTAssertTrue(SessionFileLayout.isRelevantFile(claudeChild, kind: .claudeCode))
        XCTAssertEqual(SessionFileLayout.classify(claudeChild), .claudeCode)
    }

    func testAgentToolsAndClaudeMetaAreNotSessionFiles() {
        let tools = URL(fileURLWithPath: "/Users/ada/.cursor/projects/foo/agent-tools/out.txt")
        let meta = URL(
            fileURLWithPath: "/Users/ada/.claude/projects/p/s/subagents/agent-1.meta.json"
        )
        XCTAssertFalse(SessionFileLayout.isRelevantFile(tools, kind: .cursor))
        XCTAssertFalse(SessionFileLayout.isSubagentSessionPath(tools))
        XCTAssertFalse(SessionFileLayout.isRelevantFile(meta, kind: .claudeCode))
        XCTAssertTrue(SessionFileLayout.isSubagentSessionPath(meta))
    }
}
