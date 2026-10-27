# Mac adapters

- verdict: HOLD
- blockers: 0
- high: 2
- scope: `WatchRuntime`, kernel readback, poll/disarm, lid sampling, `pmset` spawn, launch-at-login, hotkey bind, brightness and keyboard writers, inbound wake restart. Question end-vs-hold is Q. Core sleep policy that is already correct was not re-specified.

## Product promise

The Mac adapter runs the sleep, brightness, keyboard, and kernel actions Core already chose. User-off and inbound disarm run `pmset sleepnow` only when the confirmed-closed flag is set. Timer expiry sleeps unless the lid is known open. Safety and agents-settled run the sleep Core put in the command list. `displaysleepnow` is Power B on a confirmed close only. Launch at login does not arm. A hotkey that fails to bind shows up in the UI. One raw clamshell sample does not write brightness or sleep the panel. A nil brightness capture does not become a restore write. A poll that starts because the Mac woke drains without applying. `sleepnow` is not a sudoers command.

## Gates checked

| Gate | Result | Evidence |
|---|---|---|
| User-off and inbound disarm sleep only when the confirmed-closed flag is set, and the fresh read is still closed | PASS for the popover, hotkey, and bot paths | Flag is `lidCloseConfirmed && rawClosed` `Sources/AgrypnosCore/Session/WatchEngine.swift:16-17`. Popover/hotkey off and both bots call `disarmWatch` `Apps/Agrypnos/Sources/WatchRuntime.swift:363-393`, `Apps/Agrypnos/Sources/Notif/WatchRuntime+TelegramInbound.swift:157-160`, `Apps/Agrypnos/Sources/Notif/WatchRuntime+DiscordInbound.swift:224-226`. `applyUserOff` passes that flag into `userSetEngaged` `Apps/Agrypnos/Sources/WatchRuntime+Poll.swift:376-389`. The spawn then requires `readLid() == true` unless the batch is timer expiry `Apps/Agrypnos/Sources/Power/PowerHygieneCoordinator.swift:42-45` |
| Timer expiry sleeps unless the lid is known open. Nil still sleeps | PASS | `timerExpired` is set only when the batch contains `.disengage(.timerExpired)` `Apps/Agrypnos/Sources/WatchRuntime.swift:449-454`. Strip only when the read is `false` `Apps/Agrypnos/Sources/WatchRuntime+Poll.swift:326`. Spawn allows nil with `readLid() != false` `PowerHygieneCoordinator.swift:43`. Covered by `Tests/AgrypnosMacTests/TimedWatchRuntimeTests.swift:34-73` |
| Safety and agents-settled spawn the sleep Core asked for when the sensor still reads closed | PASS on a closed read | `disengage` appends `.requestSleep` when the lid was confirmed `Sources/AgrypnosCore/Session/WatchEngine.swift:363-366`. Poll keeps it when `readLid()` is `true` `WatchRuntime+Poll.swift:321-327`. Agents post then sleeps once `Tests/AgrypnosMacTests/DeferredSleepTests.swift:30-37` |
| `displaysleepnow` only for armed Power B on a confirmed close. Not on the Keep awake toggle. Not on an open lid | PASS | Arm passes `lidClosed: false` `WatchRuntime.swift:380`. One `observeLid` cannot confirm `Sources/AgrypnosCore/Power/LidCloseConfirm.swift:45-52`. Spawn requires `shouldSleepDisplay` and `readLid() == true` `PowerHygieneCoordinator.swift:46-51`. Floor and display sleep are different cases `:56-64` |
| Launch at login does not arm | PASS | Login item only registers `Apps/Agrypnos/Sources/Launch/LaunchAtLoginController.swift:9-14`. `start` does not call `setEngaged` `WatchRuntime.swift:123-140`. A held flag is cleared first; adopt runs only if the clear does not stick `WatchRuntime+Kernel.swift:81-110` |
| Hotkey bind failure is visible | PASS | Launch posts the unregistered hint `Apps/Agrypnos/Sources/AppDelegate.swift:27-30`. A failed remap keeps the previous chord, stores the attempt, and posts the hint `WatchRuntime.swift:308-328`, `Sources/AgrypnosCore/Hotkey/HotkeyBindPolicy.swift:46-69`, `Sources/AgrypnosCore/Copy/AgrypnosCopy.swift:80-87`. General paints that hint `Apps/Agrypnos/Sources/MenuBar/PopoverController.swift:214-224` |
| One raw closed sample does not write the floor or run `displaysleepnow` | PASS | `LidCloseConfirm.sample` confirms only after `pulseInterval` `LidCloseConfirm.swift:45-52`. Arm and leftover adopt pass `lidClosed: false` `WatchRuntime.swift:380`, `WatchRuntime+Kernel.swift:99` |
| Nil brightness capture does not become a restore write | PASS | Restore target is the capture `Sources/AgrypnosCore/Power/HygieneRestore.swift:18-20`. Ramp bails when that is nil `PowerHygieneCoordinator.swift:72-75`. Direct restore writes only `let captured` `:90-97`. `Tests/AgrypnosMacTests/HygieneTransitionTests.swift:60-69` |
| Wake restart drains without applying | PASS in code | `willSleep` stores wake-miss, `didWake` restarts both pollers into that session `WatchRuntime+TelegramInbound.swift:27-45`, `TelegramInboundPoller.swift:82-86`, `DiscordInboundGatewayClient.swift:36-40`. A stored wake-miss beats a live fetched cursor `Sources/AgrypnosCore/Notif/TelegramInboundPolish.swift:12-17`. A stale poll generation is dropped `WatchRuntime+TelegramInbound.swift:74` |
| Sudoers is the two `disablesleep` lines. `sleepnow` is not sudo. No arbitrary `pmset` shell | PASS | Grant text `Scripts/grant.sh:25`. Spawn is `sudo -n /usr/bin/pmset -a disablesleep` `SleepDisabledController.swift:20-25`. Crash helper is `disablesleep 0` only `Sources/AgrypnosCore/Power/KernelQuitPolicy.swift:16-19`. `sleepnow` and `displaysleepnow` are fixed argv with no sudo `PowerHygieneCoordinator.swift:44-50` |
| Lid-close hold is SleepDisabled, not an IOKit assertion | PASS | No `IOPMAssertion` under `Apps/Agrypnos`. Hold writes are `SleepDisabledController.set` |
| Quit with the lid confirmed closed still reaches `sleepnow` | FAIL | V1-MAC-01 |
| A `sleepnow` that does not sleep still restores captured brightness and keyboard | FAIL | V1-MAC-02 |
| An unavailable clamshell read is not an open edge | FAIL | V1-MAC-03 |

