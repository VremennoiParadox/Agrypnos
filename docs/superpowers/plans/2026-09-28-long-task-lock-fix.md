# Long-task Observation Continuity Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Prevent false Agents auto-off across unavailable observations or sleep/wake, and establish the trigger of the reported long-task lock before claiming that incident fixed.

**Architecture:** Keep idle decisions in Core and measurement/lifecycle handling in the Mac runtime. Add continuity to the existing settle tracker and explicit validity to agent probe results, then wire the existing sleep/wake handlers to invalidate observations. Do not suppress macOS locking or replace the selected-provider heuristics.

**Tech Stack:** Swift 5.9+, SwiftPM/XCTest, macOS 14+, AppKit/NSWorkspace, OSLog, existing pmset adapters.

**Spec:** `docs/superpowers/specs/2026-09-28-long-task-lock-investigation.md` (read confidence limits as well as requirements).

## Global Constraints

- “No file over 600 lines.” Prefer focused existing files; no framework or dependency additions.
- “Idle wait” is “2 minutes – 15 minutes”; default “2 minutes” (120s).
- Session freshness remains 45s by default; do not add a hidden long settle window.
- Providers: Cursor, Claude Code, Codex, OpenCode. Busy only from selected tools; ≥1 selected. Cursor/OpenCode stay out of CPU-busy.
- “Count terminal sessions as busy.” “Default OFF.” Nested `/subagents/*.jsonl` is not this toggle.
- “Armed ≠ black screen.” Stable confirmed lid before hygiene; Power A/B exclusive; nil capture skips writes.
- Safety and manual/inbound off continue to work during measurement failure. No auto-rearm after launch or wake.
- Outbound remains one idle-after-wait POST per real arm, after busy was seen; never task completion detection.
- No lock-setting changes, persistent display prevention, synthetic input, telemetry, transcript contents, secret logging, or new network calls.
- Model exception applies to this investigation; an executor must check its own current authorization.

## Review Focus

1. A locked session with healthy background activity continues watching and can eventually settle normally; lock itself is neither busy nor a permanent veto (Task 4).
2. An hour asleep, a backward/forward clock discontinuity, or a stale probe cannot complete an idle wait on the first resumed sample (Tasks 1–3).
3. Failed process/file reads or an exhausted walk budget produce unknown negative evidence, not successful idle (Task 2).
4. A probe arriving after tool selection, terminal preference, rearm, or wake changes cannot influence the new watch (Tasks 2–3).
5. Battery/thermal/manual off while measurements are unavailable still releases the hold through the existing sleep gate; outbound remains once-only (Tasks 1–3).

---

## File map

| File | Responsibility |
|---|---|
| `Sources/AgrypnosCore/Agent/AgentSettleTracker.swift` | Existing tracker plus continuous-observation state |
| `Sources/AgrypnosCore/Session/WatchEngine.swift` | Expose interruption without disarming; existing safety/idle decisions |
| `Sources/AgrypnosCore/Agent/AgentProbeObservation.swift` (new) | Small value describing a probe's snapshot, measurement time, and completeness |
| `Sources/AgrypnosCore/Agent/AgentSnapshotCache.swift` | Cache only trustworthy, timely snapshots |
| `Apps/Agrypnos/Sources/Agent/AgentProbeService.swift` | Report collection failures/budget exhaustion, not just arrays |
| `Apps/Agrypnos/Sources/WatchRuntime+Poll.swift` | Validate probe results before accepting idle evidence |
| `Apps/Agrypnos/Sources/WatchRuntime+Kernel.swift` | Existing OS lifecycle observer registration plus diagnostic transitions |
| `Apps/Agrypnos/Sources/Notif/WatchRuntime+TelegramInbound.swift` | Existing shared sleep/wake callbacks; keep inbound drain behavior |
| Existing Core tests + new `AgentObservationContinuityTests.swift` / `AgentProbeObservationTests.swift` | Deterministic regressions using supplied dates and snapshots |
| `Scripts/check-agent-probe-macos.swift` (new) | Minimal Mac adapter check without launching the app or running pmset |

### Task 1: Require continuous observations for settling

**Files:** Modify `AgentSettleTracker.swift` and `WatchEngine.swift`; create `Tests/AgrypnosCoreTests/AgentObservationContinuityTests.swift`. Adjust healthy-cadence setups in `AgentSettleTrackerTests.swift`, `WatchIdlePostHoldTests.swift`, `WatchEngineTests.swift`, `StickyWatchTests.swift`, `NotifIdlePostTests.swift`, `LastWatchEndTests.swift`, and `WatchDisarmRollbackTests.swift` where they currently jump directly from busy to the grace deadline.

