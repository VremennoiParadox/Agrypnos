import XCTest
@testable import AgrypnosCore

final class AgentIncludeTests: XCTestCase {
    let t0 = Date(timeIntervalSince1970: 10_000)
    let now = Date(timeIntervalSince1970: 1_800_000_000)

    var engine: AgentHeuristicEngine {
        AgentHeuristicEngine(config: AgentHeuristicConfig(sessionFreshness: 45, claudeCodexCPUBusyThreshold: 5))
    }

    func testDefaultIncludeIsAllFourOn() {
        XCTAssertEqual(AgentKind.allCases, [.cursor, .claudeCode, .codex, .openCode])
        XCTAssertEqual(UserPreferences.default.includedAgentKinds, Set(AgentKind.allCases))
        XCTAssertEqual(UserPreferences().includedAgentKinds, Set(AgentKind.allCases))
        XCTAssertEqual(AgentIncludeChrome.defaultIncluded, Set(AgentKind.allCases))
        XCTAssertEqual(AgentIncludeChrome.titles, ["Cursor", "Claude Code", "Codex", "OpenCode"])
        XCTAssertEqual(AgrypnosCopy.agentInclude, "Which tools count as busy.")
        XCTAssertEqual(
            AgrypnosCopy.agentIncludeHelp,
            "Only selected tools count as busy. Keep at least one on."
        )
        XCTAssertFalse(AgrypnosCopy.agentInclude.lowercased().contains("we track every"))
        XCTAssertFalse(AgrypnosCopy.agentIncludeHelp.lowercased().contains("we track every"))
        XCTAssertFalse(AgrypnosCopy.agentIncludeHelp.lowercased().contains("still thinking"))
        XCTAssertFalse(AgrypnosCopy.agentIncludeHelp.lowercased().contains("every ai"))
        XCTAssertLessThanOrEqual(
            CopyWrap.lineCount(AgrypnosCopy.agentIncludeHelp, columns: PopoverCopyLayout.innerColumns),
            PopoverCopyLayout.helpMaxLines
        )
    }

    func testMissingIncludeKeyDecodesToAllFourIncludingOpenCode() throws {
        let json = """
        {"batteryFloorPercent":15,"duration":"indefinite","keyboardBacklightOff":true,"applyBrightnessFloor":true,"brightnessFloorPercent":15,"agentSettleGrace":120,"sessionFreshness":45,"lidOpenRampSeconds":2,"hotkey":{"keyCode":0,"option":true,"command":true,"shift":false,"control":false}}
        """
        let decoded = try JSONDecoder().decode(UserPreferences.self, from: Data(json.utf8))
        XCTAssertEqual(decoded.includedAgentKinds, Set(AgentKind.allCases))
        XCTAssertTrue(decoded.includedAgentKinds.contains(.openCode))
        XCTAssertTrue(decoded.includedAgentKinds.contains(.cursor))
        XCTAssertTrue(decoded.includedAgentKinds.contains(.claudeCode))
        XCTAssertTrue(decoded.includedAgentKinds.contains(.codex))
    }

    func testLegacyThreeKindListTurnsOpenCodeOn() throws {
        let json = """
        {"batteryFloorPercent":15,"duration":"indefinite","keyboardBacklightOff":true,"applyBrightnessFloor":true,"brightnessFloorPercent":15,"agentSettleGrace":120,"sessionFreshness":45,"lidOpenRampSeconds":2,"hotkey":{"keyCode":0,"option":true,"command":true,"shift":false,"control":false},"includedAgentKinds":["cursor","claudeCode","codex"]}
        """
        let decoded = try JSONDecoder().decode(UserPreferences.self, from: Data(json.utf8))
        XCTAssertEqual(decoded.includedAgentKinds, Set(AgentKind.allCases))
        XCTAssertTrue(decoded.includedAgentKinds.contains(.openCode))
    }

    func testEmptyIncludeClampsToAllFourAndApplyRejectsEmpty() throws {
        XCTAssertEqual(
            UserPreferences.clampIncludedAgentKinds([]),
            Set(AgentKind.allCases)
        )
        XCTAssertEqual(UserPreferences(includedAgentKinds: []).includedAgentKinds, Set(AgentKind.allCases))

        let emptyJSON = """
        {"batteryFloorPercent":15,"duration":"indefinite","keyboardBacklightOff":true,"applyBrightnessFloor":true,"brightnessFloorPercent":15,"agentSettleGrace":120,"sessionFreshness":45,"lidOpenRampSeconds":2,"hotkey":{"keyCode":0,"option":true,"command":true,"shift":false,"control":false},"includedAgentKinds":[]}
        """
        let decoded = try JSONDecoder().decode(UserPreferences.self, from: Data(emptyJSON.utf8))
        XCTAssertEqual(decoded.includedAgentKinds, Set(AgentKind.allCases))
        XCTAssertFalse(decoded.includedAgentKinds.isEmpty)

        var prefs = UserPreferences.default
        XCTAssertTrue(prefs.applyIncludedAgentKinds([.cursor]))
        XCTAssertEqual(prefs.includedAgentKinds, [.cursor])
        XCTAssertFalse(prefs.applyIncludedAgentKinds([]))
        XCTAssertEqual(prefs.includedAgentKinds, [.cursor])
        XCTAssertNil(AgentIncludeChrome.toggling(.cursor, in: [.cursor]))
        XCTAssertEqual(AgentIncludeChrome.toggling(.codex, in: [.cursor]), [.cursor, .codex])
    }

