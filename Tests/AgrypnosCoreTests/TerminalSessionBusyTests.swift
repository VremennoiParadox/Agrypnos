import XCTest
@testable import AgrypnosCore

final class TerminalSessionBusyTests: XCTestCase {
    let now = Date(timeIntervalSince1970: 1_800_000_000)

    func testWatchEngineStoresTerminalsPreference() {
        var engine = WatchEngine(preferences: .default)
        XCTAssertFalse(engine.preferences.countTerminalSessionsAsBusy)
        engine.userSetCountTerminalSessionsAsBusy(true)
        XCTAssertTrue(engine.preferences.countTerminalSessionsAsBusy)
        engine.userSetCountTerminalSessionsAsBusy(false)
        XCTAssertFalse(engine.preferences.countTerminalSessionsAsBusy)
    }

    func testPreferenceDefaultsOffAndMissingKeyStaysOff() throws {
        XCTAssertFalse(UserPreferences.default.countTerminalSessionsAsBusy)
        XCTAssertFalse(UserPreferences().countTerminalSessionsAsBusy)

        let json = """
        {"batteryFloorPercent":15,"duration":"indefinite","keyboardBacklightOff":true,"applyBrightnessFloor":true,"brightnessFloorPercent":15,"agentSettleGrace":120,"sessionFreshness":45,"lidOpenRampSeconds":2,"hotkey":{"keyCode":0,"option":true,"command":true,"shift":false,"control":false}}
        """
        let decoded = try JSONDecoder().decode(UserPreferences.self, from: Data(json.utf8))
        XCTAssertFalse(decoded.countTerminalSessionsAsBusy)

        var on = UserPreferences.default
        on.countTerminalSessionsAsBusy = true
        let loaded = try JSONDecoder().decode(
            UserPreferences.self,
            from: try JSONEncoder().encode(on)
        )
        XCTAssertTrue(loaded.countTerminalSessionsAsBusy)
    }

