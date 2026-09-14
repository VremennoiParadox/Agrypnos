# Agents Watch Reliability Implementation Plan (tasks 3–5)

Continues [2026-09-14-agents-watch-reliability.md](./2026-09-14-agents-watch-reliability.md).

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
