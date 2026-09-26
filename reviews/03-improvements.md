# Potential improvements

Date: 2026-09-26  
Branch: `cursor/overnight-review-docs-12fc`  
Base: `main` @ `54d0ad7` (Honesty: Discord inbound UI landed / not Mac-proven)  
**NOT FOR MERGE — review docs only**

Prioritized product and engineering follow-ups. This is not a build list for tonight. Ponytail tags mark deletions. Nothing here authorizes new product surface (Notification Center, enriched status, a shared bot, Wi-Fi/Bluetooth kill, a settings window, Licence/About).

No code was changed.

## Scope / method

Same tree as the other two notes: `Apps/Agrypnos/Sources/`, `Sources/AgrypnosCore/`, `Tests/AgrypnosCoreTests/`. Improvements are tied to symbols that already exist. Watt items are mechanisms only; see `reviews/01-performance-wattage.md`. Breakages are not repeated in full; see `reviews/02-bugs.md`.

Parked on purpose, **do not implement from this note:**

- **Discord-unify** — user held. Leave Telegram and Discord as two adapters on one `WatchEngine.applyInbound`.
- **Soft Mac Discord optical** — still open. Core + UI are landed. Do not claim Mac-proven. Do not schedule the optical as engineering work in this docs pass.
- **Enriched-status B** (task text / finish ETA) — scrapped. Review blocks it.
- **Notification Center as Notif** — V2 park. Do not unlock.
- **Donate** — no control until there is a live URL.

## Executive summary

The next useful work is subtraction and one Rules decision, not a new feature.

1. Stop doing work when the watch is off (probe, countdown timer, dead `timerEnd` plumbing).
2. Rules must answer two conflicts the code cannot honestly satisfy at once: popover/hotkey user-off vs `sleepnow` when the lid is already shut, and whether Cursor terminal files are a busy signal.
3. Fix the Discord defer/generation hole when someone next touches inbound. Do not unify Discord with Telegram while doing it.
4. Split or shrink files that are sitting on the 600-line wall before the next feature.

No code was changed.

## Priority

| ID | Severity | Item | Owner |
|---|---|---|---|
| I1 | high | Idle probe and main-thread walk | Swift |
| I2 | high | Rules: user-off + already-closed lid | Rules, then Swift, then user Mac measure |
| I3 | high | Rules: Cursor terminals as busy | Rules, then Swift |
| I4 | high | Re-apply or refuse A↔B while hygiene is active | Swift, user Mac measure |
| I5 | medium | Watch/tooltip copy must follow Power A/B | UI |
| I6 | medium | Discord defer must honor generation and drain | Swift |
| I7 | medium | Delete the 1 Hz countdown and the dead auto-off timer | UI + Swift |
| I8 | medium | Cache DisplayServices symbols; don’t `dlopen` per ramp frame | Swift |
| I9 | low | Delete or quarantine dead helpers | Swift |
| I10 | low | File-size wall | Swift / UI |
| I11 | — | Parked. Do not do. | — |

## Findings

### I1 — Do less when the watch cannot change

- **Severity:** high
- **Evidence:** confirmed from code (`WatchRuntime.poll`, `AgentProbeService.snapshot`).
- **Change:** if `!engaged` and How long is not about to be read, skip `ps`, the file walk, and the second `pmset -g`. Keep one cheap way to notice leftover `SleepDisabled` (that read can be much slower than 5s). Run the walk only in `.untilAgentsSettle`, only for `includedAgentKinds`, off the main actor. `/status` should reuse the last snapshot when it is younger than one poll, not walk again on the main actor.
- **Why:** this is the whole-life energy cost of a menu extra that is supposed to be quiet when the watch is off. Launch-at-login must stay disarmed; it should also stay cheap.
- **Ponytail:** the snapshot call sitting above `tick`’s `guard engaged` is the smell. Tag: `delete-work`.
- **Next owner:** Swift. Measure on a Mac after, not before, and do not publish a watt number you did not take.

### I2 — One sentence from Rules on user-off with the lid confirmed closed

- **Severity:** high
- **Evidence:** confirmed conflict. `WatchEngine.disengage` sleeps the Mac only for non-user reasons. `WatchCommand.requestSleep` says a closed lid will not sleep just because `SleepDisabled` dropped. The bar says inbound `/disarm` is the `sleepnow` path, and also says turning the watch off lets the machine sleep. Detail: `reviews/02-bugs.md` B1.
- **Change (after Rules, not tonight):** either popover/hotkey user-off with `lidCloseConfirmed` may `sleepnow` (same predicate as inbound, still never on open or unconfirmed), or the product copy must say that turning the watch off with the lid already shut does not itself sleep the Mac. Do not do both stories.
- **Also:** do not restore keyboard or brightness while the lid is still confirmed closed if the next command is sleep. Restoring and then sleeping fights the floor / keyboard-off work. Nil capture keeps skipping. Power B must not grow a floor write on that path.
- **Ponytail:** one sleep predicate, shared by inbound and by safety auto-off. User-off joins it only if Rules say so. Tag: `one-predicate`.
- **Next owner:** Rules. Then Swift. Then user Mac measure (asleep or not, Power A and Power B).