**Interfaces:** Keep `observe(busy: Bool, now: Date) -> Activity` and `activity(busy: Bool, now: Date) -> Activity`. Add `public mutating func interruptObservations()` to the tracker, and `public mutating func interruptAgentObservations()` to WatchEngine. Add `AgentSettleTracker.maximumObservationGap: TimeInterval = 15` (three normal 5s polling intervals), `lastObservedAt: Date?`, and a separate `settleBaselineAt: Date?`; never overwrite the factual `lastBusyAt` on interruption.

- [x] **Step 1: Write failing continuity tests.** `testFirstIdleAfterOneHourGapDoesNotSettle`: arm Agents/Notif, observe busy at t=0, observe idle at t=3600; assert engaged, no POST/disengage/sleep. `testInterruptedWaitRequiresFullGraceAgain`: busy at 0, idle every 5s through 60, interrupt, first idle at 3600; idle every 5s through 3715 stays armed, at 3720 emits one Agents disengage/POST. Assert `sawBusy` survives and `lastBusyAt` remains t=0. `testClockDiscontinuityRestartsWait`: negative or >15s observation delta starts a new quiet baseline and cannot settle immediately. `testNeverBusyInterruptionDoesNotInventBusy`: still quiet, no POST. `testSafetyStillWinsAfterGap`: at resumed tick serious thermal or discharging battery below threshold still disengages with the real safety reason and no idle POST.
- [x] **Step 2: Run** `swift test --filter AgentObservationContinuityTests`; expect the gap/interruption regressions to fail on current Core.
- [x] **Step 3: Implement the interfaces above.** Busy records the real busy time and quiet baseline. A negative sample following a discontinuity or explicit interruption starts a new quiet baseline at that sample; ordinary ≤15s cadence preserves current grace timing. `activity` is read-only and cannot report settled from an interrupted/stale observation chain. `reset()` clears continuity along with busy history. Pending probe ticks using `observeAgents: false` remain skips: do not interrupt on every pending poll, which would starve settling. Explicit invalid results use the interruption API.
- [x] **Step 4: Update existing time-jump fixtures, then run** `swift test`. Existing tests often jump 90–120s in one tick; under the new continuity rule those represent observation gaps. For tests whose purpose is healthy settling, feed idle every 5s before the same deadline; keep their original final assertions. Tiny per-file helpers are sufficient. Change `WatchIdlePostHoldTests.testTickCanSkipSettleWhenAgentSnapshotIsNotReady` to require a full fresh wait after its long gap, and retain the new gap tests separately. Any further Agents-settle fixtures exposed by the full suite need the same timing correction, not a weakened continuity rule. Expect PASS; preserve healthy-cadence 120s settle, How long staying Agents, once-only POST, last-end facts and kernel reassertion.
- [x] **Step 5: Commit** only these files with `fix: require continuous agent observations before settling`.

### Task 2: Keep unavailable and stale probes out of idle decisions

**Files:** Create `Sources/AgrypnosCore/Agent/AgentProbeObservation.swift`, `Tests/AgrypnosCoreTests/AgentProbeObservationTests.swift`, and `Scripts/check-agent-probe-macos.swift`; modify `AgentProbeService.swift`, `AgentSnapshotCache.swift`, and `WatchRuntime+Poll.swift`.

**Interfaces:** `AgentProbeObservation: Equatable, Sendable` has `snapshot: AgentSnapshot`, `startedAt: Date`, `completedAt: Date`, and `complete: Bool`. Provide `settleBusy(included: Set<AgentKind>, now: Date) -> Bool?`: true/false for a timely usable observation; nil for unknown. Change `AgentProbeService.snapshot(now:freshness:countTerminalSessions:included:)` to return this value. Preserve defaults and the existing `AgentHeuristicEngine.evaluate` formulas. Mac collection helpers propagate completion alongside results rather than silently dropping failures.

