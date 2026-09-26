# Performance and absolute-minimum wattage

Date: 2026-09-26  
Branch: `cursor/overnight-review-docs-12fc`  
Base: `main` @ `54d0ad7` (Honesty: Discord inbound UI landed / not Mac-proven)  
**NOT FOR MERGE — review docs only**

No watt number in this note was measured. Nothing here is a StillOn-style claim. Each item is a mechanism that can keep the CPU, disk, network, panel, or keyboard busier than the bar requires. Magnitude is **hypothesis — needs Mac measure** unless the row says the code path itself is confirmed.

## Scope / method

Read for this note (plus the call sites that spawn work from them):

- `Apps/Agrypnos/Sources/WatchRuntime.swift` — `poll`, `pollLid`, `startLidPulse`, `armKernel`
- `Apps/Agrypnos/Sources/Agent/AgentProbeService.swift` — `AgentProbeService.snapshot`, `SessionFileWalker.walk`
- `Apps/Agrypnos/Sources/Power/MachineSensors.swift`, `SleepDisabledController.swift`, `Support/ProcessRunner.swift`
- `Apps/Agrypnos/Sources/Power/BrightnessFloorController.swift`, `BrightnessRampController.swift`, `KeyboardBacklightController.swift`, `PowerHygieneCoordinator.swift`
- `Apps/Agrypnos/Sources/MenuBar/StatusItemController.swift`, `PopoverController.swift` (`startCountdown`, `refresh`)
- `Apps/Agrypnos/Sources/Notif/TelegramInboundPoller.swift`, `DiscordInboundGatewayClient.swift`
- Core gates: `LidCloseConfirm`, `PanelPowerMode`, `AgentHeuristicEngine`, `HygieneRestore`, `AutoOffEvaluator`

Not measured: energy log, `powermetrics`, package power, display backlight current, or a closed-lid bag test. This environment is not a Mac.

## Executive summary

Agrypnos does **not** hold an extra IOKit power assertion. Closed-lid wake is `pmset disablesleep` for real arms, which is the product, not waste.

The always-on cost is the menu extra itself. `WatchRuntime.poll` runs every **5s for the life of the process**, including when Keep the watch is off and How long is not Agents. Each tick shells `pmset` more than once, runs `ps -ax`, and walks agent session trees on the **main thread**. While the watch is armed, a **0.25s** clamshell poll continues for the whole arm, not just the confirm window. While Telegram or Discord inbound is on, that 0.25s poll continues even with the watch off.

The closed-lid armed period is where extra draw matters. Power A should be at the brightness floor with the keyboard light off; Power B should have the panel asleep. Those gates exist. What still runs underneath them is process scanning, directory walks (including Cursor **terminal** files), and IOKit polling. A false “busy” signal also holds `SleepDisabled` until idle-after-wait, which is a much larger draw than any poll.

No code was changed.

## Already aligned (do not “optimize” these away)

| Mechanism | Why it stays |
|---|---|
| `SleepDisabled` only while armed / leftover adopt | Bar: lid-closed keep-awake. IOKit assertions are not the lid story. None are created. |
| Floor write only from `PanelPowerMode.lidCloseCommands` when armed + confirmed + Power A | Mutually exclusive with `requestDisplaySleep`. |
| Power B is `displaysleepnow`, not a second wake hold | B does not clear Keep the watch. |
| Idle-after-wait minimum 2 minutes | Bar. Do not advertise 15s or 30s. |
| Notif default off; inbound default off | Network cost is opt-in. |
| Telegram `getUpdates` timeout 25s when seeded | Already a long poll, not a 1s spin. |
| Secrets file mode `0600`, ephemeral `URLSession` | Not a watt item; noted so nobody “fixes” it with Keychain (login prompt). |

## Findings

### W1 — Unconditional 5s probe while the watch is off

