# Bugs that can break the app right now

Date: 2026-09-26  
Branch: `cursor/overnight-review-docs-12fc`  
Base: `main` @ `54d0ad7` (Honesty: Discord inbound UI landed / not Mac-proven)  
**NOT FOR MERGE — review docs only**

Correctness, crash, race, wake/sleep, secrets, Discord, and Telegram. Style nits are not in this list. Watt mechanisms that are not also wrong behavior live in `reviews/01-performance-wattage.md`.

No code was changed.

## Scope / method

Full read of the watch/wake path and Notif adapters, then targeted reads of heuristics, copy, and the popover:

- `Sources/AgrypnosCore/Session/WatchEngine.swift`, `Power/Safety.swift`, `Power/LidCloseConfirm.swift`, `Power/PanelPowerMode.swift`, `Power/HygieneRestore.swift`
- `Sources/AgrypnosCore/Agent/AgentHeuristicEngine.swift`, `AgentKindClassifier.swift`, `SessionFileLayout.swift`
- `Sources/AgrypnosCore/Notif/` — Telegram cursor/drain, Discord gateway session, webhook URL, secrets payload
- `Apps/Agrypnos/Sources/WatchRuntime.swift` and `Notif/WatchRuntime+TelegramInbound.swift`, `WatchRuntime+DiscordInbound.swift`
- `Apps/Agrypnos/Sources/Notif/TelegramInboundPoller.swift`, `DiscordInboundGatewayClient.swift`, `NotifSecretsStore.swift`, `NotifIdlePoster.swift`
- `Apps/Agrypnos/Sources/Power/PowerHygieneCoordinator.swift`, `BrightnessFloorController.swift`, `KeyboardBacklightController.swift`, `SleepDisabledController.swift`, `MachineSensors.swift`
- `Apps/Agrypnos/Sources/MenuBar/PopoverController.swift`, `StatusItemController.swift`
- `Apps/Agrypnos/Sources/Support/ProcessRunner.swift`, `GrantAndNotify.swift`
- `Apps/Agrypnos/Sources/AppDelegate.swift`

Linux cannot execute IOKit, `pmset`, or the Gateway socket. Rows say **confirmed from code** or **hypothesis — needs Mac measure**.

## Executive summary

Nothing in this pass is a confirmed launch crash (`fatalError` / `try!` / `as!` are absent under `Apps/`). The failures that matter are wake/sleep honesty and inbound races.

The sharpest confirmed logic bug: **turning Keep the watch off from the popover or hotkey while the lid is confirmed closed does not `sleepnow`**, and the same code comments that dropping `SleepDisabled` will not start clamshell sleep. Non-user reasons do `sleepnow`. Inbound `/disarm` does `sleepnow` only when `lidCloseConfirmed` was already true. Those three paths disagree, and the user path also **restores brightness and the keyboard light before** any sleep request.

Next: Discord slash handling can apply a command on a later turn **without** re-checking the poller generation, and the Gateway heartbeat ack flag is written off the main actor and read on it. Agents mode can stay busy because Cursor **terminal** files count, or can go idle too early because the walker stops at 4000 files. Watch captions and tooltips still describe the brightness floor when Power B is selected.

Telegram wake-miss handling is in better shape than Discord’s deferred slash path: `TelegramInboundDrain.effective` forces wake-miss when the stored cursor says so, and `finishTelegramInboundPoll` checks generation.

No code was changed.

## Checked and not a bug (this pass)