## Findings

### V1-MAC-01

- severity: HIGH
- confidence: high
- breaks: Confirmed-closed user-off runs `sleepnow`
- evidence: Quit calls `setEngaged(false)` and then `NSApp.terminate` on the same turn `Apps/Agrypnos/Sources/MenuBar/PopoverController.swift:508-512`. With Notif on, a Discord token and channel id, and a confirmed close, `shouldAwaitWatchEndPost` is true because `DiscordBotOutbound.body(.user, willSleep: true)` is non-nil `Sources/AgrypnosCore/Notif/DiscordBotOutbound.swift:17`, `WatchRuntime+Poll.swift:339-356`. `applyUserOff` only schedules `idlePostTask` and returns before `sleepnow` `WatchRuntime+Poll.swift:391-413`. `prepareForTermination` cancels that task `WatchRuntime+Kernel.swift:59-61` before the main-actor task can run. The engine is already disengaged, so the fallback `userSetEngaged(false, lidClosed: false)` at `:70-72` does not run. Kernel clear then `restoreHygiene` at `:63-75` runs with no `sleepnow`. The same hardcoded `lidClosed: false` is what a still-engaged terminate uses if the first kernel readback failed and quit continues.
- trigger: Lid confirmed closed, Notif on, Discord bot token and channel id saved. Press Quit. Same fallback if Quit runs while the watch is still engaged and terminate is what finishes the off.
- expected: Clear SleepDisabled and run `pmset sleepnow`, which is the user-off decision `applyUserOff` already computed.
- actual: The deferred sleep task is cancelled. SleepDisabled is cleared. Captured brightness and keyboard are restored. `sleepnow` is not spawned. The Mac stays awake.
- fix_files: `Apps/Agrypnos/Sources/WatchRuntime+Kernel.swift`, `Apps/Agrypnos/Sources/WatchRuntime+Poll.swift`
- fix: On terminate, if the in-flight user-off already decided to sleep, spawn that `sleepnow` after the kernel clear. If terminate itself disengages a watch that is still on, pass the live `userOffLidCloseConfirmed` result, and run the coordinator on those commands.
- test_first: Arm with two closed samples, Notif on, Discord token and channel id set, `setEngaged(false)`, then `prepareForTermination()`. Assert `sleepRequests == 1` and that the kernel was cleared. A second case with `lidClosed = false` asserts `sleepRequests == 0`.
- do_not: Do not `sleepnow` when the lid is open or unconfirmed. Do not sudo `sleepnow`. Do not skip the Discord send on a quit that is going to stay up long enough to send it; quitting may send and then sleep, or sleep without the send, and either way the confirmed-closed quit still calls `sleepnow`.