    func testBusyMathUsesTheSamePersistedKeyAsTheUIToggle() throws {
        var on = UserPreferences.default
        on.countTerminalSessionsAsBusy = true
        let object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: try JSONEncoder().encode(on)) as? [String: Any]
        )
        XCTAssertEqual(
            Set(object.keys.filter { $0.lowercased().contains("terminal") }),
            ["countTerminalSessionsAsBusy"]
        )
        XCTAssertNil(object["countTerminalsAsBusy"])
        XCTAssertNil(object["includeTerminals"])
    }

    func testCursorTerminalWriteIsBusyOnlyWhenPreferenceIsOn() {
        let terminal = SessionFileSignal(
            url: URL(fileURLWithPath: "/Users/a/.cursor/projects/x/terminals/1.txt"),
            modified: now.addingTimeInterval(-5),
            kind: .cursor
        )
        let process = ProcessRecord(pid: 1, cpuPercent: 1, name: "Cursor")

        let off = AgentHeuristicEngine(config: AgentHeuristicConfig(
            sessionFreshness: 45,
            countTerminalSessionsAsBusy: false
        ))
        XCTAssertFalse(
            off.evaluate(processes: [process], sessionWrites: [terminal], now: now).report(.cursor)?.isBusy ?? true
        )

        let on = AgentHeuristicEngine(config: AgentHeuristicConfig(
            sessionFreshness: 45,
            countTerminalSessionsAsBusy: true
        ))
        XCTAssertTrue(
            on.evaluate(processes: [process], sessionWrites: [terminal], now: now).report(.cursor)?.isBusy ?? false
        )
    }

    func testTranscriptBusyDoesNotNeedTheTerminalsToggle() {
        let transcript = SessionFileSignal(
            url: URL(fileURLWithPath: "/Users/a/.cursor/projects/x/agent-transcripts/t.jsonl"),
            modified: now.addingTimeInterval(-5),
            kind: .cursor
        )
        let process = ProcessRecord(pid: 1, cpuPercent: 1, name: "Cursor")
        let off = AgentHeuristicEngine(config: AgentHeuristicConfig(
            sessionFreshness: 45,
            countTerminalSessionsAsBusy: false
        ))
        XCTAssertTrue(
            off.evaluate(processes: [process], sessionWrites: [transcript], now: now).report(.cursor)?.isBusy ?? false
        )
    }

    func testSubagentJSONLIsNotTheTerminalsToggle() {
        let child = SessionFileSignal(
            url: URL(
                fileURLWithPath: "/Users/a/.cursor/projects/x/agent-transcripts/p/subagents/c.jsonl"
            ),
            modified: now.addingTimeInterval(-5),
            kind: .cursor
        )
        XCTAssertTrue(SessionFileLayout.isSubagentSessionPath(child.url))
        XCTAssertFalse(SessionFileLayout.isTerminalSessionPath(child.url))

        let process = ProcessRecord(pid: 1, cpuPercent: 1, name: "Cursor")
        let off = AgentHeuristicEngine(config: AgentHeuristicConfig(
            sessionFreshness: 45,
            countTerminalSessionsAsBusy: false
        ))
        XCTAssertTrue(
            off.evaluate(processes: [process], sessionWrites: [child], now: now).report(.cursor)?.isBusy ?? false
        )
    }

    func testAnyWalkedLayoutTerminalsCountWhenOn() {
        let claudeTerminal = SessionFileSignal(
            url: URL(fileURLWithPath: "/Users/a/.claude/projects/p/terminals/1.txt"),
            modified: now.addingTimeInterval(-2),
            kind: .claudeCode
        )
        XCTAssertTrue(SessionFileLayout.isTerminalSessionPath(claudeTerminal.url))
        let process = ProcessRecord(pid: 9, cpuPercent: 0.1, name: "claude")

        let off = AgentHeuristicEngine(config: AgentHeuristicConfig(
            sessionFreshness: 45,
            countTerminalSessionsAsBusy: false
        ))
        XCTAssertFalse(
            off.evaluate(processes: [process], sessionWrites: [claudeTerminal], now: now)
                .report(.claudeCode)?.recentSessionWrite ?? true
        )

        let on = AgentHeuristicEngine(config: AgentHeuristicConfig(
            sessionFreshness: 45,
            countTerminalSessionsAsBusy: true
        ))
        XCTAssertTrue(
            on.evaluate(processes: [process], sessionWrites: [claudeTerminal], now: now)
                .report(.claudeCode)?.recentSessionWrite ?? false
        )
    }

    func testCursorWalkRootsOmitTerminalsWhenPreferenceIsOff() {
        let projects = URL(fileURLWithPath: "/Users/ada/.cursor/projects")
        XCTAssertEqual(
            SessionFileLayout.cursorWalkRoots(
                projectsRoot: projects,
                projectNames: ["Agrypnos"],
                includeTerminals: false
            ),
            [URL(fileURLWithPath: "/Users/ada/.cursor/projects/Agrypnos/agent-transcripts")]
        )
        XCTAssertEqual(
            SessionFileLayout.cursorWalkRoots(
                projectsRoot: projects,
                projectNames: ["Agrypnos"],
                includeTerminals: true
            ),
            [
                URL(fileURLWithPath: "/Users/ada/.cursor/projects/Agrypnos/agent-transcripts"),
                URL(fileURLWithPath: "/Users/ada/.cursor/projects/Agrypnos/terminals"),
            ]
        )
    }

    func testLayoutStillMarksTerminalFilesRelevant() {
        let terminal = URL(fileURLWithPath: "/Users/ada/.cursor/projects/foo/terminals/1.txt")
        XCTAssertTrue(SessionFileLayout.isRelevantFile(terminal, kind: .cursor))
        XCTAssertTrue(SessionFileLayout.isTerminalSessionPath(terminal))
        XCTAssertFalse(
            SessionFileLayout.countsTowardBusy(terminal, countTerminalSessions: false)
        )
        XCTAssertTrue(
            SessionFileLayout.countsTowardBusy(terminal, countTerminalSessions: true)
        )
    }

    func testProjectNamedTerminalsIsNotATerminalSessionFile() {
        let transcript = URL(
            fileURLWithPath: "/Users/a/.cursor/projects/terminals/agent-transcripts/t.jsonl"
        )
        XCTAssertFalse(SessionFileLayout.isTerminalSessionPath(transcript))
        XCTAssertTrue(
            SessionFileLayout.countsTowardBusy(transcript, countTerminalSessions: false)
        )
    }
}

private extension AgentSnapshot {
    func report(_ kind: AgentKind) -> AgentReport? {
        reports.first { $0.kind == kind }
    }
}