| Claim | What the code does |
|---|---|
| Floor + `displaysleepnow` together | `PanelPowerMode.lidCloseCommands` appends one panel command, never both. |
| Floor while lid open, or under Power B | `shouldWriteFloor` requires armed + confirmed + `.floor`. Coordinator repeats the mode check. |
| Nil brightness capture writes the floor | `HygieneRestore.displayBrightnessToRestore` returns nil when `captured` is nil. Keyboard nil skips too. |
| Single raw clamshell edge applies hygiene | `LidCloseConfirm.sample` needs ≥ 0.25s of closed samples. Arm passes `lidClosed: false` into `userSetEngaged`. |
| Inbound `/disarm` sleeps whenever it disarms | `applyTelegramDisarm` / `applyDiscordDisarm` snapshot `lidCloseConfirmed` **before** `setEngaged(false)`. Open or unconfirmed does not append `.requestSleep`. |
| Wake-miss auto-apply on the Telegram long poll | In-flight poll uses `TelegramInboundDrain.effective(stored:fetched:)`. Stored wake-miss wins. Stale generation is dropped in `finishTelegramInboundPoll`. |
| Discord webhook receives commands | Outbound uses the webhook URL only. Inbound uses bot token + channel id. `DiscordInboundTransport.usesIncomingWebhook` is false. No Interactions Endpoint URL, `listenPort` is nil. |
| Shared bot / Keychain prompt | Secrets are `notif-secrets.json` via `NotifSecretsStore`, created `0600`, not Keychain. |
| Status item countdown | `StatusItemState.autoOffEndClock` always returns nil. Title is `Armed.` / `Agents.` / empty. |
| Enriched-status B | `/status` copy has no task text and no ETA. Live battery line omits the percent when unknown. |
| Empty agent selection | `applyIncludedAgentKinds` rejects an empty set. |
| Thermal toggle | `AutoOffEvaluator` returns `.thermal` only when `thermalAutoOff` is true. |
| Launch re-arm | `applicationDidFinishLaunching` does not call `setEngaged(true)`. Leftover `SleepDisabled` is cleared first (`preferClearLeftover: true`). |
| LPM forced-watch “ended” copy | `TelegramWatchStatusCopy.lpmLine` says the watch is still on when engaged and `userForcedThisSession`. |

## Findings

### B1 — Popover and hotkey off, lid already closed, may leave the Mac awake

- **Severity:** high
- **Evidence:** confirmed from code that user-off does not emit `.requestSleep`. Whether macOS then sleeps: **hypothesis — needs Mac measure**.
- **Where:** `WatchEngine.disengage` appends `.requestSleep` only when `wasLidClosed && reason != .user`. `WatchCommand.requestSleep` is documented: “Lid already shut: dropping SleepDisabled does not start sleep; ask the Mac to.” `WatchRuntime.setEngaged(false)` is the popover/hotkey path (`reason == .user`), so it never asks. It does call `disarmKernel()` (`pmset -a disablesleep 0`) and `restoreHygiene()`.
- **Contrast that makes this a bug rather than a missing feature:** the same function **does** `sleepnow` for battery, thermal, LPM, and `.agentsSettled` when the lid was closed. Inbound `/disarm` `sleepnow`s when confirm was true, even if the watch was already off (`applyTelegramDisarm` / `applyDiscordDisarm`). The bar says the `sleepnow` path is inbound `/disarm` only, **and** that turning the watch off lets the machine sleep. Those two sentences do not both hold if the kernel will not retrigger clamshell sleep.
- **Also on this path:** `restoreAfterDisengage` runs with the lid still shut. Power A writes brightness (`max(captured, floor)`). Both modes restore keyboard brightness if a value was captured. Safety auto-off does the restore **and then** `sleepnow` (`finishTickCommands` restores inside the `.disengage` loop, then `apply` runs `.requestSleep`).
- **Next owner:** Rules (may popover/hotkey user-off call `sleepnow` when confirm is already true?). Swift once Rules answer. User Mac measure: the actual test.

### B2 — Disarm-failure rollback throws away the re-engage commands and clears lid state

