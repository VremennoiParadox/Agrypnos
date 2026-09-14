# Agents-mode reliability — investigation

Date: 2026-09-14
Status: DONE
Mac lid-close runtime: **not run** (this agent did not arm the watch or close the lid).

Companion plan: `docs/superpowers/plans/2026-09-14-agents-watch-reliability.md`

## Symptoms (as reported)

1. Agents duration (“go to sleep when agent stops”) turns the watch **off too early** while the user still considers agents working.
2. After lid close, the Mac **sometimes does not stay awake** (SleepDisabled / lid-closed keep-awake not holding).

Both can be the same failure: false idle → Core disengages → kernel flag cleared → with the lid already shut, Core also emits `requestSleep` (`pmset sleepnow`).

## Method

Systematic debugging, no shotgun fix. Codegraph over `WatchRuntime`, `WatchEngine`, agent heuristics, settle grace, SleepDisabled. Then file reads, tests, git history, PRD / `AGENTS.md`, `SECURITY.md`, live process + session-mtime evidence on this Mac (mtimes and process names only; no transcript bodies).

No in-flight `.superpowers/sdd/progress.md`. No existing plan in `docs/superpowers/plans/`.

## End-to-end flow (what the code actually does)

1. User picks Agents (`DurationOption.untilAgentsSettle`), arms Keep the watch with the lid **open**.
2. `WatchRuntime.setEngaged(true)` → `armKernel()` (`sudo pmset -a disablesleep 1` + readback) → `WatchEngine.engage` emits `.engage` only (no brightness/keyboard, no `displaysleepnow`).
3. 5s `poll()`: `reconcileKernel` → `pollLid` → sensors → `AgentProbeService.snapshot` → `WatchEngine.tick`.
4. Agents: `AgentSettleTracker.observe(busy: snapshot.anyBusy)`. Quiet until first busy. After busy, idle for **user settle grace** (default 90s) → `disengage(.agentsSettled)`.
5. Lid close (0.25s pulse): `lidDidClose` → brightness floor + keyboard off. **Does not re-assert SleepDisabled.** Relies on the flag from arm time.
6. Auto-off also from timer (not Agents), battery floor while discharging, thermal serious/critical, LPM+discharging unless `userForcedThisSession`.
7. If auto-off while `lidClosed` and reason ≠ `.user`: `.requestSleep` → `pmset sleepnow`.
8. Launch-at-login: `start()` `reconcileKernel(preferClearLeftover: true)` tries to **clear** leftover SleepDisabled; does not re-arm. Do not change that.

`AgrypnosCore` decides busy/settle/disengage. Mac adapters execute `ps`, file walks, `pmset`.

## Root causes

### 1. Hidden 45s “fresh” window declares agents idle during real work (primary premature-off)

`isBusy` for Cursor is **process running AND session mtime ≤ `sessionFreshness`** (default **45s**, not in the popover). Claude Code / Codex add a CPU≥5% OR.

```92:98:Sources/AgrypnosCore/Agent/AgentHeuristicEngine.swift
        switch kind {
        case .cursor:
            isBusy = processRunning && recentSessionWrite
        case .claudeCode, .codex:
            isBusy = processRunning && (cpuBusy || recentSessionWrite)
        }
```

Cursor CPU is **never** a busy signal (`AgentKindClassifier.cpuCountsTowardBusy` returns false for Cursor). The long-lived `cursor-agent` worker on this Mac was at 0% CPU during an active session, so process existence is not a usable busy bit either.

`AgentSettleTracker` then waits the **user** grace (90s) only after `isBusy` has already gone false. Effective timeout after last transcript write ≈ **45s + 90s**.

**Live evidence (this machine, agent actively working, 2026-09-14):** under `~/.cursor/projects/**/agent-transcripts/**/*.jsonl`:

- 0 files younger than 45s
- 0 younger than 90s
- 0 younger than 300s
- 2 younger than 600s
- newest ≈ 5–7 minutes stale while this investigation was running

So the current heuristic would report Cursor **not busy** for this real session, then settle and turn the watch off. Tests **encode** that 10s-old transcripts are busy and 600s-old IDE-open is idle (`AgentHeuristicEngineTests`), and never assert a multi-minute think/tool pause.

Settle grace is user-visible (“Wait after agents go idle”). Session freshness is a hidden constant. The watch goes quiet while the agent is still thinking / waiting on tools / running a cloud worker that does not append jsonl every 45s.

### 2. False idle → lid-closed sleep (same bug, worse with the lid shut)

Once Core believes agents settled:

```135:148:Sources/AgrypnosCore/Session/WatchEngine.swift
        var commands: [WatchCommand] = [.disengage(reason)]
        // Clearing SleepDisabled does not retrigger clamshell sleep.
        if lidClosed, reason != .user {
            commands.append(.requestSleep)
        }
```

`PowerHygieneCoordinator` runs `pmset sleepnow`. `WatchRuntime.poll` disarms SleepDisabled first. User-facing copy: “Agents idle. Watch turned off.”

This matches both reports: premature off, and “closed the lid and it didn’t stay awake.” Introduced as a product fix in `cc632d1` (request sleep on lid-closed auto-off). Correct when idle detection is correct; catastrophic when it is not. **Keep `requestSleep`.** Fix the idle detector.

### 3. SleepDisabled is not re-asserted while armed; kernel drop silently ends the watch

Arm sets the flag once. `lidDidClose` only emits hygiene (`WatchEngine.swift:87-94`). `.engage` is a no-op in `PowerHygieneCoordinator` (kernel work is only in `setEngaged` / `armKernel`).

