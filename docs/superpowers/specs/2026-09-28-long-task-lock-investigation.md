# Long-task lock and false idle — investigation

Date: 2026-09-28. Code baseline: `d34ff59`.
Scope: investigate and plan only; no application changes or power-setting changes.
The user explicitly waived the Grok model requirement for this task.

## Conclusion and confidence

**Confirmed:** Agents mode can turn an unfinished task into an idle-after-wait event when its local signals disappear. That event sends the outbound message and releases SleepDisabled; with the lid confirmed closed, it also requests real system sleep. Cursor being open, or consuming CPU, does not prevent this decision.

**Confirmed additional defect:** the settle clock measures wall time since the last busy observation, including intervals when Agrypnos did not observe agents. After sleep or a long polling gap, one idle sample can therefore immediately end the watch. Sleep/wake handling currently protects inbound command draining but does not invalidate agent probes or interrupt settling.

**Not established:** what initiated the user's incident on **September 27**, whether it was lock-only or real system sleep, and whether the agent stopped producing signals before or after locking. Today's persisted settings and power logs are background context, not proof of that incident. The user specifically asked not to rely on today's logs. We have not reproduced the reported hour-long task on the Mac or observed the agent failing at lock.

The fix plan addresses the confirmed observation-gap defect and collects the evidence needed to classify the reported incident. It must not present that bounded fix as a proven cure for every long task.

## Evidence from current code

| Boundary | Current behavior | Source |
|---|---|---|
| Busy classification | Cursor/OpenCode: process running **and** a fresh session file. Claude Code/Codex additionally allow eligible CPU activity at ≥5%. | `Sources/AgrypnosCore/Agent/AgentHeuristicEngine.swift:100–114` |
| Freshness and grace | Default session freshness **45s**; idle wait **120s**, configurable **120–900s**. Freshness is a flush window, not a second long idle wait. | `Sources/AgrypnosCore/Session/UserPreferences.swift:8–16` |
| Settle | After busy was seen, `now - lastBusyAt >= grace` is sufficient. No history of observation continuity. | `Sources/AgrypnosCore/Agent/AgentSettleTracker.swift:26–40` |
| Agents decision | An accepted false-busy snapshot can call `disengage(.agentsSettled)`. `observeAgents: false` skips this tick but does not stop elapsed time accruing. | `Sources/AgrypnosCore/Session/WatchEngine.swift:182–211` |
| Outbound and release | The idle POST is attempted first; then the runtime clears the kernel hold and applies the sleep command when present. Network failure does not validate or reverse the idle decision. | `Apps/Agrypnos/Sources/WatchRuntime+Poll.swift:158–193` |
| Sleep gate | Disengage includes `requestSleep` only for the captured confirmed-closed lid. This is intended behavior once the idle decision is valid. | `Sources/AgrypnosCore/Session/WatchEngine.swift:293–343` |
| Wake lifecycle | `noteMacWillSleep` / `noteMacDidWake` manage Telegram/Discord wake-miss draining only. | `Apps/Agrypnos/Sources/Notif/WatchRuntime+TelegramInbound.swift:26–39` |
| Probe errors | Failed `ps` output is parsed as an empty table; directory/resource read failures are skipped. Absence and failure are not distinguished. A delayed snapshot is cached using its completion time. | `Apps/Agrypnos/Sources/Agent/AgentProbeService.swift`; `Apps/Agrypnos/Sources/WatchRuntime+Poll.swift:110–140` |

One resulting chain is:

`local signals disappear → heuristic idle → grace expires → outbound idle message → SleepDisabled cleared → confirmed closed lid: sleepnow`

The chain can also begin with genuine sleep/suspension, followed by a stale or idle observation on wake. Current code does not establish which chain occurred yesterday.

## What locking means here

macOS password locking, display sleep, and system sleep are separate states. Apple's [Lock Screen settings](https://support.apple.com/guide/mac-help/mh11784/mac) include password requirements following screen saver/display-off. Its [idle system sleep assertion documentation](https://developer.apple.com/documentation/iokit/kiopmassertiontypepreventuseridlesystemsleep) explicitly permits display dimming/sleep while system idle sleep is prevented. A system wake hold is not a promise to suppress the password screen.

Agrypnos currently holds SleepDisabled, without a persistent display-idle assertion. During this investigation the AC profile had `displaysleep 60`; that is a possible explanation for an approximately one-hour open-lid display timeout, **not evidence of yesterday's power source or trigger**. It is not an Agrypnos one-hour timer: `AutoOffEvaluator` ignores `timerEnd` by design.

There is no evidence here that locking alone stops terminal agents. Work that depends on interacting with the unlocked desktop may be affected differently; establish the actual provider/task before recommending any display or lock change. Do not disable authentication, simulate user activity repeatedly, or prevent normal Agents auto-off whenever the session is locked. Closed-lid watches commonly have locked sessions too.

## Current settings, not historical incident settings

The local saved preferences read on September 28 were Agents duration, Cursor only, terminal sessions excluded, freshness 45s, grace 120s, outbound enabled, Power B. They explain the available failure path but do not establish September 27's configuration.

The current source and running app binary both contain the outbound text:

> Agrypnos: local busy signals went idle after the wait.

They do not say the agent finished. The user's exact message from yesterday has not been supplied. Do not silently assume it matches this binary or “fix” already honest copy as the root cause.

## Runnable evidence obtained

Ran `swift test --filter 'AgentSettleTrackerTests|WatchIdlePostHoldTests|AgentHeuristicEngineTests|StickyWatchTests|NotifIdlePostTests'`: **45 tests passed, zero failures**. These are existing behavior checks, not proof that the reported incident is fixed.