- **Severity:** medium
- **Evidence:** confirmed from code.
- **Where:** `WatchRuntime.finishTickCommands`. On `.disengage`, if `disarmKernel()` is false, it calls `engine.rollbackDisarmFailure(now:lidClosed: engine.lidClosed)` and **ignores the returned commands**, then sets `applyCommands = []`. `disengage` has already set `lidClosed = false` and `lidConfirm.reset()` before the caller reads `engine.lidClosed`, so the rollback’s `lidClosed` argument is false even if the lid was confirmed closed a moment ago. `engage` then sets `lidHygieneApplied = false` while the panel may still be at the floor or display-asleep. Physical hygiene is not re-issued until a later `observeLid` confirms again.
- **User-facing:** the notification says the watch stays up (kernel flag still on). `/status` can report lid open or unconfirmed while the lid is shut and the old hygiene is still in effect. A second `displaysleepnow` or floor write waits on the debounce.
- **Next owner:** Swift. The rollback’s returned `[WatchCommand]` should be applied, and the lid confirm should not be sampled after `disengage` already zeroed it.

### B3 — Quit ignores a failed kernel clear

- **Severity:** medium
- **Evidence:** confirmed from code. Leftover behavior on next launch is the adopt path, which is implemented.
- **Where:** `WatchRuntime.prepareForTermination` calls `_ = disarmKernel()` when `terminatePlan.clearKernel` and does not check the `Bool`. `quitApp` calls `setEngaged(false)` first, which returns early if disarm fails, then `NSApp.terminate` still runs `prepareForTermination`.
- **User-facing:** Quit can leave `SleepDisabled` on. Next launch tries to clear it (`reconcileKernel(preferClearLeftover: true)`). If that also fails, the app adopts the leftover and posts `AgrypnosCopy.leftoverNotify`, which always mentions the brightness floor (wrong under Power B; see B7).
- **Next owner:** Swift.

### B4 — Switching Dim panel / Sleep panel does not re-run hygiene

- **Severity:** high
- **Evidence:** confirmed from code. Physical panel: **hypothesis — needs Mac measure**.
- **Where:** `WatchRuntime.setPanelPowerMode` assigns `preferences.panelPowerMode` and saves. No `lidCloseCommands`, no `wakeDisplay`, no floor clear. `PopoverController.panelPowerChanged` only refreshes the section.
- **User-facing:** lid already confirmed closed, Power A floor already applied, user picks Sleep panel: caption changes to panel-sleep, panel stays dimmed, no `displaysleepnow`. Opposite direction: panel stays in display sleep under Dim panel, ramp chrome comes back, brightness is not restored. Next lid-open uses the **new** mode’s restore (`lidOpenCommands`), so B→A open ramps instead of `caffeinate -u`, and may not wake a sleeping panel.
- **Next owner:** Swift. Keep A and B exclusive (never floor and `displaysleepnow` in one command list). User Mac measure: A↔B with the lid confirmed closed, then lid open.

### B5 — Watch caption and status tooltip always describe the brightness floor

- **Severity:** medium
- **Evidence:** confirmed from code. This is a live copy bug, not a docs nit. Power section chrome is fine.
- **Where:** `PopoverController.refresh` sets `caption` from `AgrypnosCopy.watchCaption`, which only branches on engaged / leftover / `lidClosed`. `captionPrepared` / `captionLidClosed` always say brightness floor + keyboard backlight off. `StatusItemController.refresh` uses `AgrypnosCopy.menuTooltip`, same story (`menuTooltipOn`, `menuTooltipLidClosed`, leftover strings). `PanelPowerChrome.caption` / `.help` on the Power card do teach A vs B. `leftoverNotify` is also floor-only.
- **User-facing:** Sleep panel selected, Watch still says the next lid close sets the brightness floor. The bar forbids claiming display sleep for Power A; this is the mirror error: claiming the floor for Power B. `/status` is better: `PanelPowerMode.statusLine` is included in `TelegramWatchStatusCopy.reply`.
- **Next owner:** UI (caption + tooltip must take `panelPowerMode`). The Power card can stay as it is.

### B6 — Armed with the lid already closed never captures brightness

