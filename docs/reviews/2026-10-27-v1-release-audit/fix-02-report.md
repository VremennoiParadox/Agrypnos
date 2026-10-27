# Fix 2 — V1-TG-01

Status: DONE

A Telegram command that arrived while the Mac was asleep is not applied. A wake-miss ack stays `seeded: false` and `wakeMiss: true`. `noteMacDidWake` starts one wake-miss drain, and only that drain's accepted ack is promoted to a live cursor. Will-sleep stops the poller before `noteMacWillSleep` returns. The will-sleep notification block calls that on the main queue. It does not hop through a `Task`. While that hold is set, `sync()` does not start another `getUpdates` and does not turn the cursor into a silent leftover drain.

No commit. No push. Fix 1 is still in the working tree. Discord files were not edited.

## Callers traced before the edit

- `acknowledging`: `finishTelegramInboundPoll` saves it. Tests call it. Discord has its own method and was left alone.
- `startingWakeMiss`: `beginTelegramInboundWakeMissSession`, and the Telegram branch of `noteMacWillSleep`. Discord's `startingWakeMiss` is a different type.
- `noteMacWillSleep`: only the will-sleep observer in `WatchRuntime+Kernel.swift`.
- Poller loop: `startLoop`, from `sync` (leftover) and `restartForWakeMiss` (keep the cursor). `restartForWakeMiss` is only called from `noteMacDidWake`.

## Files changed

- `Sources/AgrypnosCore/Notif/TelegramInbound.swift` — `acknowledging` keeps a wake-miss cursor unseeded. `promotedAfterWake()` is the explicit post-wake step. Same `TelegramInboundDrain`. Same `chatMatches`.
- `Apps/Agrypnos/Sources/Notif/WatchRuntime+TelegramInbound.swift` — `noteMacWillSleep` calls `stopForSleep` first. `finishTelegramInboundPoll` acks a stored wake-miss cursor instead of the fetched live snapshot, then promotes only when the wake drain armed that save. Telegram secret reads in this file go through `readNotifSecrets()`. The app's default for that closure is still `NotifSecretsStore.load`.
- `Apps/Agrypnos/Sources/Notif/TelegramInboundPoller.swift` — sleep sets a hold and cancels the loop. `startLoop` returns while the hold is set, before `startingSession`. `restartForWakeMiss` clears the hold, saves a wake-miss cursor, arms one promotion, and starts the drain.
- `Apps/Agrypnos/Sources/WatchRuntime+Kernel.swift` — the will-sleep observer calls `noteMacWillSleep()` inside `MainActor.assumeIsolated` on queue `.main`. The did-wake observer is still a `Task`.
- `Tests/AgrypnosCoreTests/TelegramInboundPolishTests.swift`
- `Tests/AgrypnosMacTests/TelegramInboundWakeMissRuntimeTests.swift` — new.

Not touched: Discord cursor, gateway, and inbound files. `startingSession` (Fix 13). Question submit. The sleep decision for `/disarm`.

## Tests changed

`testWakeMissAckSeedsLiveAndClearsMiss` is now `testWakeMissAckStaysUnseededAndDoesNotApply`.

- A wake-miss ack of `/arm` stays unseeded, `drain == .wakeMiss`, offset advances, and the effect is `.missedWhileAsleep`.

`testStoredWakeMissStaysWakeMissAcrossAckUntilPostWakePromotion`

- `startingWakeMiss` then `acknowledging` stays wake-miss. `promotedAfterWake()` is the step that becomes live, same offset. That live drain would apply `/arm`. The ack by itself does not.

`testLiveAckStillSeedsAndApplies`

- A seeded cursor's ack is still live and would apply `/arm`.

`TelegramInboundWakeMissRuntimeTests`