- **Severity:** high
- **Evidence:** confirmed from code. Watts: hypothesis — needs Mac measure.
- **Where:** `WatchRuntime.start` schedules `Timer` 5s → `poll`. `poll` always calls `reconcileKernel` (`SleepDisabledController.read` → `pmset -g`), `BatteryMonitor.reading` (`pmset -g batt`), `SleepDisabledController.read` again, and `AgentProbeService.snapshot` **before** `WatchEngine.tick`. `tick` returns immediately when `engaged == false`, and only reads the snapshot when `mode == .untilAgentsSettle`.
- **Draw:** at least three `pmset` processes and one `ps -ax` plus a session-file walk every 5 seconds, forever, including launch-at-login with the watch disarmed (launch must not re-arm; it still probes).
- **Next owner:** Swift (skip the probe when it cannot change a command). User Mac measure: `powermetrics` or Activity Monitor energy for Agrypnos idle vs a build that no-ops `poll` when disarmed and not in Agents.

### W2 — Main-thread `ps` and directory walk

- **Severity:** high
- **Evidence:** confirmed from code (blocks the main actor). Duration and watts: hypothesis — needs Mac measure.
- **Where:** `AgentProbeService.snapshot` → `ProcessListReader.records` (`/bin/ps -axo pid= -o pcpu= -o args=`) and `SessionFileWalker.signals`. `walk` uses `FileManager.enumerator`, stats each candidate, and stops at **4000** files or depth **6** per root. Called from `@MainActor` `poll` and again from Telegram `/status` and Discord `/status` (`WatchRuntime+TelegramInbound.applyTelegramUpdates`, `WatchRuntime+DiscordInbound.finishDiscordInbound`).
- **Draw:** wakes the CPU and can wake the disk on the exact interval the closed-lid Mac should be idle. A large `~/.cursor/projects` tree makes each tick longer, which also delays the 0.25s lid pulse (W3) so Power A stays brighter than the floor for longer after a real close.
- **Next owner:** Swift. Move the probe off the main actor; do not walk when How long is not Agents; do not walk tools that are not selected (`includedAgentKinds` is applied only later in `AgentSnapshot.anyBusy`).

### W3 — Clamshell polled at 4 Hz for the whole arm, and whenever inbound is on

- **Severity:** high
- **Evidence:** confirmed from code. Watts: hypothesis — needs Mac measure.
- **Where:** `LidCloseConfirm.pulseInterval` is **0.25s**. `startLidPulse` runs while `engine.engaged || inboundNeedsLid()`. `inboundNeedsLid` is Telegram polling **or** Discord gateway. `pollLid` does `IOServiceGetMatchingService` on `IOPMrootDomain` plus `AppleClamshellState` every pulse. After close is confirmed, the pulse does not slow down.
- **Draw:** IOKit matching four times a second for a multi-hour closed-lid arm, and also all day if the user only turned inbound on. The debounce only needs a short burst to confirm a transition. `/disarm` already calls `pollLid` once at apply time; that single sample cannot confirm by itself (confirm needs ≥ 0.25s of closed samples), which is why the pulse exists — it does not have to stay at 4 Hz after the edge.
- **Next owner:** Swift. User Mac measure: CPU time of Agrypnos with watch off + inbound off, vs inbound on + watch off, vs armed + lid closed.

### W4 — Menu bar refresh shells `pmset` again, and the popover adds a 1 Hz timer

- **Severity:** medium
- **Evidence:** confirmed from code. Watts: hypothesis — needs Mac measure.
- **Where:** `poll` always calls `delegate?.watchRuntimeDidChange`. `StatusItemController.refresh` calls `BatteryMonitor.reading()` (`pmset -g batt`) even when the glyph did not change. `PopoverController.open` calls `startCountdown`, a **1s** timer whose `refresh` path recomputes `timerEnd` remaining seconds. `AgrypnosCopy.durationHint` discards `remainingSeconds` (`_ = remainingSeconds`). `StatusItemChrome` also discards remaining seconds. The 1 Hz timer does not paint a countdown; it still refreshes the whole popover.
- **Draw:** extra `pmset` on top of W1 (about four `pmset` launches per 5s while idle, plus 1 Hz UI work while the popover is open). Timed How long does not auto-off, so the timer is not buying a real clock.
- **Next owner:** UI. Delete the countdown timer (see improvements). Keep one battery read per poll if the tooltip still needs on-battery vs AC.

