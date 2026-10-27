# Fix 1 — V1-Q-01

Status: DONE

An idle `.endUnanswered` tick now returns `disengage(.questionUnanswered)` from `WatchEngine.tick` before the Agents settle branch. Safety auto-off still runs first. That tick does not call `settle.observe`. `finishQuestionUnanswered` is unchanged. It still sends the unanswered notice, then asks the Mac to sleep only after a fresh confirmed close.

No commit. No push.

## Files changed

- `Sources/AgrypnosCore/Session/WatchEngine.swift` — one branch in `tick`, after the safety auto-off return and before `.hold` / `.deferTimeout` / Agents settle.
- `Tests/AgrypnosCoreTests/QuestionWatchTests.swift`
- `Tests/AgrypnosMacTests/QuestionTimeoutRuntimeTests.swift`

Not touched: `finishQuestionUnanswered`, question submit, popover copy, How long storage, arming.

## Tests changed

`testUnansweredEndUsesOwnReasonWithoutIdlePostOrChangingMode`

- Closed lid, Agents, Notif on, idle `.endUnanswered`: disengages `.questionUnanswered`, includes `.requestSleep`, does not post idle-after-wait, does not disengage `.agentsSettled`, leaves How long on Agents, records last end `.questionUnanswered`.
- Open lid, How long ∞: same disengage, no `.requestSleep`, How long stays ∞.

`testUnansweredQuestionDoesNotBlockAgentsSettle`

- The first idle `.endUnanswered` tick is `.questionUnanswered`. Later ticks in that grace window are not `.agentsSettled`.

`QuestionTimeoutRuntimeTests`

- `testVerifiedReleasePrecedesNoticeAndClosedLidSleep`: confirmed closed, idle deadline. Kernel is cleared and the watch is off before the notice. The notice says Keep awake turned off. Then one `sleepnow`. No idle-after-wait message.
- `testOpenLidUnansweredNoticeDoesNotSleep`: open lid sends that notice and does not sleep. The notice does not say it is asking the Mac to sleep.
- These also had to move, because they locked the old “stay engaged” result: failed kernel release (expects the couldn’t-turn-off notice, no success copy, no sleep), rearm during the notice (no sleep), lid opening during the final confirm (notice, no sleep), and the real monotonic deadline after a wall-clock jump (that deadline now ends the watch; the jump itself still does not).

Busy, unknown, safety auto-off, observed-while-off, and early native expiry were not retargeted. They still passed.

## Red, then green

Red, before the branch:

`swift test --filter QuestionWatchTests`

QuestionWatchTests: 5 tests, 7 failures. The idle deadline did not disengage `.questionUnanswered`, did not request sleep, left the watch engaged, and left last end nil. The Agents loop later disengaged `.agentsSettled`.

`swift test --filter QuestionTimeoutRuntimeTests`

QuestionTimeoutRuntimeTests: 10 tests, 24 failures. The idle deadline left the watch engaged, sent no unanswered notice, and requested sleep 0 times. Busy/unknown, safety auto-off, observed-while-off, and delayed native expiry passed.

Green:

```
swift test --filter 'QuestionWatchTests|QuestionTimeoutRuntimeTests'
```

Exit 0. 15 tests, 0 failures. QuestionTimeoutRuntimeTests 10/10. QuestionWatchTests 5/5. Re-run at 2026-10-27 16:13:57, same result.

## Concerns

- The full `swift test` suite was not run. Only these two filters.
- The popover sentence still states the sleep with no lid condition. That is Fix 11. Left as written.
- There is no separate 1h / 3h / custom test. The branch does not read How long. Agents and ∞ are covered.
- Unconfirmed close is not its own Mac test. It does not set `lidClosed`, so this disengage does not add `.requestSleep`. The Mac path still requires two fresh closed samples before `sleepnow`.
- The test shows the tick is `.questionUnanswered` rather than `.agentsSettled`. It cannot show `settle.observe` was skipped by inspecting the tracker, because `disengage` resets that tracker.