- **Severity:** medium
- **Evidence:** confirmed from code.
- **Where:** `setEngaged(true)` calls `userSetEngaged(true, lidClosed: false)` then `observeLid`. `LidCloseConfirm.shouldRecaptureOpenBrightness` is false when `rawClosed` is true, so `recaptureOpenLidHygiene` does not run. Confirm arrives ≥ 0.25s later and applies the floor or `displaysleepnow` with `savedBrightness` still nil if nothing was captured earlier. Lid-open restore then hits the nil skip and **does not** write brightness back. The panel can stay at the floor after the lid opens. That matches “nil capture skips,” and it is a bad capture, not a bad skip.
- **Same hole:** Telegram `/arm` and Discord `/arm` go through `setEngaged(true)`.
- **Next owner:** Swift. Capture once, before the floor write, if `current()` still returns the pre-hygiene level. Do not invent a number if `current()` is nil. User Mac measure: arm from inbound with the lid already shut, then open.

### B7 — Captured brightness below the floor is replaced with the floor

- **Severity:** medium
- **Evidence:** confirmed from code.
- **Where:** `HygieneRestore.displayBrightnessToRestore` returns `max(captured, floor)`. `PowerHygieneCoordinator` on `.applyBrightnessFloor` stores `max(saved, preferences.brightnessFloor)` into `savedBrightness`. A user at 8% with a 15% floor is restored to 15%, not 8%. Nil still skips. The bar says restore the captured level and do not fall back to the floor when capture is nil. It does not say to clamp the capture up.
- **Next owner:** Swift. User Mac measure only if someone was using the Mac dimmer than the floor.

### B8 — Cursor terminals (and a broad process name) hold or drop Agents mode

- **Severity:** high
- **Evidence:** confirmed from code. Runtime effect: **hypothesis — needs Mac measure**.
- **Where:** `SessionFileLayout.isRelevantFile` for `.cursor` treats `/terminals/` + `txt`/`json`/`jsonl`/`db` as a busy file. Tests assert that (`testCursorTerminalsAreRelevantAndNoiseIsNot`). `AgentKindClassifier.classify` maps basename `cursor` and **any** `hasPrefix("cursor")` to `.cursor`, so Cursor.app being open is `processRunning`. Busy is process **and** a session write newer than 45s. Then settle grace (≥ 2 minutes) must elapse before `.agentsSettled`.
- **User-facing:** How long stays Agents and the Mac stays on `SleepDisabled` for the whole time a Cursor terminal is noisy, plus 45s + idle wait, even with no transcript write. If the lid is confirmed closed, the eventual settle calls `sleepnow` (B1’s non-user path) and an idle-after-wait POST if Notif is on and `sawBusy`. A terminal is enough to set `sawBusy`.
- **Related false idle:** `SessionFileWalker.walk` stops after 4000 URLs. Order is directory order, not newest file. A busy transcript past the cap does not count. Settle can disarm and `sleepnow` while an agent is still writing. **Hypothesis — needs Mac measure** on a large `~/.cursor/projects`.
- **Next owner:** Rules for terminals (tests currently require them). Swift for the cap and the `cursor*` prefix if Rules agree the IDE binary is the only process name. User Mac measure: terminal-only “busy,” and a project tree larger than the cap.

### B9 — OpenCode can be busy on CPU with no session file

- **Severity:** medium
- **Evidence:** confirmed from code. The bar text and the tests disagree.
- **Where:** `AgentHeuristicEngine` uses `cpuBusy || recentSessionWrite` for `.openCode`. `cpuCountsTowardBusy` includes `.openCode`. Threshold 5%. `AgentHeuristicEngineTests` expects that. The bar says OpenCode is process + session files, and names CPU for Claude and Codex.
- **User-facing:** an OpenCode process at ≥ 5% CPU with stale session files keeps the watch armed. That delays sleep the same way B8 does.
- **Next owner:** Rules. Do not “fix” it in Swift until the bar or the tests move. Not a Mac-proven behavior change to sneak in.

