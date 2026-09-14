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

### Task 3: Walk session subtrees, not whole project dumps

**Files:**
- Modify: `Sources/AgrypnosCore/Agent/SessionFileLayout.swift`
- Modify: `Apps/Agrypnos/Sources/Agent/AgentProbeService.swift`
- Test: `Tests/AgrypnosCoreTests/SessionFileLayoutTests.swift`

**Interfaces:**
- Consumes: existing `roots(home:env:)` plus new helpers below.
- Produces:
  - `SessionFileLayout.cursorSubtreeNames == ["agent-transcripts", "terminals"]`
  - `SessionFileLayout.shouldSkipDirectory(_:)`
  - `SessionFileLayout.cursorWalkRoots(projectsRoot:projectNames:)` → per-project subtree URLs
  - `isRelevantFile` true for `…/terminals/*.txt`

- [ ] **Step 1: Write the failing tests**

Append to `SessionFileLayoutTests.swift`:

```swift
    func testCursorTerminalsAreRelevantAndNoiseIsNot() {
        let terminal = URL(fileURLWithPath: "/Users/ada/.cursor/projects/foo/terminals/1.txt")
        let modules = URL(fileURLWithPath: "/Users/ada/.cursor/projects/foo/node_modules/pkg/readme.md")
        XCTAssertTrue(SessionFileLayout.isRelevantFile(terminal, kind: .cursor))
        XCTAssertFalse(SessionFileLayout.isRelevantFile(modules, kind: .cursor))
        XCTAssertTrue(SessionFileLayout.shouldSkipDirectory("node_modules"))
        XCTAssertTrue(SessionFileLayout.shouldSkipDirectory(".git"))
        XCTAssertFalse(SessionFileLayout.shouldSkipDirectory("agent-transcripts"))
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
```

- [ ] **Step 2: Run tests to verify they fail**

Run:

```bash
swift test --filter SessionFileLayoutTests.testCursorTerminalsAreRelevantAndNoiseIsNot --filter SessionFileLayoutTests.testCursorWalkRootsAreTranscriptsAndTerminalsNotWholeProject
```

Expected: FAIL — `isRelevantFile` does not treat `/terminals/` as in-tree; helpers are missing.

- [ ] **Step 3: Write minimal implementation**

Add to `SessionFileLayout.swift`:

```swift
    public static let cursorSubtreeNames = ["agent-transcripts", "terminals"]

    public static func shouldSkipDirectory(_ name: String) -> Bool {
        let n = name.lowercased()
        if n == "node_modules" || n == ".git" { return true }
        if n.hasPrefix(".") && n != ".cursor" { return true }
        return false
    }

    public static func cursorWalkRoots(projectsRoot: URL, projectNames: [String]) -> [URL] {
        projectNames.flatMap { name in
            cursorSubtreeNames.map { projectsRoot.appendingPathComponent(name).appendingPathComponent($0) }
        }
    }
```

In `isRelevantFile` for `.cursor`, extend `inAgentTree`:

```swift
            let inAgentTree =
                path.contains("agent-transcripts")
                || path.contains("/chats/")
                || path.contains("acp-sessions")
                || path.contains("/terminals/")
```

Replace `SessionFileWalker.signals` in `AgentProbeService.swift` so Cursor **projects** are not walked as one 12k-file dump. Keep `chats` and `acp-sessions` roots from `SessionFileLayout.roots` as-is. For the projects root only, list immediate children and walk `cursorWalkRoots`:

```swift
    static func signals(home: URL, env: [String: String]) -> [SessionFileSignal] {
        var collected: [SessionFileSignal] = []
        let roots = SessionFileLayout.roots(home: home, env: env)
        for (kind, urls) in roots {
            for root in urls {
                if kind == .cursor, root.lastPathComponent == "projects" {
                    let names = projectDirectoryNames(in: root)
                    for sub in SessionFileLayout.cursorWalkRoots(projectsRoot: root, projectNames: names) {
                        collected.append(contentsOf: walk(root: sub, kind: kind))
                    }
                } else {
                    collected.append(contentsOf: walk(root: root, kind: kind))
                }
            }
        }
        return collected
    }

    static func projectDirectoryNames(in root: URL) -> [String] {
        let fm = FileManager.default
        guard let items = try? fm.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }
        return items.compactMap { url in
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue else { return nil }
            let name = url.lastPathComponent
            if SessionFileLayout.shouldSkipDirectory(name) { return nil }
            return name
        }.sorted()
    }
```

In `walk`, skip noise directories (still keep the 4000 cap as a backstop):

```swift
            if enumerator.level > 6 { enumerator.skipDescendants(); continue }
            if SessionFileLayout.shouldSkipDirectory(url.lastPathComponent) {
                enumerator.skipDescendants()
                continue
            }
```

- [ ] **Step 4: Run tests to verify they pass**

Run:

```bash
swift test --filter SessionFileLayoutTests
```

Expected: PASS. Existing default-root tests still include `~/.cursor/projects` as a **root**; walker no longer enumerates that tree wholesale.

- [ ] **Step 5: Commit**

```bash
git add Sources/AgrypnosCore/Agent/SessionFileLayout.swift Apps/Agrypnos/Sources/Agent/AgentProbeService.swift Tests/AgrypnosCoreTests/SessionFileLayoutTests.swift
git commit -m "$(cat <<'EOF'
Probe Cursor transcripts and terminals without walking whole project trees.

EOF
)"
```

---

### Task 4: Re-assert SleepDisabled while the watch is armed

**Files:**
- Modify: `Sources/AgrypnosCore/Session/WatchTypes.swift`
- Modify: `Sources/AgrypnosCore/Session/WatchEngine.swift`
- Modify: `Apps/Agrypnos/Sources/WatchRuntime.swift`
- Modify: `Apps/Agrypnos/Sources/Power/PowerHygieneCoordinator.swift`
- Test: `Tests/AgrypnosCoreTests/WatchEngineTests.swift`
- Test: `Tests/AgrypnosCoreTests/WatchLidHygieneTests.swift`

**Interfaces:**
- Consumes: `WatchEngine.tick(now:safety:agents:)` existing tests. New parameter `kernelSleepDisabled: Bool = true` so old tests stay valid.
- Produces: `WatchCommand.assertSleepDisabled`. If engaged and `kernelSleepDisabled == false`, tick returns `[.assertSleepDisabled]` (and does not disengage). First `lidDidClose` while engaged starts with `.assertSleepDisabled` then hygiene. Launch-at-login leftover path unchanged (`reconcileKernel(preferClearLeftover: true)` still tries to clear, then adopt).

- [ ] **Step 1: Write the failing tests**

Add to `WatchEngineTests.swift`:

```swift
    func testDroppedKernelWhileEngagedReassertsAndStaysOn() {
        var engine = WatchEngine(preferences: .default)
        _ = engine.userSetEngaged(true, now: t0, lidClosed: false)
        let commands = engine.tick(
            now: t0.addingTimeInterval(5),
            safety: .acPower,
            agents: .idle,
            kernelSleepDisabled: false
        )
        XCTAssertEqual(commands, [.assertSleepDisabled])
        XCTAssertTrue(engine.engaged)
    }

    func testAgentsStillSettleWhenKernelIsHeld() {
        var prefs = UserPreferences.default
        prefs.duration = .untilAgentsSettle
        var engine = WatchEngine(preferences: prefs)
        _ = engine.userSetEngaged(true, now: t0)
        XCTAssertTrue(
            engine.tick(
                now: t0,
                safety: .acPower,
                agents: AgentSnapshot(reports: [
                    AgentReport(
                        kind: .claudeCode,
                        processRunning: true,
                        cpuBusy: true,
                        recentSessionWrite: true,
                        isBusy: true
                    )
                ]),
                kernelSleepDisabled: true
            ).isEmpty
        )
        XCTAssertEqual(
            engine.tick(
                now: t0.addingTimeInterval(90),
                safety: .acPower,
                agents: .idle,
                kernelSleepDisabled: true
            ),
            [.disengage(.agentsSettled)]
        )
    }
```

