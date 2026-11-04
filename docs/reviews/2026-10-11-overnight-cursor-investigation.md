# Overnight Cursor watch investigation — 11 October 2026

The strongest identified explanation for the missed idle auto-off is a reproducible Codex desktop CPU classification bug. The incident itself cannot be conclusively attributed to that bug because retained logs do not contain the watch's per-provider busy decisions or historical CPU measurements.

The initial investigation was read-only with respect to application code, saved preferences, running tasks, and power state. Temporary diagnostic programs used the existing Swift implementation and were written under `/private/tmp/agrypnos-overnight-investigation`. The subsequent correction is recorded below.

## Incident evidence

All times in this section are Europe/Lisbon, UTC+1.

| Time | Evidence |
| --- | --- |
| 01:10 approximately | User reports closing the lid with a subagent-driven Cursor task running and Dim panel selected. |
| 02:40:56 | Cursor composer log first records the relevant connection failure. |
| 02:43–02:57 | Cursor worker logs connection failures, timeouts, DNS failure, and retries. |
| 02:57:24 | Latest modification among the retained Cursor transcript/subagent files whose current mtimes fall in the overnight window. These are current file metadata, not a complete historical write ledger. |
| Through 10:37:48 | Cursor composer log continues to record fetch failures. |
| 11:09:56 | macOS power log records AC power connected at 19% charge. |
| 11:29:56 | Current saved last-watch-end record says `agentsSettled`. It does not identify which arm/session ended. |

The power log has no system sleep entry from 00:40 to 11:00. Agrypnos remained running: its regular macOS service-status events occurred roughly every five seconds from 01:10 to 11:00; the largest measured gap was 5.078 seconds. This provides evidence that the main event loop continued running, rather than proving every agent measurement succeeded.

The saved preferences inspected during this investigation select Cursor and Codex, Agents duration, 120-second settle grace, 45-second session freshness, 5% battery cutoff, and terminal-session busy tracking off. Panel mode is currently Sleep panel, whereas the user reports Dim panel during the incident. These preferences are the current snapshot; their overnight values were not independently logged.

## Confirmed code behavior and defect

Cursor requires both a running matching process and a fresh session write. A stalled Cursor worker staying alive alone cannot keep the watch busy. Nested subagent writes count under the same freshness rule. Cursor CPU does not count.

Codex uses a different condition: a matching process plus either a fresh write or CPU at least 5%. `AgentKindClassifier` classifies executables whose basename starts with `codex` as Codex, including desktop `Codex (Renderer)` and `Codex (Service)` helpers. Those helpers are also eligible for CPU-based busy detection. This allows desktop activity to reset the idle wait without an agent session write.

References:

- `Sources/AgrypnosCore/Agent/AgentKindClassifier.swift:11` — broad Codex process matching.
- `Sources/AgrypnosCore/Agent/AgentKindClassifier.swift:27` — every classified Codex process is eligible for CPU busy.
- `Sources/AgrypnosCore/Agent/AgentHeuristicEngine.swift:105` — process/CPU/write evaluation.
- `Apps/Agrypnos/Sources/Agent/AgentProbeService.swift:197` — CPU threshold is 5%.
- `Sources/AgrypnosCore/Agent/AgentSettleTracker.swift:47` — busy observations reset the quiet-wait baseline.

Overnight macOS logs establish that Codex desktop service/renderer processes were present around 02:11–02:41. Current process readings also show desktop helper CPU above the threshold. Neither source supplies their CPU readings for the rest of the night.

## Reproduction

A temporary Swift replay compiled the repository's existing Core code and simulated an armed, confirmed-closed Agents watch with Cursor and Codex selected, 45-second freshness, 120-second settle grace, 5% battery cutoff, and 19% discharging battery.

| Inputs | Result |
| --- | --- |
| Cursor running; a final Cursor session write; Codex desktop renderer at 0% CPU | Watch disengages as `agentsSettled` at 165 seconds. |
| Same inputs, but the Codex desktop renderer remains at 10% CPU | Watch remains armed throughout eight simulated hours with no further session writes. |