Every 5s, if readback is off while the engine is still engaged:

```294:297:Apps/Agrypnos/Sources/WatchRuntime.swift
        } else if !kernel, engine.engaged {
            _ = engine.userSetEngaged(false, now: Date(), lidClosed: LidStateReader.isClosed())
            restoreHygiene()
        }
```

That is a **silent `.user` disengage** (return value discarded, no “Agents idle” notification, **no** `requestSleep`). If macOS dropped `SleepDisabled` on clamshell, or `pmset -g` parsed as off (empty output → `SleepDisabledParser` returns false), the watch turns off and the lid-closed Mac may sleep.

PRD line “UI follows the kernel, not hope” is about failed **set**/readback at arm time, not “if the flag falls while the user still wants the watch, give up.” While engaged, re-apply; if re-apply fails, *then* follow the kernel and say so.

No Core test covers kernel-off-while-engaged. Policy lives only in AppKit.

### 4. Probe gaps that make (1) worse on some machines (not the only cause here)

**4000-file walk cap counts every file, filesystem order, then breaks** (`AgentProbeService.swift:38-40`). This machine: `~/.cursor/projects` had **12k+** files; only 63 relevant in the first 4000. Agrypnos transcripts happened to appear in that window today; another project later in directory order would be invisible → false idle. Universal fix: do not walk whole project trees.

**`ps -axo comm=`** (`AgentProbeService.swift:8-10`). Tests explicitly ignore `node` (`AgentKindClassifierTests.testUnrelatedProcessesAreIgnored`). Claude Code / Codex invoked as `node …/claude-code` never set `processRunning`. Then even a fresh jsonl is not busy (`isBusy` requires process AND files/CPU).

**`Claude.app` / `Claude Helper` match Claude Code** because classify lowercases and `hasPrefix("claude")`. Desktop chat is not V1 Claude Code. Full paths like `/Applications/Claude.app/Contents/MacOS/Claude` are live on this Mac. Low CPU + stale `~/.claude` jsonl (days old) → not busy right now; a renderer CPU spike could false-busy forever.

**Cursor `terminals/*.txt` are not relevant files.** Tool-wait often updates terminals, not jsonl. This workspace had no `terminals/` dir (cloud/subagent path); still include them for CLI/local agents.

## What is *not* the root cause

| Hypothesis | Why rejected |
|---|---|
| Settle grace not applied | `WatchEngine.tick` calls `observe`; tests cover 90s and pref grace (`WatchEngineTests`, `CorePrefsMathTests`). |
| Launch-at-login re-arm | `reconcileKernel(preferClearLeftover: true)` tries to clear. Do not “fix” by auto-rearming at login. |
| IOKit assertions should be the lid story | `AGENTS.md`: they do not survive lid close. |
| `displaysleepnow` on toggle | Armed path does not blank the panel. Do not add it. |
| Sudoers too narrow / need `pmset sleep 0` | Grant is two exact `disablesleep` commands (`SECURITY.md`). Re-assert those two. |
| Need every provider / transcript body parse | V1: Cursor, Claude Code, Codex; mtimes only. |
| Clamshell wedge (external display, foreign assertions) | README already refuses to claim that story until Mac-proved. Out of this plan. |
| `requestSleep` itself | Right once idle is right. |

## Design choice (brainstorming, then lock)

**A. Only bump `sessionFreshness` (45 → 15 min).** Smallest. Still misses `node` CLIs, walks 12k files, silent kernel drop.

**B. Canonical Core busy + walk policy + re-assert SleepDisabled while engaged.** One busy definition all callers use; one kernel policy in `WatchEngine.tick` / `lidDidClose`. Recommended.

**C. Parse transcripts, cloud APIs, per-tool include list, `cursor-agent` liveness.** V2 / locked. `cursor-agent worker start` stays up idle at 0% CPU on this Mac.

**Chosen: B.**

Busy evidence stays local and boring: process list (command line, not GUI helpers for Claude) + session mtimes, with a freshness window that covers think/tool pauses. Quiet timer stays the user settle grace. While the user-armed watch is on, a dropped `SleepDisabled` is re-applied, not treated as Off.

## Test gaps (failing tests the plan writes)

- Cursor jsonl ~5 minutes old is still busy (today’s live gap).
- Cursor jsonl older than the new freshness is idle (do not stay awake forever).
- Saved prefs with `sessionFreshness: 45` migrate off 45.
- `Claude.app` / `Claude Helper` are not Claude Code; `node …claude-code…` is.
- `node` alone is still ignored.
- Cursor `terminals/*.txt` is relevant; `node_modules` is not walked as a project dump.
- `WatchEngine.tick(kernelSleepDisabled: false)` while engaged emits `.assertSleepDisabled` and stays on.
- Lid close while armed includes `.assertSleepDisabled` plus hygiene, still no `displaysleepnow`.
- Agents settled with lid closed still requests sleep (do not regress `cc632d1`).

## Mac runtime this agent did run

- `pmset -g`: `SleepDisabled 0`, `sleep 1` (not armed).
- Battery discharging 76% (would not hit 15% floor).
- Process names: Cursor helpers, `cursor-agent` worker, Claude.app helpers. No `claude` CLI, no `codex` CLI.
- Session mtimes as above. Did **not** toggle Keep the watch. Did **not** close the lid.

## Open questions (do not block Core)

None for starting the plan. After Core is green, a human still has to prove: arm Agents, lid open (screen usable), close lid (floor + keys, Mac stays up during a several-minute think), reopen (ramp), then real idle → allow sleep. Until that, do not claim Mac runtime.