    func testOpenCodeOffRoundTrips() throws {
        var prefs = UserPreferences.default
        XCTAssertTrue(prefs.applyIncludedAgentKinds([.cursor]))
        XCTAssertEqual(prefs.includedAgentKinds, [.cursor])
        XCTAssertFalse(prefs.includedAgentKinds.contains(.openCode))
        let loaded = try roundTrip(prefs)
        XCTAssertEqual(loaded.includedAgentKinds, [.cursor])
        XCTAssertFalse(loaded.includedAgentKinds.contains(.openCode))

        let json = """
        {"batteryFloorPercent":15,"duration":"indefinite","keyboardBacklightOff":true,"applyBrightnessFloor":true,"brightnessFloorPercent":15,"agentSettleGrace":120,"sessionFreshness":45,"lidOpenRampSeconds":2,"hotkey":{"keyCode":0,"option":true,"command":true,"shift":false,"control":false},"includedAgentKinds":{"cursor":true,"claudeCode":false,"codex":false,"openCode":false}}
        """
        let decoded = try JSONDecoder().decode(UserPreferences.self, from: Data(json.utf8))
        XCTAssertEqual(decoded.includedAgentKinds, [.cursor])
        XCTAssertFalse(decoded.includedAgentKinds.contains(.openCode))

        let cursorOnlyList = """
        {"batteryFloorPercent":15,"duration":"indefinite","keyboardBacklightOff":true,"applyBrightnessFloor":true,"brightnessFloorPercent":15,"agentSettleGrace":120,"sessionFreshness":45,"lidOpenRampSeconds":2,"hotkey":{"keyCode":0,"option":true,"command":true,"shift":false,"control":false},"includedAgentKinds":["cursor"]}
        """
        let listed = try JSONDecoder().decode(UserPreferences.self, from: Data(cursorOnlyList.utf8))
        XCTAssertEqual(listed.includedAgentKinds, [.cursor])
        XCTAssertFalse(listed.includedAgentKinds.contains(.openCode))
    }

    func testExplicitSubsetWithoutOpenCodePersistsAndRoundTrips() throws {
        var prefs = UserPreferences.default
        XCTAssertTrue(prefs.applyIncludedAgentKinds([.cursor, .openCode]))
        let loaded = try roundTrip(prefs)
        XCTAssertEqual(loaded.includedAgentKinds, [.cursor, .openCode])
        XCTAssertFalse(loaded.includedAgentKinds.contains(.claudeCode))
        XCTAssertFalse(loaded.includedAgentKinds.contains(.codex))
    }

    func testDeselectedToolBusyIsIgnored() {
        let snap = mixedBusySnapshot()
        XCTAssertTrue(snap.anyBusy)
        XCTAssertTrue(snap.anyBusy(included: Set(AgentKind.allCases)))
        XCTAssertFalse(snap.anyBusy(included: [.claudeCode]))
        XCTAssertTrue(snap.anyBusy(included: [.cursor]))
        XCTAssertTrue(snap.anyBusy(included: [.openCode]))
        XCTAssertFalse(snap.anyBusy(included: [.codex]))
    }

    func testOpenCodeProcessAndFreshSessionIsBusyWhenSelected() {
        let snap = engine.evaluate(
            processes: [ProcessRecord(pid: 11, cpuPercent: 0.2, name: "opencode")],
            sessionWrites: [openCodeSession(modified: now.addingTimeInterval(-8))],
            now: now
        )
        XCTAssertEqual(snap.report(.openCode)?.processRunning, true)
        XCTAssertEqual(snap.report(.openCode)?.isBusy, true)
        XCTAssertTrue(snap.anyBusy(included: [.openCode]))
        XCTAssertFalse(snap.anyBusy(included: [.cursor]))
    }

    func testOpenCodeBusyIgnoredWhenDeselected() {
        let snap = engine.evaluate(
            processes: [ProcessRecord(pid: 11, cpuPercent: 22, name: "opencode")],
            sessionWrites: [openCodeSession(modified: now.addingTimeInterval(-8))],
            now: now
        )
        XCTAssertEqual(snap.report(.openCode)?.isBusy, true)
        XCTAssertFalse(snap.anyBusy(included: [.cursor, .claudeCode, .codex]))
    }

