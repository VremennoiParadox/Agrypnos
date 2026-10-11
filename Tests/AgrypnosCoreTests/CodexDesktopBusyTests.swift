import XCTest
@testable import AgrypnosCore

final class CodexDesktopBusyTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)
    private let renderer = "/Applications/ChatGPT.app/Contents/Frameworks/Codex Framework.framework/Versions/155/Helpers/Codex (Renderer).app/Contents/MacOS/Codex (Renderer)"

    func testDesktopCPUWithoutSessionWritesDoesNotCountAsBusy() {
        let desktopProcesses = [
            renderer + " --type=renderer",
            "/Applications/ChatGPT.app/Contents/Frameworks/Codex Framework.framework/Versions/155/Helpers/Codex (Service).app/Contents/MacOS/Codex (Service)",
            "/Applications/Codex.app/Contents/MacOS/Codex"
        ]
        for name in desktopProcesses {
            let snapshot = AgentHeuristicEngine().evaluate(
                processes: [ProcessRecord(pid: 1, cpuPercent: 40, name: name)],
                sessionWrites: [], now: now)
            let report = snapshot.reports.first { $0.kind == .codex }
            XCTAssertEqual(report?.processRunning, true, name)
            XCTAssertEqual(report?.cpuBusy, false, name)
            XCTAssertFalse(snapshot.anyBusy, name)
        }
    }

    func testDesktopWithFreshCodexTranscriptStillCountsAsBusy() {
        let snapshot = AgentHeuristicEngine().evaluate(
            processes: [ProcessRecord(pid: 1, cpuPercent: 0, name: renderer)],
            sessionWrites: [SessionFileSignal(
                url: URL(fileURLWithPath: "/Users/ada/.codex/sessions/2026/10/11/rollout-1.jsonl"),
                modified: now.addingTimeInterval(-1), kind: .codex)], now: now)
        XCTAssertTrue(snapshot.anyBusy)
    }

    func testRealCodexCLICPUStillCountsWithoutSessionWrites() {
        let cliProcesses = [
            "codex", "codex-exec",
            "/Applications/ChatGPT.app/Contents/Resources/codex-cli/CodexCLI.app/Contents/MacOS/codex",
            "/Applications/Codex.app/Contents/Resources/codex-cli/CodexCLI.app/Contents/MacOS/codex",
            "node /Users/ada/.npm/_npx/codex/bin/codex",
            "codex --file /Applications/Codex.app/Contents/MacOS/Codex",
            "codex --file /Applications/Codex (Renderer).app/Contents/MacOS/Codex (Renderer)",
            "/Applications/ChatGPT.app/Contents/Resources/codex-cli/CodexCLI.app/Contents/MacOS/codex --file /Applications/Codex.app/Contents/MacOS/Codex"
        ]
        for name in cliProcesses {
            let snapshot = AgentHeuristicEngine().evaluate(
                processes: [ProcessRecord(pid: 1, cpuPercent: 10, name: name)],
                sessionWrites: [], now: now)
            XCTAssertTrue(snapshot.anyBusy, name)
        }
    }

    func testCodexCLIPositionalPromptsRetainCPUEvidence() {
        for name in ["codex helper functions need tests", "codex (review this change)", "codex (Renderer)"] {
            let snapshot = AgentHeuristicEngine().evaluate(
                processes: [ProcessRecord(pid: 1, cpuPercent: 10, name: name)],
                sessionWrites: [], now: now)
            XCTAssertTrue(snapshot.anyBusy, name)
        }
    }

    func testFinalCursorSubagentWriteSettlesDespiteDesktopCPUInEitherPanelMode() {
        for mode in [PanelPowerMode.floor, .displaySleep] {
            var preferences = UserPreferences.default
            preferences.duration = .untilAgentsSettle
            preferences.includedAgentKinds = [.cursor, .codex]
            preferences.agentSettleGrace = 120
            preferences.panelPowerMode = mode
            var watch = WatchEngine(preferences: preferences)
            _ = watch.userSetEngaged(true, now: now)
            _ = watch.lidDidClose(now: now)
            let processes = [
                ProcessRecord(pid: 1, cpuPercent: 0, name: "cursor-agent"),
                ProcessRecord(pid: 2, cpuPercent: 40, name: renderer)
            ]
            let writes = [SessionFileSignal(
                url: URL(fileURLWithPath: "/Users/ada/.cursor/projects/p/agent-transcripts/parent/subagents/child.jsonl"),
                modified: now, kind: .cursor)]
            let safety = SafetyInputs(batteryPercent: 90, onBatteryDischarging: true,
                                      thermalSerious: false, lowPowerMode: false)
            var commands: [WatchCommand] = []
            for seconds in stride(from: 0, through: 165, by: 5) {
                let time = now.addingTimeInterval(Double(seconds))
                let snapshot = AgentHeuristicEngine().evaluate(processes: processes, sessionWrites: writes, now: time)
                commands = watch.tick(now: time, safety: safety, agents: snapshot)
                if seconds < 165 { XCTAssertTrue(watch.engaged) }
            }
            XCTAssertFalse(watch.engaged)
            XCTAssertTrue(commands.contains(.disengage(.agentsSettled)))
            XCTAssertTrue(commands.contains(.requestSleep))
            XCTAssertEqual(watch.preferences.duration, .untilAgentsSettle)
        }
    }
}
