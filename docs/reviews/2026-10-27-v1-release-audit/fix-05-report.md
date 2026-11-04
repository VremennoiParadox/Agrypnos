# Fix 5 — V1-MAC-02

STATUS: DONE

A failed `pmset sleepnow` now restores the captured brightness and keyboard. `dropSavedHygieneWithoutWrite` runs only when `sleepnow == .ok`. A zero exit still drops the restore. SleepDisabled is left as the caller cleared it. `finishDisengageHygiene` does not run `sleepnow` again.

No commit. Fixes 1–4 are still in the working tree. Fix 6 was not started.

## What changed

`finishDisengageHygiene` used `sleepResult.sleepnow != nil`, so every stored exit, including `1` and the runner's `-2`, discarded the capture. The condition is now `sleepResult.sleepnow == .ok`.

`.failed` and a nil `sleepnow` both take the existing else: `restoreHygiene()`, and Power B `wakeDisplay` when the lid read is not closed. `restoreHygiene` still writes a brightness only when the capture is non-nil. There is no floor fallback.

Callers were checked before the edit. `finishQuestionUnanswered`, `applyPreparedDisengage`, both `applyUserOff` paths, and both quit sleeps in `prepareForTermination` all pass their `HygieneApplyResult` into this function. The quit flag `userOffSleepDecided` was not edited. `prepareForTermination` still enters this function whenever `sleepnow != nil`, including a failure, and then returns.

## Files

- `Apps/Agrypnos/Sources/WatchRuntime+Poll.swift` — one condition in `finishDisengageHygiene`.
- `Tests/AgrypnosMacTests/HygieneTransitionTests.swift` — `testFailedSleepnowRestoresCapturedBrightnessAndKeyboard`.
- `Tests/AgrypnosMacTests/RuntimeFixture.swift` — `sleepExit`, default `0`, so `sleepnow` can return a non-zero exit. Other tests still get `0`.

Not touched: `userOffSleepDecided`, `prepareForTermination`, `PowerHygieneCoordinator`, `HygieneRestore`, sudoers, lid confirm.

## Tests

`testFailedSleepnowRestoresCapturedBrightnessAndKeyboard`

Saved brightness `0.8`, saved keyboard `0.6`, floor and keyboard effect flags set, kernel already clear. `runCommand` returns exit `1` for `sleepnow`. `apply([.requestSleep])` then `finishDisengageHygiene`. The brightness writer got `[0.8]`, the keyboard writer got `[0.6]`, the floor `0.15` was not written, `sleepRequests` did not grow, and the kernel stayed clear.

The same test then sets the captures and flags again with exit `0`. Writers stay empty. Saved brightness and keyboard are nil.

`testClosedLidTimerReleasesKernelAndSleepsOnce`

Existing closed-lid timer. One `sleepnow`, kernel clear. Exit `0` still drops hygiene on that path.

## Red, then green

Red, before the condition change:

```
swift test --filter testFailedSleepnowRestoresCapturedBrightnessAndKeyboard
```

2026-10-27 18:33:08. Exit 1. 1 test, 2 failures.

`XCTAssertEqual failed: ("[]") is not equal to ("[0.8]")`

`XCTAssertEqual failed: ("[]") is not equal to ("[0.6]")`

`failed.sleepnow` was already `.failed(exit: 1)`. The zero-exit half did not fail.

Green:

```
swift test --filter 'testFailedSleepnowRestoresCapturedBrightnessAndKeyboard|testClosedLidTimerReleasesKernelAndSleepsOnce'
```

2026-10-27 18:33:25. Exit 0. 2 tests, 0 failures.

## Concerns

- A failed `sleepnow` shares the nil else, so Power B also calls `wakeDisplay` when the lid read is not closed. A confirmed-closed failure only restores. That is the one condition. It does not call `sleepnow`.
- The count is the fixture's `runCommand`, not `/usr/bin/pmset`. Exit `1` stands in for any non-`.ok`, including the 3-second runner kill `-2`. `-2` was not driven as its own case.
- Nil capture on a failed sleep was not given its own assertion. `restoreHygiene` still skips a nil capture. This test uses `0.8` and `0.6`.
- Compiling `WatchRuntime+Poll.swift` still prints the existing Sendable warning at line 94. This edit did not add it.