### B10 — Main-thread probe delays lid confirm, Discord’s 3s ack, and the popover

- **Severity:** high
- **Evidence:** confirmed from code that the work is synchronous on `@MainActor`. Stall length: **hypothesis — needs Mac measure**.
- **Where:** `poll`, `StatusItemController.refresh` (`pmset`), and both `/status` handlers call `AgentProbeService.snapshot` and `ProcessRunner.run` on the main actor. `ProcessRunner.run` `waitUntilExit` after reading stdout to EOF. `PowerHygieneCoordinator` also blocks on `pmset displaysleepnow` / `sleepnow`. `UserNotify.post` blocks on `osascript`.
- **User-facing:** lid-close floor or `displaysleepnow` waits until the walk finishes, so an unconfirmed close stays bright. Discord slash commands must be acked quickly; `applyDiscordInbound` hops to the main actor before it can defer. A long `poll` in front of that hop expires the interaction. The popover stops tracking until `pmset` / `ps` / the walk return. This is a hang, not a deadlock (`DispatchQueue.main.sync` does not appear).
- **Pipe note (low):** stdout is read to EOF before stderr. A child that fills the stderr pipe (~64KB) while still writing stdout deadlocks `ProcessRunner.run`. `ps` and `pmset` do not do that today. `sudo` password chatter is avoided with `-n`.
- **Next owner:** Swift (probe off the main actor). User Mac measure: time `poll` on a real home directory.

### B11 — Discord slash defer can apply after invalidate / wake

- **Severity:** high
- **Evidence:** confirmed from code. Needs a Mac only to see it against a live Gateway; the race is in the adapter.
- **Where:** `WatchRuntime.applyDiscordInbound` for `.slash` sends the defer **then** `MainActor.run { finishDiscordInbound }` with no generation and no drain snapshot. `finishDiscordInbound` reads `store.loadDiscordInboundCursor().drain` at completion time. `DiscordInboundGatewayClient.invalidate` bumps `generation` and cancels the socket, and `accepts(generation:)` guards `handleDiscordGatewayFrame`, but the deferred task never calls `accepts`. `noteMacDidWake` → `restartForWakeMiss` invalidates, then starts a wake-miss session. A defer that completes after that can observe `drain == .live` (if `RESUMED` / `READY` already seeded) and **apply** `/arm` or `/disarm`.
- **Why Telegram is different:** `finishTelegramInboundPoll` returns unless `inboundPoller.accepts(generation:)`. Drain uses `TelegramInboundDrain.effective`, so a stored wake-miss beats a stale in-flight snapshot.
- **Resume order (hypothesis):** `DiscordGatewaySession.handle` on `.inbound` uses `recording`, which keeps `wakeMiss` until `.ready` / `.resumed` call `acknowledging` (`seeded: true`, `wakeMiss: false`). If Discord ever delivers `RESUMED` before replayed `INTERACTION_CREATE`, those replays apply as live. Documented Gateway order is replay then `RESUMED`; this pass did not observe a live socket. Do not scrape channel history to “fix” that.
- **Next owner:** Swift. Capture generation + drain when the frame is accepted; drop the deferred finish if generation moved. Soft Mac Discord optical is still open — this is a code bug to fix later, not a request to run that optical tonight.

### B12 — Discord heartbeat ack is a cross-thread bool

- **Severity:** medium
- **Evidence:** confirmed from code.
- **Where:** `HeartbeatAck.ok` is a plain `var` on a class marked `@unchecked Sendable`. The receive loop sets `ack.ok = true` on the detached task (`runConnection`, before the main-actor hop). `startHeartbeat` reads and writes `ack.ok` inside `MainActor.run`. No lock.
- **User-facing:** a lost ack forces `reconnectSoon` and socket cancel (inbound dies until the 5s retry). A torn read is a data race. Not Mac-proven; the race does not need a Mac to be real.
- **Next owner:** Swift.