### I3 — Terminals are a product decision, not a drive-by delete

- **Severity:** high
- **Evidence:** confirmed. Tests require Cursor `terminals/*.txt` to be relevant. The bar’s agent sentence names process + transcript mtimes and `subagents/*.jsonl`, not shells. Detail: B8 and W5.
- **Change:** Rules pick one. If terminals are in, put one plain sentence in the Agents help so “local busy signals” includes IDE terminal files. If they are out, delete that branch in `isRelevantFile` and the walk root, and fix `testCursorTerminalsAreRelevantAndNoiseIsNot`. Do not also widen providers.
- **With that:** cap the walk by newest mtime or stop walking once a fresh file is found for each selected tool. A 4000-file silent truncate is how a real agent looks idle.
- **OpenCode CPU:** tests and `cpuCountsTowardBusy` include OpenCode; the bar does not. Same Rules pass. Tag: `yagni` until Rules say CPU is part of OpenCode.
- **Next owner:** Rules, then Swift.

### I4 — Panel mode changes should match the panel

- **Severity:** high
- **Evidence:** confirmed that `setPanelPowerMode` only saves. Detail: B4 / W10.
- **Change:** if the watch is armed and lid-close is confirmed, switching mode emits the new mode’s lid-close command and cancels the other (floor write **or** `displaysleepnow`, never both). If the lid is open, do nothing physical — that part is already correct. Hide ramp chrome in B stays as it is.
- **Next owner:** Swift. User Mac measure the closed-lid switch and the following lid-open. Do not claim the result until that look.

### I5 — One caption path for Power A and Power B

- **Severity:** medium
- **Evidence:** confirmed. `AgrypnosCopy.watchCaption` and `menuTooltip*` never take `PanelPowerMode`. `PanelPowerChrome` already has the right sentences.
- **Change:** Watch armed/waiting and lid-closed captions, leftover notification, and the status tooltip should use the same facts as `PanelPowerChrome.caption`. Power A: floor + keyboard off, panel stays on. Power B: panel sleeps, Keep the watch still holds the Mac awake, keyboard off. No watt words. No “Mac asleep.”
- **Ponytail:** stop maintaining a second copy of lid-close behavior in `AgrypnosCopy` that cannot see the mode. Tag: `one-caption`.
- **Next owner:** UI.

### I6 — Discord inbound: fix the hole, do not merge the transports

- **Severity:** medium
- **Evidence:** confirmed. Detail: B11, B12, B13.
- **Change:** `finishDiscordInbound` must no-op unless `discordGateway.accepts(generation:)` and the drain captured at receive time still says `.live`. Heartbeat ack needs one isolation domain (actor or lock), not a class `Bool`. Pass the token that opened the socket into `sameBot`, the way Telegram passes `fetchedToken`.
- **Do not:** unify Gateway with `getUpdates`, set an Interactions Endpoint URL, open a port, or scrape history on wake. Discord-unify stays parked (I11). Soft Mac optical stays the user’s check, later.
- **Ponytail:** `DiscordInboundPolicy.sameBot(token, token)` is dead logic. Tag: `delete-fake-check`.
- **Next owner:** Swift.

### I7 — Delete the countdown that does not count

- **Severity:** medium
- **Evidence:** confirmed. `PopoverController.startCountdown` (1s) calls `refresh`. `AgrypnosCopy.durationHint` and `StatusItemChrome.make` both discard remaining seconds. `AutoOffEvaluator` discards `timerEnd`. `DisengageReason.timerExpired.turnsWatchOff` is false. Copy still has `timerEnded` (“Timer ended. Watch turned off.”) for a reason the engine cannot emit.
- **Change:** remove `countdown`, `startCountdown`, and `hintCopy`’s `timerEnd` math. Keep How long as a remembered label (`∞` / `1h` / `3h` / custom / Agents). A later deletion of `timerEnd`, `WatchMode.timed`, and `.timerExpired` is safe only after tests that assert “remembered, does not auto-off” still exist. Do not implement auto-off for those presets.
- **Ponytail:** tag `delete-timer`. The 1 Hz timer is how a fake countdown would sneak back.
- **Next owner:** UI first (the timer is the live cost). Swift for the dead reason once tests are pointed at “never emits `.timerExpired`.”

### I8 — Brightness writes should look up DisplayServices once

