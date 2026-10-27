# Fix 6 — V1-MAC-03

STATUS: DONE

A nil clamshell read no longer counts as open in `pollLid`, and it no longer strips a safety or agents `.requestSleep`. Timer expiry still sleeps on nil. User-off still does not. One raw closed sample is still not a new confirm. `finishDisengageHygiene` was not edited.

No commit. Fixes 1–5 are still in the working tree. Fix 7 was not started.

## What changed

`pollLid` used `readLid() == true`, so nil became open and `observeLid(false)` cleared a confirmed close. A nil read now returns before `observeLid` and before the open-brightness recapture.

`removeSleepIfLidOpen` removed safety and agents `.requestSleep` when `rawClosed != true`, which is also nil. That removal is now `rawClosed == false`. Timer expiry was already `rawClosed == false`; it shares that check and still sleeps when the read is nil. The agents-hold re-sample skips a nil read and does not pass it to `observeLid`. A true read on that path still has to be confirmed. One raw closed sample does not keep the sleep.

Keeping the command was not enough to spawn `sleepnow`. `PowerHygieneCoordinator` still required `readLid() == true` for every non-timer sleep, so a nil battery read never reached `pmset`. Timer, battery, thermal, Low Power Mode, and agents now sleep unless the read is `false`. User-off, a bare `.requestSleep`, and an unanswered-question sleep still require a closed read.

The user-off branch in `removeSleepIfLidOpen` is unchanged. A nil read there is still not confirmed, so the sleep command is removed.

## Files

- `Apps/Agrypnos/Sources/WatchRuntime+Lid.swift` — `pollLid` returns when `readLid()` is nil.
- `Apps/Agrypnos/Sources/WatchRuntime+Poll.swift` — safety and agents drop `.requestSleep` only for a `false` read. The agents-hold re-sample skips nil.
- `Apps/Agrypnos/Sources/Power/PowerHygieneCoordinator.swift` — nil can spawn `sleepnow` for timer, safety, and agents. User-off still needs a closed read.
- `Tests/AgrypnosMacTests/NilLidRuntimeTests.swift` — the five cases below.

Not touched: `finishDisengageHygiene`, lid confirm, floor write, Power B wake, sudoers.

## Tests

`testNilLidPollKeepsConfirmedCloseAndSkipsBrightnessWrite`

Two closed samples confirm the lid. The next read is nil. `pollLid` leaves `lidCloseConfirmed` true. The brightness writer is not called.

`testNilLidBatteryDisengageStillRequestsSleep`

Confirmed close, then a battery disengage whose commands include `.requestSleep`, read still nil. One `sleepnow`.

`testOpenLidBatteryDisengageDoesNotRequestSleep`

Same battery path with the read `false`. Zero sleep requests.

`testNilLidUserOffDoesNotRequestSleep`

Confirmed close, then Keep awake off while the read is nil. Zero sleep requests. Inbound `/disarm` uses this same `disarmWatch` path.

`testUnknownLidAtTimerExpiryStillRequestsSleep`

Timer expiry with a nil read. One `sleepnow`.

## Red, then green

Red, before the production edit:

```
swift test --filter 'NilLidRuntimeTests'
```

2026-10-27 18:41:36. Exit 1. 4 tests, 3 failures.

`testNilLidPollKeepsConfirmedCloseAndSkipsBrightnessWrite` failed both asserts: the confirmed flag was cleared, and the brightness writer was called.

`testNilLidBatteryDisengageStillRequestsSleep` failed: `("0") is not equal to ("1")`.

`testOpenLidBatteryDisengageDoesNotRequestSleep` and `testUnknownLidAtTimerExpiryStillRequestsSleep` already passed. Those two were existing behavior.

After `pollLid` and `removeSleepIfLidOpen` only, the poll test passed and the battery test still failed the same `0 != 1`. The spawn gate was still `readLid() == true`.

Green:

```
swift test --filter 'NilLidRuntimeTests'
```

2026-10-27 18:43:44. Exit 0. 5 tests, 0 failures.

Neighboring runtime tests, same tree:

```
swift test --filter 'NilLidRuntimeTests|TimedWatchRuntimeTests|HygieneTransitionTests|RuntimeRaceTests|QuestionTimeoutRuntimeTests|DeferredSleepTests'
```

2026-10-27 18:44:50. Exit 0. 49 tests, 0 failures.

## Concerns

- The plan named two call sites. The battery assertion also needed the spawn check in `PowerHygieneCoordinator`. Without that, a kept `.requestSleep` still does not call `sleepnow` when the read is nil.
- Thermal, Low Power Mode, and agents use that same spawn list. Only battery has a new nil assertion. Agents-hold nil is the `if let closed` skip; it is not its own test. A true read there still requires `userOffLidCloseConfirmed`, so one raw reclose does not sleep.
- The user-off branch still calls `observeLid(closed: rawClosed == true)`. Nil becomes false there, the result is discarded, and the sleep is removed. That is the no-sleep path. It does not ramp brightness.
- `testNilLidUserOffDoesNotRequestSleep` calls `setEngaged(false)`, which is `disarmWatch`. It does not send a Telegram or Discord update.
- The count is the fixture's `runCommand`, not `/usr/bin/pmset`. No live `AppleClamshellState` nil was read.
- Compiling `WatchRuntime+Poll.swift` still prints the existing Sendable warning at line 94. This edit did not add it.
