# Agents Watch Reliability Implementation Plan

I'm using the writing-plans skill to create this implementation plan.

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.
>
> **Do not start execution from the investigation agent.** The parent offers execution to the user.

**Goal:** Agents mode stays armed through real think/tool/cloud pauses, then allows sleep only after the user idle-wait; lid-closed keep-awake re-asserts `SleepDisabled` instead of silently dropping the watch.

**Architecture:** Keep `AgrypnosCore` as the only decision point. Widen the **busy** definition in `AgentHeuristicEngine` / `AgentKindClassifier` / `SessionFileLayout` (one `evaluate()` every caller already uses). Pass kernel readback into `WatchEngine.tick` so a dropped `SleepDisabled` while engaged emits `.assertSleepDisabled` instead of AppKit silently calling `userSetEngaged(false)`. Mac adapters stay thin: `ps` args, walk only session subtrees, execute the new command via existing `armKernel()`.

**Tech Stack:** Swift, XCTest (`AgrypnosCore` on Linux), AppKit adapters on macOS. No new dependencies. No network.

**Investigation:** `docs/superpowers/plans/2026-09-14-agents-watch-reliability-investigation.md`

## Global Constraints

- Menu-bar extra only (`LSUIElement`). No settings window, no Dock-first UI.
- `AgrypnosCore` decides; Mac adapters execute (`pmset`, IOKit, `ps`, session-file mtimes).
- No file over 600 lines; prefer ~250.
- MIT. No telemetry. No stealth network. Do not log `ps` args (they can contain API keys).
- Do not name competing products in product docs or commit messages.
- Do not claim watt numbers.
- Do not kill Wi-Fi or Bluetooth.
- Armed ≠ black screen: no `displaysleepnow`, no keyboard-off, no panel blank on Keep the watch toggle.
- V1 agents only: Cursor, Claude Code, Codex. Local heuristics. Correctness over coverage. No transcript body parse. No per-tool include list (locked).
- Busy → stay awake. Settled idle after **user settle grace** (15s–15m, default 90s) → allow sleep.
- Lid-closed keep-awake is `pmset -a disablesleep` (SleepDisabled). IOKit assertions are not the lid story.
- Lid-close hygiene: brightness floor % (default 15, range 5–40, never 0%) + keyboard backlight off. Not `displaysleepnow`.
- Safety: reboot clears SleepDisabled; launch-at-login **never** re-arms; sudoers remains **exactly two** `pmset disablesleep` commands.
- Copy honesty: no “ended / standing down” copy while still held awake.
- Product-only commit messages. TDD: failing test first, watch it fail, then implement.
- Ponytail: smallest root-cause diff. Do not auto-rearm at login. Do not expand providers. Do not add a freshness slider. Do not treat long-lived `cursor-agent worker` as busy. Keep `requestSleep` on lid-closed auto-off.

---

## File map

| File | Role |
|---|---|
| `Sources/AgrypnosCore/Session/UserPreferences.swift` | Default + migrate `sessionFreshness` off legacy 45s. |
| `Sources/AgrypnosCore/Agent/AgentHeuristicEngine.swift` | Default freshness 900s; still the only `isBusy` math. |
| `Sources/AgrypnosCore/Agent/AgentKindClassifier.swift` | CLI vs GUI; node wrappers; ignore bare `node`. |
| `Sources/AgrypnosCore/Agent/SessionFileLayout.swift` | Cursor subtrees (`agent-transcripts`, `terminals`); skip noise dirs; terminals relevant. |
| `Sources/AgrypnosCore/Session/WatchTypes.swift` | `WatchCommand.assertSleepDisabled`. |
| `Sources/AgrypnosCore/Session/WatchEngine.swift` | `tick(..., kernelSleepDisabled:)`; lid close re-asserts kernel. |
| `Apps/Agrypnos/Sources/Agent/AgentProbeService.swift` | `ps` `args=`; walk layout subtrees only. |
| `Apps/Agrypnos/Sources/WatchRuntime.swift` | Pass kernel readback into tick; apply `.assertSleepDisabled` via `armKernel()`; stop silent disengage. |
| `Apps/Agrypnos/Sources/Power/PowerHygieneCoordinator.swift` | Exhaustive switch for the new command (no-op; runtime applies kernel). |
| Tests listed per task | Fail first, then implement. |