- [x] **Step 1: Write failing validity tests.** `testCompleteIdleIsFalse`: complete empty snapshot, started 0/completed 1/now 1 → false. `testIncompleteIdleIsUnknown`: same snapshot incomplete → nil. `testPartialSelectedBusyStillProtectsWatch`: incomplete snapshot with selected Cursor busy → true. `testUnselectedBusyDoesNotHideIncompleteSelectedProbe`: only unselected Codex busy and incomplete → nil. `testDelayedProbeIsUnknown`: started 0/completed 20/now 20 → nil even if cached “now”; negative time ordering → nil. A result older than `AgentSnapshotCache.reuseWindow` (5s) is unknown. In the Mac check, a successful empty process table/missing session root is valid absence; nonzero `ps`, unreadable existing root/file metadata, or cap exhaustion without positive busy evidence is incomplete.
- [x] **Step 2: Run** `swift test --filter AgentProbeObservationTests`; expect failure because the new value is absent. Write the adapter check before changing collection, with injected collection results and no real power/network operations; its error-versus-empty assertions must fail on the current collection behavior.
- [x] **Step 3: Implement validity and collection.** Timely means collection duration is 0…15s and completion age is 0…<5s. Preserve trustworthy positive busy evidence from partial collection; incomplete negative results interrupt settling via Task 1 and never enter the cache. Missing optional roots are normal absence; permission/I/O failures and budget exhaustion are not. Catch errors specifically; do not solve this by making every missing path unknown. Record actual start/completion times; do not turn an old snapshot fresh by stamping it at callback delivery. Have the Mac script compile against the real adapters with small injectable collector closures, not a duplicate walker.
- [x] **Step 4: Run** `swift test --filter 'AgentProbeObservationTests|AgentSnapshotCacheTests|AgentIncludeTests|TerminalSessionBusyTests|SessionWalkBudgetTests'`; expect PASS. Compile/run the Mac check with Core sources plus `ProcessRunner.swift` and `AgentProbeService.swift` in a temporary directory; expect nonzero/permission/cap/stale cases to remain unknown and the successful empty case to be idle. A real fresh subagent file must still count with terminals OFF.
- [x] **Step 5: Commit** the listed files with `fix: distinguish unavailable agent probes from idle`.

### Task 3: Invalidate observations across actual sleep/wake

**Files:** Modify `WatchRuntime+TelegramInbound.swift` and, only as needed for shared lifecycle wiring, `WatchRuntime+Kernel.swift`; extend `AgentObservationContinuityTests.swift` only for any additional portable state cases. The Task 2 Mac adapter script tests collection, not runtime lifecycle wiring.

**Interfaces:** Reuse `WatchRuntime.invalidateAgentProbe()` and Task 1's `WatchEngine.interruptAgentObservations()`. Keep `noteMacWillSleep()` / `noteMacDidWake()` signatures and existing inbound restart/drain methods.

- [ ] **Step 1: Record the native lifecycle baseline (optical pending).** This repo has no native WatchRuntime test target, so use an explicit Mac optical check instead of claiming the Core-only harness exercises callbacks. In a controlled test with inbound/outbound OFF, observe busy, manually sleep/wake with the user's participation, then inspect probe acceptance and settle state in the debugger. Current callbacks do not invalidate the generation/cache or interrupt the tracker. Keep the late-result rejection and first-resumed-idle check for post-change verification; do not add a whole native test target for two callbacks.
- [x] **Step 2: Verify the portable prerequisites.** Run `swift test --filter 'AgentObservationContinuityTests|AgentSnapshotCacheTests|TelegramInboundWakeMissTests'`; expect PASS after Tasks 1–2. Their success proves interruption/cache/drain logic, not that the Mac callbacks invoke it. If needed add a repeat-interruption portable case: busy history survives two interruptions, no POST until a full new grace. Do not manufacture a failing Core test for already tested logic.
- [x] **Step 3: Wire both callbacks.** Invalidate probes and interrupt the tracker at sleep and wake independently of whether Telegram or Discord inbound is enabled. Wake requests a fresh poll through the existing runtime without rearming. Preserve safety polling, current lid gates, and all inbound wake-miss behavior. Keep lock-only transitions observational; they must not clear/rearm the watch or block healthy settling.
- [ ] **Step 4: Run (automated checks passed; optical pending)** `swift test --filter 'AgentObservationContinuityTests|TelegramInboundWakeMissTests|WatchUserOffSleepTests|WatchDisarmRollbackTests|NotifIdlePostTests|NotifIdleOutboundCoordinatorTests'`, the collection-only Mac check, and `xcodebuild -project Apps/Agrypnos/Agrypnos.xcodeproj -scheme Agrypnos -configuration Debug -derivedDataPath /tmp/agrypnos-lock-plan-build CODE_SIGN_IDENTITY=- build`; expect PASS / BUILD SUCCEEDED. Repeat the native check from Step 1: actual callbacks clear the cache, bump the generation, reject a late result, preserve real busy history, require a new 120s wait, and leave an off watch off. Confirm with a repeated sleep while settling too; mark native behavior unverified if optical/debugger checking is unavailable.
- [x] **Step 5: Commit** with `fix: restart agent observation wait after sleep and wake`.