The existing `Scripts/check-file-sizes.sh` exited 1 because it also scans pre-existing untracked `.derivedData/` / `dist/` generated outputs and the older 701-line `docs/superpowers/plans/2026-09-21-subagent-busy-signals.md`. Those files were not changed or removed. The two new documents are under 600 lines. An executor must report this baseline separately from source-file limits rather than claim the whole check passes.

Compiled all existing Core sources with a temporary offline harness at `/tmp/agrypnos-long-task-investigation/main.swift`. It executes Core commands only; no Mac sleep, messages, or preference writes. Compiler and harness both exited 0:

1. Cursor process at 80% CPU, a transcript last modified at time 0, samples every 5s, default preferences, confirmed closed lid: at **165s**, Core emits `.disengage(.agentsSettled)`, `.postIdleAfterWaitNotif`, and `.requestSleep`.
2. Busy at time 0, an hour with no accepted observations, then an empty snapshot at 3605s: Core immediately emits `.disengage(.agentsSettled)`. A skipped tick does not protect the next tick.
3. Remembered one-hour duration, safe inputs, tick at 4000s: still engaged, no auto-off.

The first reproduction demonstrates the known ceiling of the specified heuristics. The second isolates a fixable continuity defect. Neither simulates macOS locking or proves a completed task versus an unfinished task from file timestamps alone.

## Fix requirements

1. Count a settle wait only across trustworthy, sufficiently continuous agent observations; never treat time asleep or an unavailable probe as a completed wait.
2. Preserve `sawBusy` and the true `lastBusyAt` across interruptions. Restart the quiet wait without inventing a new busy signal or rearming a watch that was off.
3. On sleep/wake invalidate the probe generation and cache. A fresh, timely probe must precede an Agents settle decision. Keep inbound wake-miss behavior.
4. Distinguish a successful idle reading from failed/incomplete/delayed measurements. Positive busy evidence may still protect the watch even if another selected tool is unavailable; unavailable negative evidence must not allow disarm.
5. Preserve battery/thermal/LPM safety checks, manual/inbound off, one POST per real arm, kernel-release failure rollback, and confirmed-lid sleep gates.
6. Reproduce the user's actual long task with transition diagnostics before claiming the incident resolved. If complete, continuous samples are genuinely quiet while the task is unfinished, this continuity fix is insufficient: document the existing signal ceiling and use the current longer idle wait or ∞ mode for that workload. Any new busy source needs observed evidence and a separate scoped decision.

## Constraints carried into implementation

- macOS 14+, Swift/Core separation; no new dependencies; no file over 600 lines.
- Default freshness 45s. Do not restore the rejected hidden 15-minute freshness window.
- Idle wait 2m–15m, default 2m; terminal sessions default OFF; only selected tools count.
- Power A/B and stable lid confirmation unchanged. No brightness floor/display sleep on open-lid arm, no disabling security settings.
- Real system sleep after a valid confirmed-closed disarm remains intentional.
- No telemetry, transcript bodies, task text/ETA, secret values/URLs in diagnostic output, or automatic external messages from the diagnostic tooling.

## Next evidence to collect

Record the tested build, selected tool, duration, panel mode, lid and power source; run the same workload. Capture busy transitions, probe health and observation gaps, lock/unlock and sleep/wake ordering, outbound decision, kernel readback/release, and `pmset` command outcome. Use matching timestamps to distinguish “lock → signal loss → false idle” from “false idle → hold released → sleep/lock.” Do not use unrelated current logs to fill that gap.

## Implementation evidence — September 28

Implemented the bounded continuity fix after user authorization, in `codex/agent-observation-continuity` based on `d34ff59`:

- Observation gaps over 15s, backward clock movement, and explicit interruptions restart the quiet wait. Real busy history and the one-POST latch survive interruptions.
- Complete, timely negative measurements can advance the wait. Failed process reads, malformed process tables, filesystem errors, exhausted traversal budgets, expired positives from an early traversal stop, and stale/delayed callbacks cannot. Timely partial positive busy evidence still protects the watch.
- Actual measurement start/completion times are retained. A cache entry expires from collection completion, rather than callback delivery. A backward cache timestamp is rejected. Timely partial positives may be cached inside the same 5s window; incomplete negatives are never cached.
- Existing sleep/wake callbacks now invalidate the cache and generation and interrupt the wait, independently of inbound settings. Wake requests a fresh poll without arming the watch. Preference changes also interrupt the old observation chain through the existing invalidation helper.
- Local OSLog diagnostics record probe/state transitions, lifecycle, end reasons, kernel readback, outbound decisions and power-command outcomes. Unchanged probes do not generate a log every five seconds. Observation gaps and backward clock movement emit explicit restart events. Logs contain booleans, provider names, timestamps and outcomes, without paths, process arguments, transcript contents or notification secrets.

Automated verification: all **592 Core tests passed**; the Mac collection check passed against the actual walker/reader, including injected failed reads/caps, an expired early-positive shortcut with skipped fresh activity, and a real fresh nested subagent file with terminals OFF; the Debug app build succeeded; file-size and diff-whitespace checks passed in the isolated checkout. Existing unrelated AppKit actor/deprecation warnings remain in the app build.

The polling timer remains 5s, session freshness remains 45s by default, and the user idle wait remains 2–15m. No wattage was measured. No lock/security setting, synthetic input, new external polling or busy provider was added.

**Still unverified:** running-app OSLog output, actual runtime sleep/wake callback ordering, a matching >1h workload while locked in Power A/B, and the September 27 incident's causal order. The existing running app was not replaced or driven into sleep/lock. These checks require the user's workload and a controlled Mac test. This implementation fixes demonstrated observation defects; it does not establish that screen locking caused the historical incident, prevent macOS locking, or detect unfinished tasks whose permitted local signals remain continuously quiet.
