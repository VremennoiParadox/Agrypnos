# Fix 4 — V1-MAC-01

STATUS: DONE

Quit with the lid confirmed closed now runs one `sleepnow` after SleepDisabled is cleared. A Discord user-off still schedules the send. If that send is still in flight when quit runs, quit cancels the wait and spawns the sleep the user-off already chose. If the send finishes first, that path still sleeps and quit does not sleep a second time. An open lid does not sleep. `sleepnow` is still `/usr/bin/pmset sleepnow` with no sudo.

No commit. Fixes 1–3 are still in the working tree. Fix 5 was not started.

## What changed

`applyUserOff` remembers `userOffSleepDecided` when it defers for a watch-end send that will sleep. The task clears that flag only when it is about to apply the sleep itself. A new arm, a failed wake-hold reassertion, and an immediate user-off that is not waiting on a send clear the flag.

`prepareForTermination` reads the flag, then cancels the send task, then clears the kernel. After that clear:

- If the watch is still armed, it turns Keep awake off with the live `userOffLidCloseConfirmed` result. A failed kernel clear passes false, so that path does not sleep.
- If the deferred user-off already decided to sleep, the kernel clear succeeded, and the lid is still confirmed closed, it applies `[.requestSleep]`.

Either sleep goes through `apply` / `PowerHygieneCoordinator` and then `finishDisengageHygiene`. No second sleep policy. No sudo.

`ownsWakeHold` is settable inside the module so the test can enter `prepareForTermination` without `SleepDisabledCrashGuard.start()`. That start takes the real wake-owner lock and would launch the sudo cleanup helper.

## Files

- `Apps/Agrypnos/Sources/WatchRuntime+Poll.swift` — set and clear `userOffSleepDecided` in `applyUserOff`.
- `Apps/Agrypnos/Sources/WatchRuntime+Kernel.swift` — `prepareForTermination` only. The will-sleep observer in this file is Fix 2 and was not edited.
- `Apps/Agrypnos/Sources/WatchRuntime.swift` — the flag, the test seam on `ownsWakeHold`, and the two cancels that retire the decision.
- `Tests/AgrypnosMacTests/TimedWatchRuntimeTests.swift`

Not touched: `PopoverController.quitApp`, sudoers, `finishDisengageHygiene`'s failed-exit rule, Power B, lid debounce.

## Tests

`testQuitAfterConfirmedClosedDiscordUserOffSleepsOnceAndClearsKernel`

Two closed samples, Notif on, Discord token and channel id. `setEngaged(false)` leaves the send task scheduled, zero `sleepnow`, kernel still held. `prepareForTermination()` then does one `sleepnow` and clears the kernel. After the cancelled send is drained, the count is still one.

`testQuitAfterOpenLidUserOffRequestsNoSleep`

Same Notif and Discord secrets, `lidClosed = false`. Zero sleep requests.

`testTerminateWhileStillArmedSleepsOnlyWhenLidIsConfirmedClosed`

Terminate while the watch is still on. Confirmed closed: one `sleepnow`, kernel clear. Open lid: zero.

`testTerminateWhileStillArmedDoesNotSleepWhenKernelClearFails`

Confirmed closed, kernel write fails. Zero `sleepnow`, kernel stays held.

The existing Discord user-off test still sends, then sleeps once, when quit is not called.

## Red, then green

Red, before the terminate sleep:

```
swift test --filter 'testQuitAfterConfirmedClosedDiscordUserOffSleepsOnceAndClearsKernel|testQuitAfterOpenLidUserOffRequestsNoSleep|testTerminateWhileStillArmedSleepsOnlyWhenLidIsConfirmedClosed'
```

2026-10-27 17:16:35. Exit 1. 3 tests, 3 failures. The confirmed-closed Discord quit asserted `sleepRequests` 0 not 1, both right after terminate and after the send drained. The kernel had already cleared. The still-armed confirmed close asserted 0 not 1. The open-lid quit passed.

Red, after that sleep existed but a failed kernel clear on a still-armed terminate still slept:

```
swift test --filter testTerminateWhileStillArmedDoesNotSleepWhenKernelClearFails
```

2026-10-27 17:20:44. Exit 1. 1 test, 1 failure. `sleepRequests` was 1.

Green, after the last edit:

```
swift test --filter 'testQuitAfterConfirmedClosedDiscordUserOffSleepsOnceAndClearsKernel|testQuitAfterOpenLidUserOffRequestsNoSleep|testTerminateWhileStillArmedSleepsOnlyWhenLidIsConfirmedClosed|testTerminateWhileStillArmedDoesNotSleepWhenKernelClearFails|testUserOffPostsDiscordSleepSentenceOnlyWhenLidIsConfirmedClosed|testUserOffDoesNotSleepOnUnconfirmedRecloseDuringPost|testUserOffWaitFailedKernelClearDoesNotClaimWatchUnchanged'
```

2026-10-27 17:21:46. Exit 0. 7 tests, 0 failures.

## Concerns

- The open-lid quit test passed before the fix. It guards the new path. The two closed-lid failures are what showed the bug.
- A real Quit on a closed-lid Mac was not run. The count is the fixture's `runCommand`, not `/usr/bin/pmset`.
- Quit still cancels `idlePostTask`. The fixture shows that post still starts if the process stays up, and `sleepnow` is one either way. A quit that exits inside `applicationWillTerminate` can sleep before the Discord HTTP send finishes. The non-quit user-off still sends, then sleeps.
- `finishDisengageHygiene` still drops the saved brightness and keyboard whenever `sleepnow` is non-nil, including a non-zero exit. That is Fix 5. This fix did not change that check.
- If SleepDisabled already reads clear, `prepareForTermination` returns before the deferred sleep. The Discord user-off leaves it held, which is the bug path. That already-clear return is not a separate test.
- One raw closed sample is not its own quit test. `lidClosed = false` is the open case. The flag is set only from `userOffLidCloseConfirmed`, which needs the stable confirm.
- `ownsWakeHold` can now be set from the Mac module. Production still sets it only in `start()`.
- The full `swift test` suite was not run.