No new god objects. No AppDelegate helpers.

---

### Task 1: Session freshness covers think / tool pauses

**Files:**
- Modify: `Sources/AgrypnosCore/Session/UserPreferences.swift`
- Modify: `Sources/AgrypnosCore/Agent/AgentHeuristicEngine.swift`
- Test: `Tests/AgrypnosCoreTests/AgentHeuristicEngineTests.swift`
- Test: `Tests/AgrypnosCoreTests/CorePrefsMathTests.swift`

**Interfaces:**
- Consumes: existing `AgentHeuristicEngine.evaluate(processes:sessionWrites:now:)` → `AgentSnapshot.anyBusy`.
- Produces: `UserPreferences.defaultSessionFreshness == 900`. Legacy decoded `45` becomes `900`. `AgentHeuristicConfig` default `sessionFreshness` is `900`. Tests may still construct `AgentHeuristicConfig(sessionFreshness: 45)` to pin window math.

- [ ] **Step 1: Write the failing tests**

Append to `Tests/AgrypnosCoreTests/AgentHeuristicEngineTests.swift` (keep the existing 45s `engine` helper for the old window tests):

```swift
    func testCursorThinkPauseFiveMinutesStillBusyWithDefaultFreshness() {
        let engine = AgentHeuristicEngine()
        let snap = engine.evaluate(
            processes: [ProcessRecord(pid: 1, cpuPercent: 1, name: "Cursor")],
            sessionWrites: [
                SessionFileSignal(
                    url: URL(fileURLWithPath: "/Users/a/.cursor/projects/x/agent-transcripts/t.jsonl"),
                    modified: now.addingTimeInterval(-300),
                    kind: .cursor
                )
            ],
            now: now
        )
        XCTAssertTrue(snap.anyBusy)
        XCTAssertEqual(snap.report(.cursor)?.recentSessionWrite, true)
        XCTAssertEqual(snap.report(.cursor)?.isBusy, true)
    }

    func testCursorTranscriptOlderThanDefaultFreshnessIsIdle() {
        let engine = AgentHeuristicEngine()
        let snap = engine.evaluate(
            processes: [ProcessRecord(pid: 1, cpuPercent: 80, name: "Cursor Helper (GPU)")],
            sessionWrites: [
                SessionFileSignal(
                    url: URL(fileURLWithPath: "/Users/a/.cursor/projects/x/agent-transcripts/old.jsonl"),
                    modified: now.addingTimeInterval(-901),
                    kind: .cursor
                )
            ],
            now: now
        )
        XCTAssertFalse(snap.anyBusy)
        XCTAssertEqual(snap.report(.cursor)?.processRunning, true)
        XCTAssertEqual(snap.report(.cursor)?.isBusy, false)
    }
```

Append to `Tests/AgrypnosCoreTests/CorePrefsMathTests.swift` inside `CorePrefsMathTests`:

```swift
    func testDefaultSessionFreshnessIsFifteenMinutes() {
        XCTAssertEqual(UserPreferences.defaultSessionFreshness, 900)
        XCTAssertEqual(UserPreferences.default.sessionFreshness, 900)
        XCTAssertEqual(AgentHeuristicConfig().sessionFreshness, 900)
    }

    func testLegacyFortyFiveSecondFreshnessMigratesToDefault() throws {
        let loaded = try JSONDecoder().decode(
            UserPreferences.self,
            from: Data(fixtureJSON().utf8)
        )
        XCTAssertEqual(loaded.sessionFreshness, 900)
    }
```

`fixtureJSON()` already encodes `"sessionFreshness":45`.

- [ ] **Step 2: Run tests to verify they fail**

Run:

```bash
swift test --filter AgentHeuristicEngineTests.testCursorThinkPauseFiveMinutesStillBusyWithDefaultFreshness --filter CorePrefsMathTests.testDefaultSessionFreshnessIsFifteenMinutes --filter CorePrefsMathTests.testLegacyFortyFiveSecondFreshnessMigratesToDefault
```

Expected: FAIL because default freshness is still 45, so a 300s-old Cursor transcript is not busy, and decoded prefs stay 45.

Then run:

```bash
swift test --filter AgentHeuristicEngineTests.testCursorTranscriptOlderThanDefaultFreshnessIsIdle
```