    func testCursorSubagentsCountOnlyWhenCursorIsSelected() {
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
                    modified: now.addingTimeInterval(-10),
                    kind: .cursor
                )
            ],
            now: now
        )
        XCTAssertEqual(snap.report(.cursor)?.isBusy, true)
        XCTAssertTrue(snap.anyBusy(included: [.cursor]))
        XCTAssertFalse(snap.anyBusy(included: [.claudeCode, .codex, .openCode]))
    }

    func testWatchEngineIgnoresDeselectedCursorSubagents() {
        var prefs = UserPreferences.default
        prefs.duration = .untilAgentsSettle
        XCTAssertTrue(prefs.applyIncludedAgentKinds([.openCode]))
        var watch = WatchEngine(preferences: prefs)
        _ = watch.userSetEngaged(true, now: t0)

        let cursorSubagentBusy = engine.evaluate(
            processes: [ProcessRecord(pid: 1, cpuPercent: 1, name: "Cursor")],
            sessionWrites: [
                SessionFileSignal(
                    url: URL(fileURLWithPath: "/Users/a/.cursor/projects/x/agent-transcripts/p/subagents/c.jsonl"),
                    modified: t0.addingTimeInterval(-10),
                    kind: .cursor
                )
            ],
            now: t0
        )
        XCTAssertTrue(cursorSubagentBusy.report(.cursor)?.isBusy ?? false)
        XCTAssertTrue(
            watch.tick(now: t0, safety: .acPower, agents: cursorSubagentBusy).isEmpty
        )
        XCTAssertTrue(
            watch.tick(now: t0.addingTimeInterval(10_000), safety: .acPower, agents: cursorSubagentBusy).isEmpty
        )
        XCTAssertTrue(watch.engaged)
        XCTAssertEqual(watch.preferences.duration, .untilAgentsSettle)
        XCTAssertNil(watch.preferences.lastWatchEnd)
    }

    func testWatchEngineSettlesOnSelectedOpenCodeIdle() {
        var prefs = UserPreferences.default
        prefs.duration = .untilAgentsSettle
        XCTAssertTrue(prefs.applyIncludedAgentKinds([.openCode]))
        var watch = WatchEngine(preferences: prefs)
        _ = watch.userSetEngaged(true, now: t0)

        let busy = engine.evaluate(
            processes: [ProcessRecord(pid: 11, cpuPercent: 0.2, name: "opencode")],
            sessionWrites: [
                SessionFileSignal(
                    url: URL(fileURLWithPath: "/Users/ada/.local/share/opencode/project/demo/storage/session/ses_1.json"),
                    modified: t0.addingTimeInterval(-8),
                    kind: .openCode
                )
            ],
            now: t0
        )
        XCTAssertTrue(busy.report(.openCode)?.isBusy ?? false)
        XCTAssertTrue(watch.tick(now: t0, safety: .acPower, agents: busy).isEmpty)

        let idle = engine.evaluate(
            processes: [ProcessRecord(pid: 11, cpuPercent: 0.2, name: "opencode")],
            sessionWrites: [
                SessionFileSignal(
                    url: URL(fileURLWithPath: "/Users/ada/.local/share/opencode/project/demo/storage/session/ses_1.json"),
                    modified: t0.addingTimeInterval(-120),
                    kind: .openCode
                )
            ],
            now: t0.addingTimeInterval(120)
        )
        XCTAssertFalse(idle.report(.openCode)?.isBusy ?? true)
        XCTAssertEqual(
            watch.tick(now: t0.addingTimeInterval(120), safety: .acPower, agents: idle),
            [.disengage(.agentsSettled)]
        )
        XCTAssertFalse(watch.engaged)
        XCTAssertEqual(watch.preferences.duration, .untilAgentsSettle)
        XCTAssertEqual(watch.preferences.includedAgentKinds, [.openCode])
    }

    private func mixedBusySnapshot() -> AgentSnapshot {
        engine.evaluate(
            processes: [
                ProcessRecord(pid: 1, cpuPercent: 1, name: "Cursor"),
                ProcessRecord(pid: 11, cpuPercent: 0.2, name: "opencode"),
            ],
            sessionWrites: [
                SessionFileSignal(
                    url: URL(fileURLWithPath: "/Users/a/.cursor/projects/x/agent-transcripts/t.jsonl"),
                    modified: now.addingTimeInterval(-10),
                    kind: .cursor
                ),
                openCodeSession(modified: now.addingTimeInterval(-8)),
            ],
            now: now
        )
    }

    private func openCodeSession(modified: Date) -> SessionFileSignal {
        SessionFileSignal(
            url: URL(fileURLWithPath: "/Users/ada/.local/share/opencode/project/demo/storage/session/ses_1.json"),
            modified: modified,
            kind: .openCode
        )
    }

    private func roundTrip(_ prefs: UserPreferences) throws -> UserPreferences {
        let data = try JSONEncoder().encode(prefs)
        return try JSONDecoder().decode(UserPreferences.self, from: data)
    }
}

private extension AgentSnapshot {
    func report(_ kind: AgentKind) -> AgentReport? {
        reports.first { $0.kind == kind }
    }
}

private extension SafetyInputs {
    static let acPower = SafetyInputs(
        batteryPercent: 90,
        onBatteryDischarging: false,
        thermalSerious: false,
        lowPowerMode: false
    )
}