- `testLiveFinishStillArms`: matching generation, live cursor, `/arm` turns Keep awake on and saves a live cursor.
- `testWillSleepBumpsGenerationSoInFlightFinishDoesNotSeedOrEngage`: watch on, then `noteMacWillSleep`, then `finish` with the old generation and `/disarm`. Generation no longer matches. Watch stays on. `sleepRequests == 0`. Cursor is wake-miss, unseeded, same offset.
- `testStoredWakeMissFinishDoesNotSaveFetchedLiveAckOrArm`: stored wake-miss, fetched live snapshot, `/arm`. Does not arm. Saved cursor stays wake-miss and the offset advances.
- `testPostWakeDrainPromotesWithoutApplying`: the post-wake promotion is armed, the batch is wake-miss, `/arm` does not arm, and the saved cursor is live.
- `testSleepHoldDoesNotStartLeftoverDrain`: after will-sleep, `sync()` leaves the wake-miss cursor in place.

The will-sleep test calls `noteMacWillSleep` directly. It does not post `NSWorkspace.willSleepNotification`. Posting that notification tells every app the Mac is about to sleep.

## Red, then green

Core, before `acknowledging` changed. `promotedAfterWake` was a stub that returned `self`, so the suite could compile.

`swift test --filter 'testWakeMissAckSeedsLiveAndClearsMiss|testStoredWakeMissStaysWakeMissAcrossAckUntilPostWakePromotion|testLiveAckStillSeedsAndApplies'`

Exit 1. `testLiveAckStillSeedsAndApplies` passed. The other two failed because the ack was seeded, `drain` was `.live`, and `/arm` was `.apply(.arm)` rather than `.missedWhileAsleep`.

After `acknowledging` kept wake-miss, and before `promotedAfterWake` did anything: the ack test passed. The promotion test failed because the cursor was still wake-miss and the effect was still `.missedWhileAsleep`.

Mac, before will-sleep invalidated, before finish used the stored wake-miss cursor, and before the promotion flag was wired. `armPostWakePromotion` was an empty stub.

`swift test --filter TelegramInboundWakeMissRuntimeTests`

Exit 1. 4 tests, 10 failures. `testLiveFinishStillArms` passed.

- `testWillSleepBumpsGenerationSoInFlightFinishDoesNotSeedOrEngage`: generation 0 was still accepted. The saved cursor was seeded, not wake-miss, offset 42. The watch stayed engaged and `sleepRequests` stayed 0, because the stored cursor was already wake-miss and that drain does not disarm. The bug that failed the test was the live reseed and the missing generation bump.
- `testStoredWakeMissFinishDoesNotSaveFetchedLiveAckOrArm`: `/arm` did not engage. The saved cursor was live.
- `testPostWakeDrainPromotesWithoutApplying`: `/arm` did not engage. The saved cursor stayed wake-miss.

Green, after the implementation, re-run at 2026-10-27 16:43:09:

```
swift test --filter TelegramInbound
```

Exit 0. 57 tests, 0 failures. That filter includes the Core Telegram inbound suites and `TelegramInboundWakeMissRuntimeTests` (5 tests). `testSleepHoldDoesNotStartLeftoverDrain` passed in 0.001s, so it did not sit in `getUpdates`.

## Concerns

- The full `swift test` suite was not run. Only `--filter TelegramInbound`.
- The will-sleep observer itself was not invoked. `MainActor.assumeIsolated` compiled. It was not run by posting `NSWorkspace.willSleepNotification`.
- A `finish` block that is already running, or already queued on the main queue ahead of the will-sleep observer, can still apply and seed before the observer runs. The extra `Task` hop is gone. That earlier queue slot is not.
- Did-wake is still scheduled with `Task`. `heldForSleep` rejects `startLoop` until `restartForWakeMiss` clears it, so that hop does not start a leftover `getUpdates`.
- `testSleepHoldDoesNotStartLeftoverDrain` was not watched failing. The failing path calls `startingSession` and then `getUpdates`. With the hold in place the test passes and does not start that loop.
- Fix 13 is not this fix. A new process still uses `startingSession`, which clears `wakeMiss`. A stored wake-miss cursor from a crash during sleep is still a silent leftover drain on the next launch.
- The in-hand batch, once the stored cursor is wake-miss, was already blocked by `TelegramInboundDrain.effective`. The new generation check is what stops a stale `finish` from running at all. The new save path is what stops a matching-generation finish from replacing that wake-miss cursor with the fetched live ack.