Expected: PASS already (901s is idle at 45s and stays idle at 900s). Keep the test as the ceiling so the wider window cannot hold a 15-minute-stale IDE forever.

- [ ] **Step 3: Write minimal implementation**

In `UserPreferences.swift`, next to the other static defaults:

```swift
    /// Seconds of session-file mtime that still count as busy.
    /// Hidden: not a popover control. Must cover think / tool pauses; 45s does not.
    public static let defaultSessionFreshness: TimeInterval = 900
    /// Values below this are the old 45s default (or junk) and migrate.
    public static let sessionFreshnessLegacyCeiling: TimeInterval = 300
    public static let sessionFreshnessRange: ClosedRange<TimeInterval> = 300...1_800
```

Change the init default `sessionFreshness: TimeInterval = 45` to `= UserPreferences.defaultSessionFreshness`.

After assigning `self.agentSettleGrace`, replace the raw `self.sessionFreshness = sessionFreshness` with:

```swift
        self.sessionFreshness = Self.clampSessionFreshness(sessionFreshness)
```

Add:

```swift
    public static func clampSessionFreshness(_ seconds: TimeInterval) -> TimeInterval {
        guard seconds.isFinite else { return defaultSessionFreshness }
        if seconds < sessionFreshnessLegacyCeiling { return defaultSessionFreshness }
        let lo = sessionFreshnessRange.lowerBound
        let hi = sessionFreshnessRange.upperBound
        return min(max(seconds, lo), hi)
    }
```

In `AgentHeuristicEngine.swift`, change:

```swift
    public init(sessionFreshness: TimeInterval = 45, claudeCodexCPUBusyThreshold: Double = 5) {
```

to:

```swift
    public init(sessionFreshness: TimeInterval = 900, claudeCodexCPUBusyThreshold: Double = 5) {
```

Do not change `evaluate` math. Do not add a popover slider.

- [ ] **Step 4: Run tests to verify they pass**

Run:

```bash
swift test --filter AgentHeuristicEngineTests --filter CorePrefsMathTests
```

Expected: PASS. Existing `testCursorOpenWithoutRecentTranscriptsIsNotBusy` uses `-600` and a **45s** engine helper — still not busy. Existing `testClaudeIdlePromptIsNotBusy` uses `-120` on the **45s** helper — still not busy. Default-config tests above cover the product window.

- [ ] **Step 5: Commit**

```bash
git add Sources/AgrypnosCore/Session/UserPreferences.swift Sources/AgrypnosCore/Agent/AgentHeuristicEngine.swift Tests/AgrypnosCoreTests/AgentHeuristicEngineTests.swift Tests/AgrypnosCoreTests/CorePrefsMathTests.swift
git commit -m "$(cat <<'EOF'
Hold Agents busy through think pauses in session files.

EOF
)"
```

---

### Task 2: Classify CLI agents, not chat apps; accept node wrappers

**Files:**
- Modify: `Sources/AgrypnosCore/Agent/AgentKindClassifier.swift`
- Modify: `Sources/AgrypnosCore/Agent/ProcessRecord.swift` (comment only: parser already takes the rest of the line)
- Modify: `Apps/Agrypnos/Sources/Agent/AgentProbeService.swift`
- Test: `Tests/AgrypnosCoreTests/AgentKindClassifierTests.swift`
- Test: `Tests/AgrypnosCoreTests/ProcessTableParserTests.swift`
- Test: `Tests/AgrypnosCoreTests/AgentHeuristicEngineTests.swift`

**Interfaces:**
- Consumes: `ProcessRecord.name` as the `ps` command field (now full `args=`).
- Produces: `AgentKindClassifier.classify(processName:)` returns `.claudeCode` for CLI / node wrappers, `nil` for Claude.app helpers, `.cursor` for Cursor.app / `cursor-agent`, `.codex` for Codex CLI. Bare `node` stays `nil`.

- [ ] **Step 1: Write the failing tests**

Replace `testClaudeAndCodexNames` usage of GUI `Claude` and add these tests to `AgentKindClassifierTests.swift`:

```swift
    func testClaudeCodeCLIClassifiesAndDesktopAppDoesNot() {
        XCTAssertEqual(AgentKindClassifier.classify(processName: "claude"), .claudeCode)
        XCTAssertEqual(AgentKindClassifier.classify(processName: "/opt/homebrew/bin/claude"), .claudeCode)
        XCTAssertEqual(
            AgentKindClassifier.classify(
                processName: "node /usr/local/lib/node_modules/@anthropic-ai/claude-code/cli.js"
            ),
            .claudeCode
        )
        XCTAssertNil(AgentKindClassifier.classify(processName: "/Applications/Claude.app/Contents/MacOS/Claude"))
        XCTAssertNil(AgentKindClassifier.classify(processName: "Claude Helper"))
        XCTAssertNil(AgentKindClassifier.classify(processName: "Claude Helper (Renderer)"))
    }

    func testCodexCLIAndNodeWrapper() {
        XCTAssertEqual(AgentKindClassifier.classify(processName: "codex"), .codex)
        XCTAssertEqual(AgentKindClassifier.classify(processName: "codex-exec"), .codex)
        XCTAssertEqual(
            AgentKindClassifier.classify(processName: "node /Users/ada/.npm/_npx/codex/bin/codex"),
            .codex
        )
    }

    func testBareNodeStillIgnored() {
        XCTAssertNil(AgentKindClassifier.classify(processName: "node"))
        XCTAssertNil(AgentKindClassifier.classify(processName: "/usr/local/bin/node"))
    }
```

Replace `testClaudeAndCodexNames` with:

```swift
    func testClaudeAndCodexNames() {
        XCTAssertEqual(AgentKindClassifier.classify(processName: "claude"), .claudeCode)
        XCTAssertEqual(AgentKindClassifier.classify(processName: "codex"), .codex)
        XCTAssertEqual(AgentKindClassifier.classify(processName: "codex-exec"), .codex)
    }
```

Do not classify the GUI token `Claude` as Claude Code. `basename` uses the first path token, so `Claude Helper` would look like `claude` without the `claude helper` guard in `isClaudeDesktop`.

Add to `ProcessTableParserTests.swift`:

```swift
    func testParsesArgsLineWithNodeWrapper() {
        let rows = ProcessTableParser.parse(
            stdout: "  4421  6.1 node /usr/local/lib/node_modules/@anthropic-ai/claude-code/cli.js --resume\n"
        )
        XCTAssertEqual(rows.count, 1)
        XCTAssertEqual(rows[0].pid, 4421)
        XCTAssertEqual(rows[0].cpuPercent, 6.1, accuracy: 0.01)
        XCTAssertEqual(AgentKindClassifier.classify(processName: rows[0].name), .claudeCode)
    }
```

Add to `AgentHeuristicEngineTests.swift` using the 45s helper (process match is the point):

```swift
    func testClaudeCodeNodeWrapperWithFreshJSONLIsBusy() {
        let snap = engine.evaluate(
            processes: [
                ProcessRecord(
                    pid: 9,
                    cpuPercent: 0.2,
                    name: "node /usr/local/lib/node_modules/@anthropic-ai/claude-code/cli.js"
                )
            ],
            sessionWrites: [
                SessionFileSignal(
                    url: URL(fileURLWithPath: "/Users/a/.claude/projects/p/s.jsonl"),
                    modified: now.addingTimeInterval(-8),
                    kind: .claudeCode
                )
            ],
            now: now
        )
        XCTAssertTrue(snap.report(.claudeCode)?.isBusy ?? false)
    }

    func testClaudeDesktopAppIsNotClaudeCodeBusy() {
        let snap = engine.evaluate(
            processes: [
                ProcessRecord(
                    pid: 2,
                    cpuPercent: 40,
                    name: "/Applications/Claude.app/Contents/MacOS/Claude"
                )
            ],
            sessionWrites: [
                SessionFileSignal(
                    url: URL(fileURLWithPath: "/Users/a/.claude/projects/p/s.jsonl"),
                    modified: now.addingTimeInterval(-1),
                    kind: .claudeCode
                )
            ],
            now: now
        )
        XCTAssertEqual(snap.report(.claudeCode)?.processRunning, false)
        XCTAssertFalse(snap.report(.claudeCode)?.isBusy ?? true)
    }
```

- [ ] **Step 2: Run tests to verify they fail**

Run:

```bash
swift test --filter AgentKindClassifierTests --filter ProcessTableParserTests.testParsesArgsLineWithNodeWrapper --filter AgentHeuristicEngineTests.testClaudeCodeNodeWrapperWithFreshJSONLIsBusy --filter AgentHeuristicEngineTests.testClaudeDesktopAppIsNotClaudeCodeBusy
```