### V1-MAC-02

- severity: HIGH
- confidence: high
- breaks: Keyboard and brightness come back when the Mac did not sleep
- evidence: Every `sleepnow` exit is stored, including failure `PowerHygieneCoordinator.swift:42-45`, `Sources/AgrypnosCore/Power/PmsetCommandOutcome.swift:10-12`. The default runner deadline is 3 seconds, and a timeout returns `-2` after SIGKILL `Apps/Agrypnos/Sources/Support/ProcessRunner.swift:5`, `:32-47`. `finishDisengageHygiene` treats any non-nil `sleepnow` as a completed sleep and calls `dropSavedHygieneWithoutWrite` `WatchRuntime+Poll.swift:359-367`, `:486-491`. That drops the capture and clears `hygieneEffects`. The watch is already off, so a later lid-open has no restore to run. Callers are the sync user-off `:415-416`, the post completion `:407-408`, poll disengage `:331-334`, and the question-notice completion `:305-306`. The user-visible failure string is separate and does not restore `PmsetCommandOutcome.swift:24-27`, `WatchRuntime.swift:469-470`.
- trigger: Confirmed-closed user-off, timer expiry, safety, or agents-settled asks for `sleepnow`, and `/usr/bin/pmset sleepnow` exits non-zero or the 3-second runner kills it.
- expected: Leave SleepDisabled clear, keep the Mac awake, and write the captured brightness and keyboard back.
- actual: The capture is discarded. The panel stays at the floor if a floor was applied. The keyboard stays at 0 if it was turned off. Nothing later writes the captured values.
- fix_files: `Apps/Agrypnos/Sources/WatchRuntime+Poll.swift`
- fix: Call `dropSavedHygieneWithoutWrite` only when `sleepnow` is `.ok`. On `.failed`, call `restoreHygiene` so the captured values are written, then clear them.
- test_first: Set `savedBrightness` and `savedKeyboard`, set `hygieneEffects.floor` and `hygieneEffects.keyboard`, and make `runCommand` return exit 1 for `sleepnow`. Drive `finishDisengageHygiene`. Assert the brightness writer received the capture, the keyboard writer received the capture, and the floor was not written again.
- do_not: Do not restore on a zero exit; that turns the panel and keyboard back on as the Mac goes to sleep. Do not write the floor when the capture is nil.

### V1-MAC-03

- severity: MEDIUM
- confidence: high
- breaks: An unavailable clamshell sample must not undo a confirmed close or drop a safety or agents sleep Core already emitted
- evidence: `LidStateReader.closedState()` is `Bool?` so a missing sensor stays unavailable `Apps/Agrypnos/Sources/Power/MachineSensors.swift:12-28`. `pollLid` turns nil into open with `readLid() == true` and feeds that to `observeLid` `WatchRuntime+Lid.swift:17-20`. `observeLid(false)` takes the open edge and returns lid-open restore `Sources/AgrypnosCore/Session/WatchEngine.swift:257-268`, `Sources/AgrypnosCore/Power/LidCloseConfirm.swift:54-58`. The same collapse is in the agents post re-check `WatchRuntime+Poll.swift:321-324`. For battery, thermal, Low Power Mode, and agents when that hold branch is false, nil fails `rawClosed != true` and the `requestSleep` Core appended is removed `:326-327`. Timer expiry does not do this: it strips only `rawClosed == false` `:326`, and the spawn allows nil `PowerHygieneCoordinator.swift:43`.
- trigger: Keep awake is on, the lid is already confirmed closed, and one poll gets nil from `AppleClamshellState` (registry service missing or the property missing). For the sleep half: Core has already appended `.requestSleep` for battery, thermal, Low Power Mode, or agents-settled, and the read in `removeSleepIfLidOpen` is nil.
- expected: Ignore that sample. Leave the confirmed-closed flag set. Do not ramp brightness, do not turn the keyboard on, do not pulse the panel awake. If Core's command is still `.requestSleep` and this is not a known-open lid, spawn `sleepnow`.
- actual: The engine records an open edge. Power A starts the brightness ramp toward the capture. Power B runs the panel-wake pulse. The confirmed flag clears. A safety or agents `.requestSleep` is removed whenever the fresh read is nil, so that sleep is not spawned. The next closed sample has to confirm again before hygiene returns.
- fix_files: `Apps/Agrypnos/Sources/WatchRuntime+Lid.swift`, `Apps/Agrypnos/Sources/WatchRuntime+Poll.swift`
- fix: If `readLid()` is nil, skip `observeLid` and skip the agents-hold re-sample. In `removeSleepIfLidOpen`, remove safety and agents `.requestSleep` only when the read is `false`. Leave the timer comparison as it is.
- test_first: Confirm the lid with two closed samples, set `lidUnknown = true`, call `pollLid`. Assert `lidCloseConfirmed` stays true and the brightness writer was not called. Then emit a battery disengage that contains `.requestSleep` with `lidUnknown` still true and assert `sleepRequests == 1`. A `lidClosed = false` case asserts `sleepRequests == 0`.
- do_not: Do not make user-off or inbound disarm sleep on nil. Do not make timer expiry stop sleeping on nil. Do not treat one raw closed sample as a new confirm.