### W5 — Cursor terminal files count as agent busy

- **Severity:** high (this holds `SleepDisabled`, which dominates poll cost)
- **Evidence:** confirmed from code and tests. Watts of the resulting hold: hypothesis — needs Mac measure.
- **Where:** `SessionFileLayout.isRelevantFile` returns true for Cursor paths containing `/terminals/` with extensions `txt`, `json`, `jsonl`, or `db`. `cursorWalkRoots` walks `terminals` beside `agent-transcripts`. `AgentKindClassifier` treats basename `cursor` **or any prefix `cursor`** as the Cursor process, so the IDE being open sets `processRunning`. `AgentHeuristicEngine` Cursor busy is `processRunning && recentSessionWrite` within `sessionFreshness` (default **45s**). `AgentSettleTracker` then waits `agentSettleGrace` (default **120s**, floor 120) after the last busy sample.
- **Draw:** a shell that keeps writing `terminals/*.txt` (build, test, log tail) keeps How long = Agents armed. The Mac stays on `SleepDisabled` with the lid closed until the terminal is quiet for 45s + the idle wait. That is not a poll; it is the full wake hold. Tests lock this in (`testCursorTerminalsAreRelevantAndNoiseIsNot`). The bar names transcripts and `subagents/*.jsonl`, not IDE terminals.
- **Next owner:** Rules (is a terminal a busy signal?), then Swift if the answer is no. User Mac measure: arm Agents, run a long command in a Cursor terminal, confirm whether Keep the watch stays on with no agent transcript writes.

### W6 — OpenCode CPU-only busy, and Claude/Codex CPU at 5%

- **Severity:** medium
- **Evidence:** confirmed from code. False-hold rate: hypothesis — needs Mac measure.
- **Where:** `AgentHeuristicEngine.evaluate` sets Claude, Codex, **and OpenCode** busy when the process is running and (`cpuBusy` **or** a recent session file). `cpuCountsTowardBusy` is true for `.openCode`. Threshold is **5** percent (`AgentHeuristicConfig`). The bar allows CPU for Claude and Codex. It describes OpenCode as local process + session files. Tests expect OpenCode `cpuBusy` to count (`AgentHeuristicEngineTests`).
- **Draw:** a resident CLI at ≥ 5% CPU with no session write holds the watch, then the settle grace, then (if the lid was confirmed closed and the reason is not user) `pmset sleepnow`. The hold is the watt cost; the threshold is a guess, not a measured cutoff.
- **Next owner:** Rules for OpenCode CPU. Swift only if Rules drop it. Do not lower the 2-minute settle floor to chase watts.

### W7 — Probe ignores the include set and the 4000-file cap

- **Severity:** medium
- **Evidence:** confirmed from code. Missed-file behavior: hypothesis — needs Mac measure.
- **Where:** `AgentProbeService.snapshot` always walks Cursor, Claude, Codex, and OpenCode roots. Selection is applied only in `anyBusy(included:)`. `walk` breaks after 4000 visited URLs in filesystem order, not newest-mtime order.
- **Draw:** unselected tools still stat disks every 5s. A capped walk can also **miss** the live transcript and treat a running agent as idle, which ends the watch early (see bugs). Early sleep saves watts; a missed busy signal is a correctness bug, not a saving to keep.
- **Next owner:** Swift.

### W8 — Brightness path `dlopen`s DisplayServices on every read and write

