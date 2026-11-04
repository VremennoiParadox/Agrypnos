# Fix 1 review — V1-Q-01

Reviewed the uncommitted diff in `WatchEngine.swift`, `QuestionWatchTests.swift`, and `QuestionTimeoutRuntimeTests.swift` only.

## SPEC: PASS

No missing behavior. No extra behavior.

- An idle `.endUnanswered` tick returns `disengage(.questionUnanswered)` after the safety auto-off return and before `.hold` / `.deferTimeout` and the Agents settle branch.
- That return does not call `settle.observe`. `disengage` resets the tracker; it does not observe it.
- How long (`preferences.duration`) is not written. The closed-lid case stays Agents. The open-lid case stays ∞.
- Idle-after-wait is not posted. `NotifIdlePostPolicy.shouldPost` is true only for `.agentsSettled` with busy seen. The reason is `.questionUnanswered`.
- Safety stays first. `testSafetyWinsAndDeferredTimeoutKeepsKernelReassertion` still expects `.thermal` on an `.endUnanswered` tick.
- Open lid does not add `.requestSleep`. The Mac test sends the turned-off notice, the notice does not say it is asking the Mac to sleep, and `sleepRequests` stays 0.
- Confirmed closed adds `.requestSleep` from the existing `disengage` lid gate. `finishQuestionUnanswered` is unchanged: it removes that command, sends the notice, then applies one `.requestSleep` only after a new two-sample close. `PowerHygieneCoordinator` runs `sleepnow` for a non-timer reason only when `readLid() == true`. The closed-lid Mac test sees one sleep request, after the notice.
- An unconfirmed close leaves `lidClosed` false until `LidCloseConfirm` returns `.closed`, so this disengage does not add `.requestSleep`. The Mac re-check also requires two closed samples.
- No answer is submitted. Timeout still uses `returnLocal`. The branch does not arm the watch.
- No new types. The only production edit is that branch. The other Mac assertion updates replace the old “stay engaged” locks on this same deadline. Popover copy is untouched.

## QUALITY: Approved

The branch is the one the spec names. The tests that must change assert the reason, the idle post, How long, and the lid sleep split. The later grace loop in `testUnansweredQuestionDoesNotBlockAgentsSettle` cannot fail once the first tick has disengaged, because a disengaged `tick` returns no commands. The first tick’s reason assertions are real, and `testUnansweredEndUsesOwnReasonWithoutIdlePostOrChangingMode` covers the same tick on which Agents settle would otherwise win. That is not an empty test and not a second sleep path.

## ISSUES

none