## Handoffs

- Q: Whether an unanswered question ends the watch. `QuestionTimeoutRuntimeTests` stays engaged and never emits `.requestSleep` on those ticks. That choice is `questionWaitPolicy`. The adapter sleeps a `.questionUnanswered` command only after a fresh 0.25s confirm `WatchRuntime+Poll.swift:279-306`. This pass did not re-specify that policy.
- WE, PW, SF, AG, TG, DC: no handoff. The engine's reason-to-`requestSleep` split matches the matrix, and the wake cursors are consumed as wake-miss when `willSleep` / `didWake` run.

## Needs a Mac

- Quit with the lid confirmed closed and Discord watch-end send configured: SleepDisabled clears and the Mac sleeps. Quit with the lid open: the watch turns off and the Mac stays awake.
- Confirmed-closed off whose `pmset sleepnow` exits non-zero: brightness and keyboard return to the captured values. A zero exit leaves them alone and the Mac sleeps.
- One missing `AppleClamshellState` read while the lid is confirmed closed does not ramp the panel or wake it.
- Power A confirmed close writes the floor on the built-in panel only. Lid open ramps to the capture. Nil capture writes nothing. `DisplayServices` and the keyboard registry were not called in this pass.
- Power B confirmed close runs `displaysleepnow` and does not run it when Keep awake is turned on with the lid open. Lid open turns the keyboard backlight back on.
- `pmset sleepnow` and `displaysleepnow` exit times. The runner kills them at 3 seconds `ProcessRunner.swift:32-43`. This pass did not time a real `pmset`.
- Launch at login after reboot: watch stays off and SleepDisabled stays clear.
- Hotkey conflict: General shows the chord is not registered.
- Sleep, then a `/disarm` that arrived while asleep: on wake the reply is missed-while-asleep and Keep awake does not change.

## Unproven

- This pass did not run `swift test` or `xcodebuild`. Gate results are from the source and the existing Mac tests, not from a run tonight.
- No live IOKit return. Whether a closed MacBook ever yields a nil `AppleClamshellState`, which display id `CGDisplayIsBuiltin` picks, and whether the keyboard properties round-trip the value `current()` read are open. `KeyboardBacklightController.swift:25-31` and `:54-58` write every matching service and every listed key; a restore that writes the captured number and still leaves the keys dark would be a property-unit miss this pass cannot see.
- `ProcessRunner` waits on `waitUntilExit` after SIGKILL with no second deadline `ProcessRunner.swift:37-43`, on the main actor. `Tests/AgrypnosMacTests/ProcessRunnerTests.swift:4-9` and `:22-25` show `/bin/sleep` is reaped. A `pmset` stuck in uninterruptible sleep was not observed.
- `NSWorkspace` `willSleep` / `didWake` delivery was not observed. The wake-miss classification above assumes those notifications run. A gateway resume that seeds live before replayed dispatches would be a Core session-order bug; `DiscordGatewaySession.swift:40-55` records inbound before `RESUMED` acknowledges.
