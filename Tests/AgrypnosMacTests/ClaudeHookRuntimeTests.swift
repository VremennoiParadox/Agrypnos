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
        runtime.disableClaudeQuestionHook()
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
        runtime.engine.preferences.includedAgentKinds = [.claudeCode]
        runtime.engine.preferences.telegramInboundEnabled = true
        return runtime
    }
}
