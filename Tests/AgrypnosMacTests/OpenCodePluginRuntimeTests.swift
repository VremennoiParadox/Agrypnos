import Foundation
import XCTest
import AgrypnosCore
@testable import AgrypnosMac

@MainActor
final class OpenCodePluginRuntimeTests: XCTestCase {
    func testEnableWaitsForRealHostNeverArmsAndDisableRevokesManifest() async throws {
        let fixture = Fixture(); defer { fixture.cleanup() }
        let runtime = fixture.runtime
        let enabled = await runtime.enableOpenCodeForwarding()
        XCTAssertTrue(enabled)
        XCTAssertTrue(runtime.preferences.openCodePluginEnabled)
        XCTAssertTrue(runtime.preferences.forwardAgentQuestions)
        XCTAssertFalse(runtime.engaged)
        XCTAssertNotNil(runtime.openCodePluginSource)
        XCTAssertTrue(runtime.openCodeQuestionCaption.contains("waiting"))
        let manifest = fixture.bridge.appendingPathComponent("bridge.json")
        let active = try JSONSerialization.jsonObject(with: Data(contentsOf: manifest)) as! [String: Any]
        XCTAssertEqual(active["active"] as? Bool, true)
        runtime.disableOpenCodeForwarding()
        XCTAssertFalse(runtime.preferences.forwardAgentQuestions)
        XCTAssertNil(runtime.openCodePluginSource)
        let inactive = try JSONSerialization.jsonObject(with: Data(contentsOf: manifest)) as! [String: Any]
        XCTAssertEqual(inactive["active"] as? Bool, false)
        XCTAssertNil(inactive["token"])
        XCTAssertTrue(FileManager.default.fileExists(atPath: fixture.config.appendingPathComponent("agrypnos-opencode.js").path))
    }
    func testInstalledIntegrationCanBeRemovedWhileManualSourceIsSelected() async throws {
        let fixture = Fixture(); defer { fixture.cleanup() }
        let runtime = fixture.runtime
        let enabled = await runtime.enableOpenCodeForwarding()
        XCTAssertTrue(enabled)
        // Saving manual settings selects this source while retaining the owned installation.
        runtime.engine.preferences.openCodePluginEnabled = false
        runtime.stopQuestionSources()
        XCTAssertTrue(runtime.openCodeIntegrationCanBeRemoved)
        let removed = await runtime.removeOpenCodeForwarding()
        XCTAssertTrue(removed)
        XCTAssertFalse(runtime.openCodeIntegrationCanBeRemoved)
    }
    func testDisableDuringInstallCancelsEnableAndDoubleClickInstallsOnce() async throws {
        let fixture = Fixture(); defer { fixture.cleanup() }
        let started = expectation(description: "install started")
        let gate = DispatchSemaphore(value: 0)
        var writes = 0
        fixture.writeHook = { data, url in
            writes += 1
            if writes == 1 { started.fulfill(); gate.wait() }
            try OpenCodePrivateFiles.write(data, to: url)
        }
        let runtime = fixture.runtime
        let first = Task { await runtime.enableOpenCodeForwarding() }
        await fulfillment(of: [started], timeout: 2)
        let duplicate = await runtime.enableOpenCodeForwarding()
        XCTAssertFalse(duplicate)
        runtime.disableOpenCodeForwarding()
        gate.signal()
        let result = await first.value
        XCTAssertFalse(result)
        XCTAssertFalse(runtime.preferences.forwardAgentQuestions)
        XCTAssertFalse(runtime.preferences.openCodePluginEnabled)
        XCTAssertNil(runtime.openCodePluginSource)
    }
    func testLongConfigurationPathStillUsesShortPrivateSocket() async throws {
        let fixture = Fixture(); defer { fixture.cleanup() }
        fixture.bridgeOverride = fixture.root.appendingPathComponent(String(repeating: "b", count: 90))
        let enabled = await fixture.runtime.enableOpenCodeForwarding()
        XCTAssertTrue(enabled)
        let manifest = try JSONSerialization.jsonObject(with: Data(contentsOf: fixture.bridge.appendingPathComponent("bridge.json"))) as! [String: Any]
        let path = try XCTUnwrap(manifest["socketPath"] as? String)
        XCTAssertLessThan(path.utf8.count, 104)
        fixture.runtime.disableOpenCodeForwarding()
        XCTAssertFalse(FileManager.default.fileExists(atPath: path))
    }
    func testPrerequisitesAndFailureKeepPreferencesUnchanged() async throws {
        for missing in ["owner", "inbound", "selection", "installation"] {
            let fixture = Fixture(); defer { fixture.cleanup() }
            let runtime = fixture.runtime
            if missing == "owner" { fixture.secrets.telegramQuestionUserId = nil }
            if missing == "inbound" { runtime.engine.preferences.telegramInboundEnabled = false }
            if missing == "selection" { runtime.engine.preferences.includedAgentKinds = [.codex] }
            if missing == "installation" {
                try FileManager.default.createDirectory(at: fixture.config, withIntermediateDirectories: true)
                try Data("foreign".utf8).write(to: fixture.config.appendingPathComponent("agrypnos-opencode.js"))
            }
            let before = runtime.preferences
            let enabled = await runtime.enableOpenCodeForwarding()
            XCTAssertFalse(enabled); XCTAssertEqual(runtime.preferences, before)
            XCTAssertNil(runtime.openCodePluginSource); XCTAssertFalse(fixture.notices.isEmpty)
        }
    }
    func testRepeatedEnableDoesNotReinstallOrReplaceSourceAndSleepUsesFreshGeneration() async throws {
        let fixture = Fixture(); defer { fixture.cleanup() }
        let runtime = fixture.runtime
        let first = await runtime.enableOpenCodeForwarding()
        XCTAssertTrue(first)
        let source = runtime.openCodePluginSource
        let second = await runtime.enableOpenCodeForwarding()
        XCTAssertTrue(second); XCTAssertTrue(source === runtime.openCodePluginSource)
        let old = try Data(contentsOf: fixture.bridge.appendingPathComponent("bridge.json"))
        runtime.questionSourcesSuspended = true; runtime.clearQuestionWatch()
        XCTAssertNil(runtime.openCodePluginSource)
        runtime.questionSourcesSuspended = false; runtime.syncQuestionSources()
        XCTAssertNotNil(runtime.openCodePluginSource)
        XCTAssertFalse(source === runtime.openCodePluginSource)
        XCTAssertNotEqual(try Data(contentsOf: fixture.bridge.appendingPathComponent("bridge.json")), old)
        let removed = await runtime.removeOpenCodeForwarding()
        XCTAssertTrue(removed); XCTAssertFalse(runtime.preferences.forwardAgentQuestions)
        XCTAssertFalse(FileManager.default.fileExists(atPath: fixture.config.appendingPathComponent("agrypnos-opencode.js").path))
        XCTAssertEqual(fixture.secrets.telegramBotToken, "fixture")
    }
}

