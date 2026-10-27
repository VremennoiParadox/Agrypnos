# Fix 2 review — V1-TG-01

Reviewed the uncommitted diff in the six named files only. Discord paths have no diff. Fix 1 was not reviewed.

## SPEC: PASS

No missing behavior. No extra behavior.

- A wake-miss `acknowledging` stays `seeded: false` and `wakeMiss: true`, advances the offset, and `TelegramInboundDispatch` yields `.missedWhileAsleep`. `promotedAfterWake()` is the only step that makes that cursor live, at the same offset.
- `noteMacDidWake` does not flip the cursor before the drain. `restartForWakeMiss` saves `startingWakeMiss()`, arms one promotion, and starts `keepCursor`. `finishTelegramInboundPoll` applies with `TelegramInboundDrain.effective` first. Stored wake-miss forces `.wakeMiss` even when the fetched snapshot is live. Only that armed ack is saved as `promotedAfterWake()`. The backlog in that batch is not applied. The next poll is live.
- `noteMacWillSleep` calls `stopForSleep()` before it returns. That sets the hold and `invalidate()` (generation bump, task cancel) synchronously. The will-sleep observer calls it inside `MainActor.assumeIsolated` on `queue: .main`. There is no `Task` hop. On this Swift, `assumeIsolated` from `OperationQueue.main` runs; it does not trap.
- `startLoop` returns while the hold is set, before `startingSession` and before a new `Task`. `sync()` during the hold does not turn the cursor into a silent leftover drain and does not start `getUpdates`. `restartForWakeMiss` is what clears the hold.
- A live seeded ack still becomes `.live` and still applies `/arm`.
- Same `TelegramInboundDrain`. Same `chatMatches`. `readNotifSecrets()` is the existing closure; the app default is still `NotifSecretsStore.load`. No second allowlist. `startingSession` is untouched. Discord cursor, gateway, and inbound files are untouched. The pre-existing Discord lines in `noteMacWillSleep` were not changed.

The reported leftover is an acceptable race. The required sentence is an in-flight finish whose generation was already bumped. `finishTelegramInboundPoll` and the will-sleep observer both run on the main actor, and finish does not suspend, so will-sleep cannot bump generation in the middle of a finish that has already started. A finish already queued ahead of the observer is a `getUpdates` body that was parsed before that observer was queued, while the process was awake. A command that arrives while the Mac is asleep is not in that body: the process is frozen during sleep, so the update stays on Telegram until a later poll. On wake the will-sleep block was queued first, bumps generation, and that later finish returns before `setEngaged`, `disarmWatch`, or a seeded save. If the ahead-of-observer finish does apply its already-fetched batch, `noteMacWillSleep` still replaces the cursor with `startingWakeMiss()`, so the seeded save does not stick. The plan did not require dropping a batch fetched while awake.

## QUALITY: Approved

The tests assert the new behavior. They are not empty.

- `testWakeMissAckStaysUnseededAndDoesNotApply` asserts unseeded, wake-miss, offset 42, `.wakeMiss`, and `.missedWhileAsleep`.
- `testStoredWakeMissStaysWakeMissAcrossAckUntilPostWakePromotion` asserts the ack stays wake-miss and that only `promotedAfterWake()` would apply `/arm`.
- `testLiveAckStillSeedsAndApplies` asserts a seeded ack still applies.
- `testWillSleepBumpsGenerationSoInFlightFinishDoesNotSeedOrEngage` calls `noteMacWillSleep`, then `finish` with generation 0 and `/disarm`. It asserts the old generation is rejected, Keep awake stays on, `sleepRequests == 0`, and the cursor stays unseeded wake-miss at offset 40. That is the required finish. It does not need the poll loop.
- `testStoredWakeMissFinishDoesNotSaveFetchedLiveAckOrArm` feeds a live fetched snapshot over a stored wake-miss cursor and asserts `/arm` does not engage and the save stays wake-miss at offset 42.
- `testPostWakeDrainPromotesWithoutApplying` arms the one promotion, asserts `/arm` does not engage, and asserts the saved cursor is live at offset 42.
- `testSleepHoldDoesNotStartLeftoverDrain` returns in about 0.001s because the hold returns before `getUpdates`. That is still evidence. `startLoop(.leftover)` calls `beginTelegramInboundPollSession()` on the same stack, before the detached task. That would clear `wakeMiss` before `sync()` returned. The test asserts it stayed true. It does not need to sit in the HTTP call.
- `testLiveFinishStillArms` calls `finish` at generation 0 with `/arm` and asserts Keep awake turns on and the saved cursor is live at offset 42.

## ISSUES

none