### B13 — `handleDiscordGatewayFrame` “same bot” check compares the token to itself

- **Severity:** low
- **Evidence:** confirmed from code.
- **Where:** `WatchRuntime.handleDiscordGatewayFrame` calls `DiscordInboundPolicy.sameBot(fetchedToken: secrets.discordBotToken, currentToken: secrets.discordBotToken)`. Telegram’s poll path passes the token captured when the request was built (`fetchedToken: token` in `finishTelegramInboundPoll`), so a token edit mid-flight is ignored. Discord does not. `setNotifDiscordBotToken` does `invalidate()` and bumps generation, which covers the live socket. The deferred slash path (B11) still finishes against whatever token is loaded later.
- **Next owner:** Swift, fold into the B11 fix. Do not log the token while touching this.

### B14 — Idle-after-wait UI says the watch ended while `SleepDisabled` is still on

- **Severity:** medium
- **Evidence:** confirmed from code for the state window (bounded by the POST, max about 3s plus main-thread lag). Copy vs kernel: confirmed.
- **Where:** `WatchEngine.disengage` sets `engaged = false` and `lastWatchEnd` before returning `.postIdleAfterWaitNotif`. `poll` sees the POST, applies only `.assertSleepDisabled` (which can **re-arm** the kernel via `armKernel`), starts the POST task, notifies the delegate, and returns. `shouldSkipPoll` is true while that POST is in flight and the engine is disengaged, so battery/thermal are not sampled again until `finishTickCommands`. The menu title goes to the off glyph and the Watch card can show last-end while the kernel flag is still on. The bar’s LPM sentence is the same honesty rule: do not show ended copy while a hold remains.
- **Next owner:** Swift (keep `engaged` or a “holding for POST” flag until `disarmKernel` succeeds). UI binds whatever the engine reports.

### B15 — `sleepnow` / `displaysleepnow` failures are discarded

- **Severity:** medium
- **Evidence:** confirmed from code. Whether they fail on a current macOS without sudo: **hypothesis — needs Mac measure**.
- **Where:** `PowerHygieneCoordinator` uses `_ = ProcessRunner.run` for both. Sudoers is only the two `disablesleep` lines. The bar says `sleepnow` is not a new sudoers grant, so a sudo failure would be the wrong fix if the console user can already run them. A non-zero exit today is indistinguishable from success. Power B can report “panel sleeps” after a failed `displaysleepnow`. Inbound `/disarm` can report `Disarmed.` after a failed `sleepnow` (`applyTelegramDisarm` does not read the exit).
- **Next owner:** Swift (return the exit to the caller and say so in the reply / a notification). User Mac measure: exit status of both commands as the logged-in user.

### B16 — Keyboard backlight writes three keys and ignores the IOKit result

- **Severity:** low
- **Evidence:** confirmed from code. Hardware effect is Mac-proven for the user’s optical on 2026-09-24 for “keyboard off,” not for every key name.
- **Where:** `KeyboardBacklightController.write` sets `KeyboardBacklightBrightness`, `KeyboardBacklightUserBrightness`, and `KeyboardBacklight` on every matching service. `IORegistryEntrySetCFProperty`’s result is ignored. Scales differ by board (0...1 vs a larger integer). A successful optical on one Mac does not prove the triple write is safe on another; a bad scale could restore the light to full on lid open.
- **Next owner:** user Mac measure if a machine mis-restores the keyboard. Swift only with a captured read/write pair that matches one key. Nil capture must keep skipping.

### B17 — 1 Hz popover timer fights in-progress edits and looks like a countdown