Expected: FAIL — `Claude.app` currently classifies as `.claudeCode`; `node …claude-code…` currently returns nil.

- [ ] **Step 3: Write minimal implementation**

Replace `AgentKindClassifier.swift` with:

```swift
public enum AgentKindClassifier: Sendable {
    public static func classify(processName: String) -> AgentKind? {
        let lowered = processName.lowercased()
        if isClaudeDesktop(lowered) { return nil }

        let n = basename(processName)
        if n == "cursor-agent" || n.hasPrefix("cursor-agent") { return .cursor }
        if n == "cursor" || n.hasPrefix("cursor") { return .cursor }

        if isClaudeCodeCLI(basename: n, loweredCommand: lowered) { return .claudeCode }
        if n == "codex" || n.hasPrefix("codex") { return .codex }
        if isCodexNodeWrapper(basename: n, loweredCommand: lowered) { return .codex }
        return nil
    }

    static func basename(_ processName: String) -> String {
        let trimmed = processName.trimmingCharacters(in: .whitespaces)
        let first = trimmed.split(whereSeparator: { $0 == " " || $0 == "\t" }).first.map(String.init) ?? trimmed
        let slash = first.lastIndex(of: "/")
        let name = slash.map { String(first[$0...].dropFirst()) } ?? first
        return name.lowercased()
    }

    public static func cpuCountsTowardBusy(processName: String) -> Bool {
        switch classify(processName: processName) {
        case .claudeCode, .codex:
            return true
        case .cursor, .none:
            return false
        }
    }

    static func isClaudeDesktop(_ lowered: String) -> Bool {
        if lowered.contains("claude helper") { return true }
        if lowered.contains(".app/") && lowered.contains("claude") { return true }
        return false
    }

    static func isClaudeCodeCLI(basename n: String, loweredCommand: String) -> Bool {
        if loweredCommand.contains("claude helper") { return false }
        if n == "claude" { return true }
        if n.hasPrefix("claude") { return true }
        if n == "node" || n == "nodejs" {
            return loweredCommand.contains("@anthropic-ai/claude")
                || loweredCommand.contains("claude-code")
        }
        return false
    }

    static func isCodexNodeWrapper(basename n: String, loweredCommand: String) -> Bool {
        guard n == "node" || n == "nodejs" else { return false }
        if loweredCommand.contains("codex") { return true }
        return false
    }
}
```

`isClaudeCodeCLI` for `n.hasPrefix("claude")` must **not** run after desktop exclusion. Desktop returns nil first. `claude-code` as a binary name still matches `hasPrefix("claude")`.

In `ProcessRecord.swift` change the parser doc comment to:

```swift
    /// Parses `ps -axo pid= -o pcpu= -o args=` (pid, cpu, rest is command). Never log `name`.
```

In `AgentProbeService.swift` `ProcessListReader.records()`:

```swift
        let stdout = ProcessRunner.run("/bin/ps", ["-axo", "pid=", "-o", "pcpu=", "-o", "args="]).out
```

Do not print or notify `ProcessRecord.name`.

- [ ] **Step 4: Run tests to verify they pass**

Run:

```bash
swift test --filter AgentKindClassifierTests --filter ProcessTableParserTests --filter AgentHeuristicEngineTests
```

Expected: PASS. `testClassifiesBasenameOfPathAndTruncatedComm` still classifies Cursor.app paths as Cursor.

- [ ] **Step 5: Commit**

```bash
git add Sources/AgrypnosCore/Agent/AgentKindClassifier.swift Sources/AgrypnosCore/Agent/ProcessRecord.swift Apps/Agrypnos/Sources/Agent/AgentProbeService.swift Tests/AgrypnosCoreTests/AgentKindClassifierTests.swift Tests/AgrypnosCoreTests/ProcessTableParserTests.swift Tests/AgrypnosCoreTests/AgentHeuristicEngineTests.swift
git commit -m "$(cat <<'EOF'
Match Claude Code and Codex CLIs without treating the chat app as busy.

EOF
)"
```

---

Tasks 3–5 continue in [2026-09-14-agents-watch-reliability-tasks-3-5.md](./2026-09-14-agents-watch-reliability-tasks-3-5.md).