Assertions also verified that a 5% cutoff does not disengage at 19%, and does disengage at 5%. The replay exited successfully. This proves the failure mechanism, not its historical occurrence overnight.

The real filesystem scanner completed with no permission errors or traversal-limit failures when freshness was expired for diagnosis. Normal live scans report positive activity because tasks are running during the investigation. No static folder-size or depth failure was reproduced.

## Why the battery protection did not stop this drain

The saved cutoff is 5%. The power log records 19% at charger reconnection. With those settings, the battery guard would not trigger at that level. There is no evidence from this incident that the low-battery guard failed. Its historical setting remains a qualification because only the current preference snapshot is available.

Agents duration has no fixed deadline. It depends on observed quiet time. Dim panel changes display brightness on confirmed lid-close; it does not stop the watch or independently request system sleep. Sleep panel also leaves the watch active. Changing panel mode therefore does not resolve a false-busy signal.

## Remaining uncertainty and next correction

The exact source of the network interruption is unknown. Cursor recorded connection/DNS failures while macOS's power log showed no system sleep. Agrypnos later also recorded unavailable network routes. The retained Wi-Fi events did not identify why connectivity failed.

Agrypnos's watch diagnostics use debug-level OSLog events, and the historical watch-state messages were not available in the retained log query. That leaves three possible blockers after Cursor activity stopped: another selected provider's busy signal, incomplete/rejected observations, or never having accepted busy evidence in that arm. The first has a confirmed reproducible defect; the others were not reproduced here.

The focused correction is to prevent ordinary Codex desktop renderer/service CPU from counting as agent work, while retaining support for actual Codex CLI processes, including the CLI bundled with the desktop app. It should get a regression test using the desktop helper executable path and stale transcripts before implementation.

For a Cursor-only unattended run, selecting only Cursor removes this identified cross-provider CPU path. Raising the battery cutoff from the saved 5% leaves a larger reserve. Those settings have not been changed by this investigation.

## Correction and validation

The correction is isolated on local branch `codex/ignore-desktop-agent-cpu`, starting from `discord-bot-outbound` commit `ec3adb9`. It excludes Codex desktop main/helper CPU from CPU-only busy evidence. Desktop fresh transcript writes still count; real Codex CLI processes, including the bundled CLI and Node wrapper, retain CPU evidence. Panel behavior, networking, sleep commands, and saved settings are unchanged.

Four new regression tests first failed with 18 assertions, then passed after the correction. The tests cover desktop CPU-only activity, fresh desktop transcript activity, genuine CLI CPU, and an Agents watch ending 165 seconds after a final Cursor subagent write in both Dim panel and Sleep panel modes (45 seconds freshness plus 120 seconds settle grace).

The full baseline suite already failed in `OpenCodePluginNativeTests.testProductionPluginRepliesThroughRealSocketToOriginalOpenCodeChat`: its real OpenCode socket fixture timed out. The corrected full suite reproduced that same failing test. Independent review caught one valid CLI positional-prompt edge case; a new regression first failed three assertions, then passed after detection was narrowed to recognized desktop executable paths. The final five regression tests pass. Excluding the existing OpenCode integration timeout, all 801 tests passed. The final isolated macOS Release app build succeeded. This validates the code correction; it is not a physical overnight or battery-drain test. The running application has not been replaced or restarted.

The confirmed cause of the defect is overly broad CPU eligibility: Codex desktop UI activity was treated as coding-agent work and could continually reset the quiet wait. A Cursor connection failure can leave the task unfinished, but an unfinished task alone is not a busy signal in this implementation. The connection failure and this false-busy defect can coexist; retained overnight evidence cannot establish that the defect was the actual blocker in this particular arm, nor explain the original network failure.

Final local fix commit: `6d917b4` on `codex/ignore-desktop-agent-cpu`. The original checkout remains on `discord-bot-outbound`. The committed correction report is `docs/reviews/2026-10-11-codex-desktop-cpu-fix.md` in the attached `agent-idle-cpu-fix` worktree.