### Task 4: Establish the incident trigger and verify on the Mac

**Files:** Add minimal transition diagnostics to `WatchRuntime+Poll.swift`, `WatchRuntime+Kernel.swift`, and `AgentProbeService.swift`; update the investigation spec with matching-run evidence. Add `README.md` clarification only if the tested result demonstrates a user-facing limitation missing there.

**Interfaces:** Native `Logger(subsystem: "app.agrypnos.Agrypnos", category: "watch")`. Log sampled timestamp/duration, completion, selected provider reports (process/recent-write/CPU/busy booleans), settle elapsed, lifecycle transition, disengage reason, kernel readback, POST decision and sleep command outcome. No secret values, complete process args, URLs, file paths, transcript text, or task content. Log transitions/failures at debug level; do not emit every unchanged five-second sample. Collect lock/unlock from the Mac's loginwindow diagnostics alongside Agrypnos's logs; add no product lock-state observer.

- [ ] **Step 1: Add and inspect diagnostics.** Run `log stream --level debug --predicate 'subsystem == "app.agrypnos.Agrypnos" AND category == "watch"'`. Confirm visible transition fields and absence of private content; no additional external messages beyond the existing user's outbound opt-in. Capture loginwindow lock/unlock messages separately with `log stream --level debug --predicate 'process == "loginwindow" AND (eventMessage CONTAINS "setScreenIsLocked" OR eventMessage CONTAINS "sendNotificationOf kScreenIsUnlocked")'`. These OS message names are diagnostic evidence, not an API contract; if absent on the tested OS, use optical timestamps for lock/unlock and retain pmset's sleep/wake records. Do not create an authentication or anti-lock controller.
- [ ] **Step 2: Reproduce the actual workload.** Record the tested build, agent/provider, actual settings, power source and lid. First run with the user's original settings. Match lock/unlock, file/process signals, observation gaps, watch end and system sleep from this same run. Preserve the existing baseline app before implementing Tasks 1–3; if a baseline comparison is needed, use a separate diagnostic-only baseline build rather than overwrite or reset the working tree. If feasible, compare the same workload in ∞ mode: it skips Agents auto-off and can distinguish the idle decision from independent locking. Do not change the user's OS security settings.
- [ ] **Step 3: Verify five conditions.** (a) More than one hour of continuously observable work, locked and unlocked: no idle POST/off. (b) Manual sleep/wake or injected unavailable probe: no immediate settle; full new grace afterward. (c) Real signals stop with healthy polling while locked: after grace exactly one POST, watch off, How long still Agents. (d) Low battery/thermal or manual/inbound off during unavailable observations: existing safety and lid-gated sleep behavior. (e) A late pre-wake/rearm/selection probe: ignored. Include Power A and B; locking is not a veto on legitimate closed-lid auto-off.
- [ ] **Step 4: Apply the evidence gate.** If healthy, continuous, complete probes show all allowed signals quiet during unfinished work, this plan has not solved that signal ceiling. Record the measured gap and recommend the existing 2–15m wait or ∞ for that workload. Do not add Cursor GPU CPU, all-process liveness, always-on terminals, long hidden freshness, task parsing, or global anti-lock behavior as a speculative patch. If locking prevents a GUI-dependent task despite a retained hold, record it as a separate supported-workload/design question. A matching reproduction establishes that run's causal order and a likely explanation for September 27; it does not retrospectively prove yesterday's trigger without incident-specific evidence.
- [x] **Step 5: Run final checks.** `swift test`, `bash Scripts/check-file-sizes.sh`, Mac adapter check, and the app build command from Task 3. The file-size script already flags unrelated generated outputs and an older 701-line plan in this checkout; report that baseline and separately verify changed source files stay below 600 lines. Request an independent review focused on false-negative probes, clock/gap handling, post/hold lifecycle and unchanged lid/security behavior. Report Core/build evidence separately from optical checks and any unresolved incident trigger.
- [x] **Step 6: Commit** with `chore: add watch transition diagnostics` (and measured documentation only). Do not publish a release or change the running app without an implementation request.

## Implementation status

The user authorized implementation on September 28. Tasks 1–3 are implemented and automated checks pass. Task 4 diagnostics are implemented, with the matching long-task and sleep/wake optical checks pending. See the spec's implementation-evidence section for confidence limits. Native execution was used with an independent final review (no unresolved findings at `a425fa0`); no new monitoring automation or running-app replacement was performed.
