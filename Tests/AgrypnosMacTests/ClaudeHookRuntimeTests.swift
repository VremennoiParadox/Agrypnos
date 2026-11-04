import Foundation
import XCTest
import AgrypnosCore
@testable import AgrypnosMac

@MainActor
final class ClaudeHookRuntimeTests: XCTestCase {
    func testEnableMergesAskUserQuestionAndKeepsBrainrot() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let settings = root.appendingPathComponent("settings.json")
        try Self.brainrot.write(to: settings)
        let runtime = makeRuntime(settings: settings)
        defer { stop(runtime) }
        XCTAssertFalse(runtime.engaged)
        let enabled = await runtime.enableClaudeQuestionHook()
        XCTAssertTrue(enabled)
        XCTAssertTrue(runtime.preferences.claudeQuestionHookEnabled)
        XCTAssertTrue(runtime.preferences.forwardAgentQuestions)
        XCTAssertFalse(runtime.engaged)
        let merged = try JSONSerialization.jsonObject(with: Data(contentsOf: settings)) as! [String: Any]
        let hooks = merged["hooks"] as! [String: Any]
        XCTAssertEqual(((hooks["Stop"] as? [[String: Any]])?.first?["hooks"] as? [[String: Any]])?.first?["command"] as? String,
            "/Users/test/.brainrot/brainrot-state.sh")
        XCTAssertTrue(String(data: try Data(contentsOf: settings), encoding: .utf8)!.contains("--claude-question-hook"))
        XCTAssertNotNil(runtime.claudeQuestionHookSource)
        runtime.disableClaudeQuestionHook()
        XCTAssertNil(runtime.claudeQuestionHookSource)
        XCTAssertFalse(runtime.preferences.claudeQuestionHookEnabled)
        let disabled = String(data: try Data(contentsOf: settings), encoding: .utf8)!
        XCTAssertFalse(disabled.contains("--claude-question-hook"))
        XCTAssertTrue(disabled.contains("brainrot-state.sh"))
    }

    func testEnableCreatesMissingSettingsFileWithoutTouchingHome() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let settings = root.appendingPathComponent(".claude/settings.json")
        XCTAssertFalse(FileManager.default.fileExists(atPath: settings.path))
        XCTAssertNotEqual(settings.path, FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude/settings.json").path)
        let runtime = makeRuntime(settings: settings)
        defer { stop(runtime) }
        let enabled = await runtime.enableClaudeQuestionHook()
        XCTAssertTrue(enabled)
        XCTAssertTrue(runtime.preferences.claudeQuestionHookEnabled)
        XCTAssertTrue(FileManager.default.fileExists(atPath: settings.path))
        let body = String(data: try Data(contentsOf: settings), encoding: .utf8)!
        XCTAssertTrue(body.contains("--claude-question-hook"))
        XCTAssertTrue(body.contains("AskUserQuestion"))
    }

    func testDisableDoesNotClearPrefWhenSettingsWriteFails() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: root.path)
            try? FileManager.default.removeItem(at: root)
        }
        let settings = root.appendingPathComponent("settings.json")
        try Self.brainrot.write(to: settings)
        let runtime = makeRuntime(settings: settings)
        defer { stop(runtime) }
        let enabled = await runtime.enableClaudeQuestionHook()
        XCTAssertTrue(enabled)
        XCTAssertTrue(runtime.preferences.claudeQuestionHookEnabled)
        try FileManager.default.setAttributes([.posixPermissions: 0o555], ofItemAtPath: root.path)
        runtime.disableClaudeQuestionHook()
        XCTAssertTrue(runtime.preferences.claudeQuestionHookEnabled)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: root.path)
        let body = String(data: try Data(contentsOf: settings), encoding: .utf8)!
        XCTAssertTrue(body.contains("--claude-question-hook"))
        XCTAssertTrue(body.contains("brainrot-state.sh"))
    }

    func testHookStdinReachesReceiveAsClaudeCodeAndSubmitReturnsReturnedToHook() async throws {
        let dir = URL(fileURLWithPath: "/private/tmp/ag-claude-src-" + UUID().uuidString, isDirectory: true)
        let sock = dir.appendingPathComponent("hook.sock")
        defer { try? FileManager.default.removeItem(at: dir) }
        let stdin = Data(#"""
        {"session_id":"sess_live","cwd":"/Users/test/project","hook_event_name":"PreToolUse","tool_name":"AskUserQuestion","tool_use_id":"toolu_live","tool_input":{"questions":[{"question":"Pick B?","header":"Pick","options":[{"label":"A","description":"no"},{"label":"B","description":"yes"}],"multiSelect":false}]}}
        """#.utf8)
        let submitted = expectation(description: "returnedToHook")
        let source = ClaudeQuestionHookSource(socketURL: sock, uptime: { 1000 }, receive: { batch, submit, _ in
            XCTAssertEqual(batch.key.provider, .claudeCode)
            XCTAssertEqual(batch.questions[0].options.map(\.label), ["A", "B"])
            Task { @MainActor in
                let delivery = await submit(QuestionAnswer(key: batch.key, selections: [
                    QuestionSelection(questionID: "Pick B?", optionIDs: ["B"])
                ]))
                XCTAssertEqual(delivery, .returnedToHook)
                submitted.fulfill()
            }
            return true
        })
        try source.start()
        defer { source.stop() }
        let reply = try await Task.detached {
            try ClaudeQuestionHookProcess.exchange(stdin, socketURL: sock, connectTimeout: 2)
        }.value
        await fulfillment(of: [submitted], timeout: 5)
        XCTAssertTrue(ClaudeAskUserQuestionPayload.isSufficientAskUserQuestionOutput(reply))
        let root = try XCTUnwrap(JSONSerialization.jsonObject(with: reply) as? [String: Any])
        let answers = ((root["hookSpecificOutput"] as? [String: Any])?["updatedInput"] as? [String: Any])?["answers"] as? [String: String]
        XCTAssertEqual(answers, ["Pick B?": "B"])
    }

    func testMissingSocketIsNativeFallbackWithinTwoSeconds() {
        let missing = FileManager.default.temporaryDirectory.appendingPathComponent("agrypnos-claude-missing.sock")
        let started = Date()
        XCTAssertThrowsError(try ClaudeQuestionHookProcess.exchange(Data("{}".utf8), socketURL: missing, connectTimeout: 2))
        XCTAssertLessThan(Date().timeIntervalSince(started), 3)
        let out = ClaudeAskUserQuestionPayload.helperStdout(stdin: Data(#"""
        {"session_id":"s","cwd":"/p","hook_event_name":"PreToolUse","tool_name":"AskUserQuestion","tool_use_id":"t","tool_input":{"questions":[{"question":"Q?","header":"Q","options":[{"label":"A","description":"a"},{"label":"B","description":"b"}],"multiSelect":false}]}}
        """#.utf8)) { _ in throw ClaudeAskUserQuestionPayload.Error.invalidRequest }
        XCTAssertEqual(out, ClaudeAskUserQuestionPayload.nativeFallback)
    }

    private static let brainrot = Data(#"""
        {"hooks":{"UserPromptSubmit":[{"hooks":[{"type":"command","command":"/Users/test/.brainrot/brainrot-state.sh"}]}],"Stop":[{"hooks":[{"type":"command","command":"/Users/test/.brainrot/brainrot-state.sh"}]}],"StopFailure":[{"hooks":[{"type":"command","command":"/Users/test/.brainrot/brainrot-state.sh"}]}]}}
        """#.utf8)

    private func makeRuntime(settings: URL) -> WatchRuntime {
        let defaults = UserDefaults(suiteName: "ag-claude-hook-" + UUID().uuidString)!
        let runtime = WatchRuntime(store: PreferencesStore(defaults: defaults), readLid: { false },
            readKernel: { .clear }, setKernel: { _ in XCTFail("must not arm"); return .ok },
            runCommand: { _, _ in XCTFail("must not run power command"); return (0, "", "") },
            notify: { _ in },
            readNotifSecrets: {
                NotifSecrets(telegramBotToken: "fixture", telegramChatId: "9", telegramQuestionUserId: "42")
            })
        runtime.claudeSettingsURLOverride = settings
        let sockDir = URL(fileURLWithPath: "/private/tmp/ag-claude-hook-" + UUID().uuidString, isDirectory: true)
        runtime.claudeHookSocketURLOverride = sockDir.appendingPathComponent("hook.sock")
        runtime.engine.preferences.includedAgentKinds = [.claudeCode]
        runtime.engine.preferences.telegramInboundEnabled = true
        return runtime
    }

    private func stop(_ runtime: WatchRuntime) {
        runtime.stopQuestionSources()
        if let sock = runtime.claudeHookSocketURLOverride {
            try? FileManager.default.removeItem(at: sock.deletingLastPathComponent())
        }
    }
}