- **Severity:** medium
- **Evidence:** confirmed from code. Watts: hypothesis — needs Mac measure.
- **Where:** `BrightnessFloorController.displayServicesGet` / `displayServicesSet` call `load`, which `dlopen`s `DisplayServices.framework` and `dlsym`s every time. No `dlclose`. `BrightnessRampController.start` schedules **30 Hz** for 1–3s (`Timer` interval `1/30`) and calls `set` each tick. `PowerHygieneCoordinator` also `set`s on floor apply and on disengage restore.
- **Draw:** a lid-open ramp is tens of framework loads plus 30 wakeups a second. Small next to `SleepDisabled`, real next to “panel already at the target.” The ramp is product for Power A; the per-call `dlopen` is not.
- **Next owner:** Swift (cache the function pointers once). User Mac measure: not required to justify caching `dlsym`; required before any claim that the ramp’s watt cost matters.

### W9 — Hygiene restore can raise brightness, including while the lid is still closed

- **Severity:** high (closed-lid case)
- **Evidence:** confirmed from code that a write is issued. Whether the panel backlight actually rises with the lid shut: hypothesis — needs Mac measure.
- **Where:** `HygieneRestore.displayBrightnessToRestore` returns `max(captured, floor)`, so a captured level below the floor is rewritten **up** to the floor. `PowerHygieneCoordinator.apply` on `.applyBrightnessFloor` also does `savedBrightness = max(saved, preferences.brightnessFloor)` before the floor write, so the stored “pre-hygiene” value is already lifted. `restoreAfterDisengage` writes that value whenever Power A and `applyBrightnessFloor` are on, **without** checking that the lid is open. `WatchRuntime.finishTickCommands` calls `restoreHygiene()` **before** `apply` runs `.requestSleep`. `setEngaged(false)` (popover / hotkey) restores and does **not** emit `.requestSleep` (reason `.user`).
- **Draw:** user-off or safety-off with the lid confirmed closed can turn the keyboard light back on (`restoreKeyboardBacklight`) and, on Power A, write a brighter panel, and user-off does not then call `sleepnow`. `WatchCommand.requestSleep`’s own comment says dropping `SleepDisabled` does not start sleep if the lid is already shut. A closed Mac that stays awake is the watt problem. Do not invent a watt figure for it.
- **Next owner:** Swift for the write. Rules for whether popover/hotkey user-off may `sleepnow` (today that path is inbound `/disarm` only). User Mac measure: arm, confirm lid close, turn Keep the watch off from the popover, see whether the Mac sleeps and whether brightness or the keyboard light changes before it does.

### W10 — A↔B while hygiene is already applied does not change the panel

- **Severity:** medium
- **Evidence:** confirmed from code. Panel result: hypothesis — needs Mac measure.
- **Where:** `WatchRuntime.setPanelPowerMode` saves the enum and refreshes UI. It does not emit `lidCloseCommands` or a restore. Switching Dim → Sleep while the floor is already applied leaves the panel dimmed instead of `displaysleepnow`. Switching Sleep → Dim leaves the panel asleep and shows the ramp chrome, but no floor write and no ramp until the next lid edge.
- **Draw:** Sleep panel that never slept stays on (dim). Dim panel that is still display-asleep is dark, which is fine for watts and wrong for the label. Staying on the dim path in a bag is the costly direction.
- **Next owner:** Swift, after a Mac check. Do not apply floor and `displaysleepnow` together.

### W11 — Network only when Notif inbound or outbound is on