`testAgentsStillSettleWhenKernelIsHeld` should pass once the default parameter exists (same as today’s settle test). Write it to lock “reassert does not skip settle when kernel is on.”

Add / update lid tests in `WatchLidHygieneTests.swift`:

```swift
    func testLidCloseReassertsSleepDisabledThenHygiene() {
        var engine = WatchEngine(preferences: .default)
        _ = engine.userSetEngaged(true, now: t0, lidClosed: false)
        XCTAssertEqual(
            engine.lidDidClose(now: t0.addingTimeInterval(1)),
            [.assertSleepDisabled, .applyBrightnessFloor, .requestKeyboardBacklightOff]
        )
        XCTAssertFalse(engine.lidDidClose(now: t0.addingTimeInterval(2)).contains(.requestSleep))
    }
```

In `WatchEngineTests.testLidCloseFloorsBrightnessAndKillsKeyboardWithoutDisplaySleep` change the expected commands to:

```swift
        XCTAssertEqual(
            cmds,
            [.assertSleepDisabled, .applyBrightnessFloor, .requestKeyboardBacklightOff]
        )
        XCTAssertFalse(cmds.contains(.requestSleep))
```

In `WatchLidHygieneTests.testArmWithLidAlreadyClosedAppliesFloorAndKeyboard`:

```swift
        XCTAssertEqual(
            commands,
            [.engage, .assertSleepDisabled, .applyBrightnessFloor, .requestKeyboardBacklightOff]
        )
```

In `WatchLidHygieneTests.testSecondLidCloseIsNoOp` first close:

```swift
        XCTAssertEqual(
            engine.lidDidClose(now: t0.addingTimeInterval(1)),
            [.assertSleepDisabled, .applyBrightnessFloor, .requestKeyboardBacklightOff]
        )
```

In `WatchLidHygieneTests.testLidHygieneHonorsPreferenceToggles`:

```swift
        XCTAssertEqual(
            engine.lidDidClose(now: t0.addingTimeInterval(1)),
            [.assertSleepDisabled]
        )
        XCTAssertTrue(engine.lidDidOpen(now: t0.addingTimeInterval(2)).isEmpty)
```

In `WatchLidHygieneTests.testAdoptLeftoverWithLidClosedAppliesFloorAndKeyboard`, after `engage` with lid already closed the command list becomes:

```swift
        XCTAssertEqual(commands.first, .engage)
        XCTAssertTrue(commands.contains(.assertSleepDisabled))
        XCTAssertTrue(commands.contains(.applyBrightnessFloor))
        XCTAssertTrue(commands.contains(.requestKeyboardBacklightOff))
```

`testAdoptLeftoverWhileEngagedWithLidClosedReappliesFloorAndKeys` still returns only hygiene (kernel is already on; leftover adopt is not the drop-while-armed path). Leave that expected array as `[.applyBrightnessFloor, .requestKeyboardBacklightOff]`.

Order everywhere: **assert kernel, then hygiene.** `requestSleep` stays absent on lid close.

- [ ] **Step 2: Run tests to verify they fail**

Run:

```bash
swift test --filter WatchEngineTests.testDroppedKernelWhileEngagedReassertsAndStaysOn --filter WatchLidHygieneTests.testLidCloseReassertsSleepDisabledThenHygiene
```

Expected: FAIL — `assertSleepDisabled` does not exist; tick ignores kernel; lid close has no kernel command.

- [ ] **Step 3: Write minimal implementation**

`WatchTypes.swift` — add:

```swift
    case assertSleepDisabled
```

to `WatchCommand` (after `.engage` is fine).

`WatchEngine.swift` — change `tick`:

```swift
    public mutating func tick(
        now: Date,
        safety: SafetyInputs,
        agents: AgentSnapshot,
        kernelSleepDisabled: Bool = true
    ) -> [WatchCommand] {
        guard engaged else { return [] }
        if let reason = AutoOffEvaluator.reason(
            engaged: true,
            timerEnd: timerEnd,
            safety: safety,
            batteryFloorPercent: preferences.batteryFloorPercent,
            userForcedThisSession: userForcedThisSession,
            now: now
        ) {
            return disengage(reason)
        }
        if mode == .untilAgentsSettle {
            let activity = settle.observe(busy: agents.anyBusy, now: now)
            if activity == .settled {
                return disengage(.agentsSettled)
            }
        }
        if !kernelSleepDisabled {
            return [.assertSleepDisabled]
        }
        return []
    }
```

Auto-off and agents settle still win over reassert (if we are disengaging, do not re-arm).

`lidDidClose`:

```swift
    public mutating func lidDidClose(now: Date) -> [WatchCommand] {
        lidClosed = true
        _ = now
        guard engaged else { return [] }
        guard !lidHygieneApplied else { return [] }
        lidHygieneApplied = true
        return [.assertSleepDisabled] + lidCloseHygieneCommands()
    }
```

`engage` when `lidClosed`:

```swift
        var commands: [WatchCommand] = [.engage]
        if lidClosed {
            commands.append(.assertSleepDisabled)
            commands.append(contentsOf: lidCloseHygieneCommands())
            lidHygieneApplied = true
        } else {
            lidHygieneApplied = false
        }
```

`PowerHygieneCoordinator.apply` — add:

```swift
            case .assertSleepDisabled:
                break
```

`WatchRuntime.apply`:

```swift
    func apply(_ commands: [WatchCommand]) {
        for command in commands {
            if case .assertSleepDisabled = command {
                _ = armKernel()
            }
        }
        PowerHygieneCoordinator.apply(
            commands,
            preferences: engine.preferences,
            savedBrightness: &savedBrightness,
            savedKeyboard: &savedKeyboard,
            ramp: brightnessRamp
        )
    }
```

`WatchRuntime.poll` — pass kernel into tick:

```swift
        let kernel = SleepDisabledController.read()
        let agents = AgentProbeService.snapshot(now: Date(), freshness: engine.preferences.sessionFreshness)
        let commands = engine.tick(
            now: Date(),
            safety: safety,
            agents: agents,
            kernelSleepDisabled: kernel
        )
```

`WatchRuntime.reconcileKernel` — **delete** the `else if !kernel, engine.engaged { userSetEngaged(false)… }` branch. Kernel-off-while-engaged is now tick’s job. Keep leftover adopt (`kernel && !engaged`). Do not re-arm at launch: `start()` still calls `reconcileKernel(preferClearLeftover: true)` first.

If `armKernel()` fails during `.assertSleepDisabled`, leave the engine engaged; the next poll retries. Do not notify “ended.” If you notify, use the existing grant/failure strings from `armKernel()`, which already do that.

- [ ] **Step 4: Run tests to verify they pass**

Run:

```bash
swift test --filter WatchEngineTests --filter WatchLidHygieneTests
```

Expected: PASS. Lid-closed agents settle still equals `[.disengage(.agentsSettled), .requestSleep]`. Timed lid-closed expiry still requests sleep. No test expects `displaysleepnow`.

- [ ] **Step 5: Commit**

```bash
git add Sources/AgrypnosCore/Session/WatchTypes.swift Sources/AgrypnosCore/Session/WatchEngine.swift Apps/Agrypnos/Sources/WatchRuntime.swift Apps/Agrypnos/Sources/Power/PowerHygieneCoordinator.swift Tests/AgrypnosCoreTests/WatchEngineTests.swift Tests/AgrypnosCoreTests/WatchLidHygieneTests.swift
git commit -m "$(cat <<'EOF'
Re-assert SleepDisabled while the watch is armed.

EOF
)"
```