- **Severity:** medium
- **Evidence:** confirmed. `BrightnessFloorController.load` `dlopen`s on every get and set. Ramp is 30 Hz.
- **Change:** resolve `DisplayServicesGetBrightness` / `SetBrightness` once. Keep the ramp durations 1/2/3s. Do not add a second brightness API. Do not write while the lid is open except the captured restore.
- **Also small:** `applyBrightnessFloor` should not `max` the saved capture up to the floor (B7). Restore the captured number. Nil still skips.
- **Ponytail:** tag `cache-symbol`.
- **Next owner:** Swift.

### I9 — Dead or sideways helpers

- **Severity:** low
- **Evidence:** confirmed unused or overlapping. Not a behavior bug until someone calls them.
- **Where:**
  - `BrightnessFloorController.applyFloor` and `restoreAtLeastFloor` — coordinator uses `set` and `HygieneRestore` instead. `applyFloor` uses `current() ?? 0`, which is a guess write the bar forbids if it ever gets called.
  - `PreferencesStore.save` writes the JSON blob **and** a loose `batteryFloorPercent` key. Readers use the blob.
  - `StatusItemController.refresh` runs `pmset -g batt` on every delegate ping, including the 5s poll that already read the battery.
  - `AgrypnosCopy.commandsHelp` on Telegram still says “arm, disarm, status” without `/help` (`TelegramInboundCopy.commandsHelp`). The landed `/help` string is `TelegramInboundCopy.help`. The short constant looks stale.
- **Ponytail:** tag `delete-helper` for `applyFloor` / `restoreAtLeastFloor` if grep shows no caller outside the type. Tag `one-read` for battery: poll stores `BatteryReading`, the status item consumes it.
- **Next owner:** Swift / UI. Grep before deleting; this pass did not see UI call sites for `applyFloor`.

### I10 — Line count before the next feature

- **Severity:** low
- **Evidence:** `wc -l` on this tree. The bar is 600, prefer ~250. These review files are exempt. Product files are not.
- **At the wall:** `Tests/AgrypnosCoreTests/PopoverSettingsChromeTests.swift` is 600 lines. `AgrypnosCopyTests.swift` is 572. `WatchRuntime.swift` is 517. `PopoverController.swift` is 484. `TelegramInboundTests.swift` is 504. `NotifIdlePostTests.swift` is 513.
- **Change:** the next person who adds a Notif or popover case splits first. `WatchRuntime`’s inbound extensions are already split (`WatchRuntime+TelegramInbound`, `WatchRuntime+DiscordInbound`); the remaining weight is `poll` / kernel / hygiene. Do not extract a second `AppDelegate`.
- **Ponytail:** tag `split-before-feature`. No split in this docs pass.
- **Next owner:** whoever touches those files next.

### I11 — Parked (do not recommend, do not start)

| Item | Why it stays parked |
|---|---|
| Discord-unify | User held. One `applyInbound` is enough. Two transports stay. |
| Soft Mac Discord optical | User’s Mac, later. Landed Core + UI. Not Mac-proven. Wake-miss, `/help`, lid-open vs confirmed `/disarm`, webhook outbound-only. |
| Enriched-status B | Scrapped. No task text, no finish ETA, no countdown on remembered How long. |
| Notification Center | V2 park. Notif stays POST + inbound bots. |
| More agent providers / think-detection | Out of V1. Cursor, Claude Code, Codex, OpenCode only. |
| Watt marketing, Wi-Fi/Bluetooth kill, settings window, Licence/About, donate | Bar. |
| Sudoers lines for `sleepnow` / `displaysleepnow` | Bar: not a new grant. If those commands fail, say so (B15); do not widen sudoers in the same breath. |
| M2-only lid or brightness branches | Forbidden. |

## Smaller product notes (not a roadmap)

- **Agents help** already says local process and session activity, and denies “still thinking.” If I3 keeps terminals, that help is the place to say so in one clause. If I3 drops them, do not mention terminals.
- **Last-end honesty** is in good shape (real `DisengageReason` + time, no log). Do not add a history list.
- **Per-tool include** is landed and should not grow a “track all” switch. Default all four, reject empty. That part does not need a project.
- **Section switch animation** (0.25s, no cross-paint, height hug) is implemented in `PopoverController.applySection` and was Mac-proven earlier. Do not reopen it unless a regression shows up.
- **Hotkey** surfaces bind failure (`NSLog` plus hint). No change needed for honesty. Carbon `InstallEventHandler` on every successful `register` is fine because `unregister` removes the previous handler.

## Open questions

1. I2: does Rules want popover/hotkey user-off, lid confirmed closed, to `sleepnow`? Yes or no. The code cannot imply both.
2. I3: are Cursor integrated-terminal files a busy signal on purpose? Tests say yes. The bar does not name them.
3. I3b: is OpenCode CPU-only busy on purpose? Tests say yes. The bar says session files.
4. After I1, what is idle energy with the watch off? Still unmeasured. Do not fill in a number in `AGENTS.md`.

## Explicit

No code was changed. No product file was edited. Discord-unify was not designed. Soft Mac Discord was not marked proven. Enriched-status B was not revived.