@MainActor
private final class Fixture {
    let root = URL(fileURLWithPath: "/private/tmp/ag-runtime-" + UUID().uuidString)
    var config: URL { root.appendingPathComponent("config") }
    var bridgeOverride: URL?
    var bridge: URL { bridgeOverride ?? root.appendingPathComponent("bridge") }
    var secrets = NotifSecrets(telegramBotToken: "fixture", telegramChatId: "9", telegramQuestionUserId: "42")
    var notices: [String] = []
    var writeHook: ((Data, URL) throws -> Void)?
    let defaults = UserDefaults(suiteName: "ag-plugin-runtime-" + UUID().uuidString)!
    lazy var runtime: WatchRuntime = {
        let runtime = WatchRuntime(store: PreferencesStore(defaults: defaults), readLid: { false }, readKernel: { .clear },
            setKernel: { _ in XCTFail("must not arm"); return .ok },
            runCommand: { _, _ in XCTFail("must not run power command"); return (0, "", "") },
            notify: { [weak self] in self?.notices.append($0) },
            readNotifSecrets: { [weak self] in self?.secrets ?? NotifSecrets() },
            openCodePluginInstaller: { [unowned self] in
                var installer = OpenCodePluginInstaller(configRoot: self.config, bridgeRoot: self.bridge, pluginData: Data("fixture".utf8))
                if let hook = self.writeHook { installer.write = hook }
                return installer
            })
        runtime.engine.preferences.telegramInboundEnabled = true
        runtime.engine.preferences.includedAgentKinds = [.openCode]
        return runtime
    }()
    func cleanup() { runtime.stopQuestionSources(); try? FileManager.default.removeItem(at: root) }
}