- **Severity:** low as a baseline; medium if the user leaves inbound on
- **Evidence:** confirmed from code. Radio watts: hypothesis — needs Mac measure.
- **Where:** Telegram long-poll **25s** (`TelegramInboundPoll.longPollSeconds`) plus 35s URL timeout, retry 5s on failure. Discord Gateway stays connected and heartbeats at the server interval (`startHeartbeat`). Both are receive-on-the-Mac. No listen port, no Interactions Endpoint URL (`DiscordInboundTransport`). Outbound POST is one shot after settle, 3s bound (`NotifIdlePoster.waitBound`).
- **Draw:** an open Gateway plus TLS heartbeats, and a Telegram request that is in flight most of the time, will keep the Wi-Fi radio from the deepest idle. That is the cost of inbound. Default off is the mitigation. Do not add a second poller. Discord-unify is parked (see improvements).
- **Next owner:** user Mac measure only if inbound-on battery life is a complaint. Swift: do not shorten the long poll.

### W12 — `displaysleepnow` / `sleepnow` / `osascript` block the main actor; failures are ignored

- **Severity:** medium
- **Evidence:** confirmed from code that the call is synchronous and the exit code is discarded (`_ = ProcessRunner.run`). How long `pmset` blocks, and whether user-level `displaysleepnow` works without the sudoers grant: hypothesis — needs Mac measure.
- **Where:** `PowerHygieneCoordinator` runs `pmset displaysleepnow` and `pmset sleepnow` inline. The sudoers grant is only `disablesleep 0` and `disablesleep 1` (`SudoersGrant.pmsetClause`). `UserNotify.post` runs `osascript` inline on the same actor, including on every non-user disengage.
- **Draw:** a stalled main thread delays W3, so the floor or panel sleep lands late (panel stays brighter). A failed `displaysleepnow` that nobody reads leaves Power B on the Power A physical path (panel on) while the caption says the panel sleeps.
- **Next owner:** Swift (surface failure, don’t block the UI). User Mac measure: Power B confirmed close actually sleeps the panel on this OS build without sudo.

### W13 — Dead timer clock is not a watt bug by itself

- **Severity:** low
- **Evidence:** confirmed from code.
- **Where:** `WatchEngine.applyDuration` sets `timerEnd` for 1h / 3h / custom. `AutoOffEvaluator` ignores `timerEnd` (`_ = timerEnd`). `DisengageReason.timerExpired.turnsWatchOff` is false. The popover still keeps a 1 Hz timer (W4).
- **Draw:** the `Date` math is nothing. The 1 Hz `refresh` is the cost. The product is remembered-only How long. Do not “finish” the timer to auto-off; that would be a behavior change the bar forbids.
- **Next owner:** UI (stop ticking). Swift (delete unused `timerEnd` only if UI and `/status` stop reading it).

## What this pass did not find

- No `IOPMAssertionCreate` / no always-on `caffeinate` except Power B lid-open `caffeinate -u -t 1` (`PowerHygieneCoordinator`, detached, 1 second). That pulse is a panel wake, not a sleep hold. Whether one second of user-activity is enough to wake the panel after `displaysleepnow` is still marked “Needs a Mac” on `WatchCommand.wakeDisplay`.
- No Wi-Fi or Bluetooth kill (out of scope; do not add).
- No watt table, no competitor comparison, no display-sleep claim for Power A or for the Keep the watch toggle.
- Discord inbound and Telegram inbound do not run when their toggles and secrets are empty (`shouldPoll` / `shouldReceive`).

## Open questions

1. After popover/hotkey user-off with the lid already confirmed closed, does this Mac stay awake? (W9.) Measure before changing who may call `sleepnow`.
2. With Cursor open and a noisy integrated terminal, does Agents mode ever go idle? (W5.)
3. What is Agrypnos’s idle energy with watch off, inbound off, popover closed? That is the W1+W2+W4 baseline. No number exists yet.
4. On confirmed Power B close, does `pmset displaysleepnow` succeed as the console user? (W12.)
5. Does `DisplayServicesSetBrightness` while `AppleClamshellState` is closed change backlight power, or only the stored level? (W9.)

## Explicit

No code was changed. No watt was measured. Soft Mac optical for Discord inbound is still open; this note does not treat Discord as Mac-proven and does not ask anyone to implement it tonight.
