import Foundation
import XCTest
import AgrypnosCore
@testable import AgrypnosMac

@MainActor
final class CodexAlertHookProcessTests: XCTestCase {
    func testMissingSocketExitsQuiet() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("missing-\(UUID().uuidString).sock")
        let output = CodexAlertHookProcess.run(stdin: Data("{}".utf8), socketURL: url)
        XCTAssertEqual(output, Data())
    }

    func testPreferenceDefaultsOff() throws {
        XCTAssertFalse(UserPreferences().codexAlertEnabled)
        var object = try JSONSerialization.jsonObject(with: JSONEncoder().encode(UserPreferences())) as! [String: Any]
        object.removeValue(forKey: "codexAlertEnabled")
        let decoded = try JSONDecoder().decode(UserPreferences.self, from: JSONSerialization.data(withJSONObject: object))
        XCTAssertFalse(decoded.codexAlertEnabled)
    }

    func testEnableWithoutDestinationDoesNotWriteHooks() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let hooks = root.appendingPathComponent("hooks.json")
        let runtime = makeRuntime(hooks: hooks, secrets: NotifSecrets())
        defer { stop(runtime) }
        XCTAssertFalse(runtime.enableCodexAlerts())
        XCTAssertFalse(runtime.preferences.codexAlertEnabled)
        XCTAssertFalse(FileManager.default.fileExists(atPath: hooks.path))
        XCTAssertEqual(runtime.codexAlertCaption, "Save a Telegram chat or Discord webhook first.")
        XCTAssertFalse(runtime.engaged)
        XCTAssertNotEqual(hooks.path, FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".codex/hooks.json").path)
    }

    func testEnableMergesTempHooksWithoutIdleOptInOrArm() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let hooks = root.appendingPathComponent("hooks.json")
        try Self.brainrot.write(to: hooks)
        let runtime = makeRuntime(hooks: hooks)
        defer { stop(runtime) }
        runtime.engine.preferences.notifEnabled = false
        XCTAssertFalse(runtime.engaged)
        XCTAssertTrue(runtime.enableCodexAlerts())
        XCTAssertTrue(runtime.preferences.codexAlertEnabled)
        XCTAssertFalse(runtime.preferences.notifEnabled)
        XCTAssertFalse(runtime.engaged)
        let text = String(data: try Data(contentsOf: hooks), encoding: .utf8)!
        XCTAssertTrue(text.contains("brainrot-state.sh"))
        XCTAssertTrue(text.contains("--codex-alert-hook"))
        XCTAssertTrue(text.contains("request_user_input"))
        XCTAssertTrue(text.contains("UserPromptSubmit"))
        XCTAssertTrue(text.contains("Stop"))
        XCTAssertEqual(
            runtime.codexAlertCaption,
            "Added the hook. In Codex, run /hooks and trust it. Until then, no alert is sent."
        )
        runtime.disableCodexAlerts()
        XCTAssertFalse(runtime.preferences.codexAlertEnabled)
        let after = String(data: try Data(contentsOf: hooks), encoding: .utf8)!
        XCTAssertTrue(after.contains("UserPromptSubmit"))
        XCTAssertTrue(after.contains("Stop"))
        XCTAssertTrue(after.contains("brainrot-state.sh"))
        XCTAssertFalse(after.contains("--codex-alert-hook"))
        XCTAssertFalse(runtime.engaged)
    }

    func testQuestionStdinPostsSentenceAndLeavesWatchOff() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let hooks = root.appendingPathComponent("hooks.json")
        let runtime = makeRuntime(hooks: hooks)
        defer { stop(runtime) }
        XCTAssertTrue(runtime.enableCodexAlerts())
        let sock = try XCTUnwrap(runtime.codexSocketURLOverride)
        let stdin = Data("""
        {"hook_event_name":"PreToolUse","tool_name":"request_user_input","tool_input":{"questions":[{"id":"q","question":"Which?","options":[{"label":"A"},{"label":"B"}]}]}}
        """.utf8)
        let output = await Task.detached {
            CodexAlertHookProcess.run(stdin: stdin, socketURL: sock)
        }.value
        XCTAssertEqual(output, Data())
        XCTAssertEqual(runtime.codexPostedSentences, ["Codex is waiting on you.\n\nWhich?"])
        XCTAssertFalse(runtime.engaged)
    }

    private static let brainrot = Data(#"""
        {"hooks":{"UserPromptSubmit":[{"hooks":[{"type":"command","command":"/Users/me/.brainrot/brainrot-state.sh"}]}],"Stop":[{"hooks":[{"type":"command","command":"/Users/me/.brainrot/brainrot-state.sh"}]}]}}
        """#.utf8)

    private func makeRuntime(hooks: URL, secrets: NotifSecrets? = nil) -> WatchRuntime {
        let loaded = secrets ?? NotifSecrets(telegramBotToken: "fixture", telegramChatId: "9")
        let defaults = UserDefaults(suiteName: "ag-codex-alert-" + UUID().uuidString)!
        let runtime = WatchRuntime(store: PreferencesStore(defaults: defaults), readLid: { false },
            readKernel: { .clear }, setKernel: { _ in XCTFail("must not arm"); return .ok },
            runCommand: { _, _ in XCTFail("must not run power command"); return (0, "", "") },
            notify: { _ in },
            readNotifSecrets: { loaded })
        runtime.codexHooksURLOverride = hooks
        let sockDir = URL(fileURLWithPath: "/private/tmp/ag-codex-alert-" + UUID().uuidString, isDirectory: true)
        runtime.codexSocketURLOverride = sockDir.appendingPathComponent("hook.sock")
        runtime.codexSuppressNetwork = true
        runtime.engine.preferences.notifEnabled = false
        return runtime
    }

    private func stop(_ runtime: WatchRuntime) {
        runtime.stopQuestionSources()
        if let sock = runtime.codexSocketURLOverride {
            try? FileManager.default.removeItem(at: sock.deletingLastPathComponent())
        }
    }
}