- **Severity:** low
- **Evidence:** confirmed from code.
- **Where:** `PopoverController.startCountdown` fires `refresh` every 1s while the popover is open. `refresh` writes slider values and caption text from preferences. `hintCopy` computes remaining seconds from `timerEnd` and `AgrypnosCopy.durationHint` drops them. Timed How long does not auto-off (`AutoOffEvaluator`).
- **User-facing:** no fake “1h left” string today (good). The timer still exists, so a later one-line copy change would start lying. Refresh during a drag resets control positions from the last saved value.
- **Next owner:** UI. Delete the timer. Do not wire `timerExpired` to turn the watch off.

### B18 — Secrets file is `0600`; the directory is not tightened

- **Severity:** low
- **Evidence:** confirmed from code.
- **Where:** `NotifSecretsStore.write` creates the Application Support directory with default attributes, writes a temp file at `0600`, `replaceItemAt`, then `setAttributes` `0600` on the final file. Contents are not world-readable if that second `setAttributes` runs. The directory can still be listed by the user account (normal). Tokens are not in `UserDefaults` (only Telegram offset / Discord resume cursor). `NSLog` in `GlobalHotkeyCenter` does not print secrets. Telegram comments say not to log the request URL because the token is in the path; `TelegramInboundHTTP.fetch` does not log it.
- **Not found:** plaintext secrets in prefs, a webhook used as inbound, or a listen socket.
- **Next owner:** Swift only if a review wants the directory at `0700` too. Not a leak by itself.

### B19 — Battery “on AC” is any non-discharging reading

- **Severity:** low
- **Evidence:** confirmed from code for the label. Real `pmset` strings beyond the two fixtures: **hypothesis — needs Mac measure**.
- **Where:** `WatchEngine.telegramWatchStatus` sets `liveBatteryDischarging` from `SafetyInputs.onBatteryDischarging` (`onBattery && discharging`). `TelegramWatchStatusCopy.batteryLine` prints `discharging` or `on AC`. On battery + `charged` (or any non-discharging state) becomes “on AC.” `BatteryStatusParser` tests cover a discharging battery and an AC `100%` charged line only. Percent parse uses `pmsetBatt.contains("\(value)%")`, which is true for a shorter number contained in a longer percent (`"15%".contains("5%")`). The fixtures (67, 100) do not hit that.
- **Next owner:** Swift if a captured `pmset -g batt` from the user’s Mac shows the wrong line. Do not invent a percent when parse fails (omit is correct).

### B20 — Grant dialog can re-enter `poll` from a timer

- **Severity:** low
- **Evidence:** confirmed from code structure.
- **Where:** `armKernel` calls `GrantInstaller.installViaNativeAuth`, which `runModal`s. `poll` → `tick` → `.assertSleepDisabled` → `apply` → `armKernel` when the kernel flag reads off. `runModal` spins the main run loop, so the 5s timer can enter `poll` again on top of the dialog. `start()` only happens once from `AppDelegate`. This is an edge (sudoers removed while armed), not the cold-launch path.
- **Next owner:** Swift. Don’t show a modal from the poll timer; coalesce `armKernel`.

## Open questions

1. B1: on this Mac, after popover off with the lid confirmed closed, is `SleepDisabled` 0 and is the machine still awake 30 seconds later? Power A and Power B separately.
2. B4: A↔B with the lid already confirmed closed — what does the panel actually do, and what happens on the next open?
3. B8: terminal-only Cursor session — does Keep the watch stay on? Does a home directory with many projects hit the 4000 cap and disarm early?
4. B11: can a slash `/disarm` deferred across sleep still `sleepnow` on wake? Code says yes if the cursor is seeded again before `finishDiscordInbound`. Live Gateway not run here.
5. B15: exit code of user-level `pmset displaysleepnow` and `pmset sleepnow` on the OS build you ship.

Discord inbound soft Mac optical (menu, `/help`, wake-miss, lid-open vs confirmed `/disarm`, webhook still outbound-only) is **not** done. Do not mark B11/B12 Mac-proven. Do not run that optical as part of this docs pass.

## Explicit

No code was changed. No Swift, tests, plist, `AGENTS.md`, `README.md`, or `SECURITY.md` edits.