---

### Task 5: Linux verify, sizes, copy honesty

**Files:**
- Modify only if a test fixture or copy test broke.
- Do not change popover copy to mention freshness (hidden). `AgrypnosCopy.agentsHint` stays: “Stays awake while agents are busy. Allows sleep after they go idle.”

**Interfaces:**
- Consumes: Tasks 1–4.
- Produces: `swift test` green; `Scripts/check-file-sizes.sh` green.

- [ ] **Step 1: Run the full Core suite (no new production code first)**

```bash
swift test
./Scripts/verify-linux.sh
```

Expected: PASS, including file-size cap. If a switch on `WatchCommand` in tests or copy tests is non-exhaustive, add the `.assertSleepDisabled` case as a no-op / not user-facing.

- [ ] **Step 2: Fix any leftover compile failures from the new enum case**

Grep `WatchCommand` / `switch command` and add `.assertSleepDisabled` wherever the compiler says. Do not add UI copy for it.

- [ ] **Step 3: Re-run**

```bash
swift test
./Scripts/verify-linux.sh
```

Expected: `Linux verification passed.`

- [ ] **Step 4: Commit only if Step 2 changed files**

```bash
git add -u
git commit -m "$(cat <<'EOF'
Cover the SleepDisabled re-assert command in remaining switches.

EOF
)"
```

Skip the commit if there is nothing to add.

---

## Self-review (PRD + AGENTS.md)

| Requirement | Task |
|---|---|
| Agents busy → stay; idle after user settle grace → allow sleep | 1 (busy evidence), existing tracker unchanged |
| Cursor + Claude Code + Codex; process + session mtimes | 2, 3 |
| Correctness over coverage; no extra providers | skipped |
| Armed ≠ black screen | unchanged; lid close still no `displaysleepnow` |
| Lid close: floor % + keyboard off | 4 prepends kernel assert, keeps hygiene |
| Lid-closed keep-awake = SleepDisabled | 4 re-assert while engaged |
| IOKit not the lid story | skipped / unchanged |
| Auto-off timer / battery / thermal / LPM+force | unchanged; tick still checks them first |
| `requestSleep` when auto-off with lid closed | kept (`WatchLidHygieneTests`) |
| Launch-at-login never re-arms | `preferClearLeftover: true` kept |
| Sudoers exactly two disablesleep commands | unchanged |
| Copy: no ended while still held | failed reassert does not post agents-ended |
| Menu-bar only, no freshness slider | skipped slider; migrate 45s in prefs instead |
| No file > 600 lines | Task 5 |

Placeholder scan: no TBD/TODO. Types: `assertSleepDisabled` used consistently. `tick` default `kernelSleepDisabled: true` matches existing tests.

## Skipped (ponytail)

- Freshness slider — add when Boss unlocks a visible control; Core already persists a clamped value.
- Parsing transcript bodies / cloud APIs / per-tool include list — add when V2 says so.
- Treating `cursor-agent worker` liveness as busy — that process stays up idle at 0% CPU.
- Clamshell wedge (external display, foreign sleep assertions) — README already refuses that claim until Mac-proved.
- IOKit assertions as lid keep-awake — they do not survive lid close.
- Auto-rearm at login — safety.
- Status-item remaining time / busy glyph while settling — locked / cosmetic.
- Main-thread probe queue — skip until the narrowed walk is still slow.

## Mac prove (human, after implementation)

Arm Agents, lid **open** (screen usable). Close lid: floor + keys, Mac stays up through a several-minute think. Reopen: ramp + keys. When agents are actually done, idle wait then allow sleep. Until that happens, do not claim Mac runtime.
