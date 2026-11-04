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
        XCTAssertEqual(AgentKindClassifier.classify(processName: "codex"), .codex)
        XCTAssertEqual(AgentKindClassifier.classify(processName: "codex-exec"), .codex)
    }

    func testClaudeCodeCLIAndDesktopMainClassifyButHelpersDoNot() {
        XCTAssertEqual(AgentKindClassifier.classify(processName: "claude"), .claudeCode)
        XCTAssertEqual(AgentKindClassifier.classify(processName: "/opt/homebrew/bin/claude"), .claudeCode)
        XCTAssertEqual(
            AgentKindClassifier.classify(
                processName: "node /usr/local/lib/node_modules/@anthropic-ai/claude-code/cli.js"
            ),
            .claudeCode
        )
        // The desktop app hosts the Code tab, so its main process stands in for Claude Code.
        XCTAssertEqual(
            AgentKindClassifier.classify(processName: "/Applications/Claude.app/Contents/MacOS/Claude"),
            .claudeCode
        )
        XCTAssertEqual(
            AgentKindClassifier.classify(processName: "/Users/a/Apps/Claude.app/Contents/MacOS/Claude --flag"),
            .claudeCode
        )
        XCTAssertNil(AgentKindClassifier.classify(processName: "Claude Helper"))
        XCTAssertNil(AgentKindClassifier.classify(processName: "Claude Helper (Renderer)"))
        XCTAssertNil(AgentKindClassifier.classify(
            processName: "/Applications/Claude.app/Contents/Frameworks/Claude Helper.app/Contents/MacOS/Claude Helper --type=renderer"
        ))
        XCTAssertNil(AgentKindClassifier.classify(
            processName: "/Applications/Claude.app/Contents/Frameworks/Electron Framework.framework/Helpers/chrome_crashpad_handler"
        ))
        XCTAssertNil(AgentKindClassifier.classify(processName: "/Applications/Claude.app/Contents/Frameworks/Squirrel.framework/Resources/ShipIt"))
    }

    func testClaudeDesktopCPUDoesNotCountTowardBusy() {
        XCTAssertFalse(AgentKindClassifier.cpuCountsTowardBusy(processName: "/Applications/Claude.app/Contents/MacOS/Claude"))
        XCTAssertTrue(AgentKindClassifier.cpuCountsTowardBusy(processName: "claude"))
    }

    /// The Code tab launches this binary for each session. It is the real agent process, so CPU counts.
    func testClaudeCodeBinaryBundledWithTheDesktopAppIsTheCLI() {
        let bundled = "/Users/a/Library/Application Support/Claude/claude-code/2.1.295/9d6405864fdc/claude.app/Contents/MacOS/claude"
        XCTAssertEqual(AgentKindClassifier.classify(processName: bundled), .claudeCode)
        XCTAssertEqual(AgentKindClassifier.classify(processName: bundled + " --output-format stream-json"), .claudeCode)
        XCTAssertTrue(AgentKindClassifier.cpuCountsTowardBusy(processName: bundled))
    }

    func testCodexCLIAndNodeWrapper() {
        XCTAssertEqual(AgentKindClassifier.classify(processName: "codex"), .codex)
        XCTAssertEqual(AgentKindClassifier.classify(processName: "codex-exec"), .codex)
        XCTAssertEqual(
            AgentKindClassifier.classify(processName: "node /Users/ada/.npm/_npx/codex/bin/codex"),
            .codex
        )
    }

    func testNodeArgContainingCodexSubstringIsNotCodex() {
        XCTAssertNil(
            AgentKindClassifier.classify(processName: "node /Users/ada/src/codex-docs/build.js")
        )
        XCTAssertFalse(
            AgentKindClassifier.cpuCountsTowardBusy(
                processName: "node /Users/ada/src/codex-docs/build.js"
            )
        )
    }

    func testBareNodeStillIgnored() {
        XCTAssertNil(AgentKindClassifier.classify(processName: "node"))
        XCTAssertNil(AgentKindClassifier.classify(processName: "/usr/local/bin/node"))
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

    func testCursorWinsWhenArgsContainClaudePath() {
        XCTAssertEqual(
            AgentKindClassifier.classify(
                processName: "/Applications/Cursor.app/Contents/MacOS/Cursor /Users/a/claude/notes.md"
            ),
            .cursor
        )
        XCTAssertEqual(
            AgentKindClassifier.classify(processName: "cursor-agent --workspace /Users/a/claude"),
            .cursor
        )
    }

    func testCursorCPUIsNeverABusySignal() {
        XCTAssertFalse(AgentKindClassifier.cpuCountsTowardBusy(processName: "Cursor"))
        XCTAssertFalse(AgentKindClassifier.cpuCountsTowardBusy(processName: "Cursor Helper (GPU)"))
        XCTAssertTrue(AgentKindClassifier.cpuCountsTowardBusy(processName: "claude"))
        XCTAssertTrue(AgentKindClassifier.cpuCountsTowardBusy(processName: "codex"))
        XCTAssertFalse(AgentKindClassifier.cpuCountsTowardBusy(processName: "opencode"))
        XCTAssertFalse(AgentKindClassifier.cpuCountsTowardBusy(processName: "OpenCode Helper"))
    }

    func testOpenCodeCLIClassifiesAndDesktopAppDoesNot() {
        XCTAssertEqual(AgentKindClassifier.classify(processName: "opencode"), .openCode)
        XCTAssertEqual(AgentKindClassifier.classify(processName: "/opt/homebrew/bin/opencode"), .openCode)
        XCTAssertEqual(AgentKindClassifier.classify(processName: "opencode-cli"), .openCode)
        XCTAssertEqual(
            AgentKindClassifier.classify(processName: "bun /Users/ada/.bun/bin/opencode run"),
            .openCode
        )
        XCTAssertEqual(
            AgentKindClassifier.classify(processName: "node /usr/local/lib/node_modules/opencode/bin/opencode"),
            .openCode
        )
        XCTAssertNil(AgentKindClassifier.classify(processName: "/Applications/OpenCode.app/Contents/MacOS/OpenCode"))
        XCTAssertNil(AgentKindClassifier.classify(processName: "OpenCode Helper"))
        XCTAssertEqual(
            AgentKindClassifier.classify(processName: "/Applications/OpenCode.app/Contents/MacOS/opencode-cli"),
            .openCode
        )
    }

    func testNodeArgContainingOpenCodeSubstringIsNotOpenCode() {
        XCTAssertNil(
            AgentKindClassifier.classify(processName: "node /Users/ada/src/opencode-tools/index.js")
        )
        XCTAssertNil(
            AgentKindClassifier.classify(processName: "bun /Users/ada/src/opencode-tools/build.ts")
        )
    }
}
