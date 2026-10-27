# Watch engine

- verdict: BLOCK
- blockers: 1
- high: 0
- scope: `Sources/AgrypnosCore/Session/WatchEngine.swift`, `WatchTypes.swift`, `StatusItemState.swift`, `WatchTickProbe.swift`, `UserPreferences.swift`; `Sources/AgrypnosCore/Power/Safety.swift`, `LidCloseConfirm.swift`, `DurationOption.swift`, `PanelPowerMode.swift`; `Sources/AgrypnosCore/Agent/AgentSettleTracker.swift`; `Sources/AgrypnosCore/Questions/QuestionWaitPolicy.swift`; `Sources/AgrypnosCore/Notif/TelegramInboundPolish.swift`, `NotifIdlePostPolicy.swift`, `NotifIdleOutboundCoordinator.swift`, `DiscordBotOutbound.swift`; `Sources/AgrypnosCore/Copy/AgrypnosCopy.swift` (last-end and LPM lines); `Apps/Agrypnos/Sources/WatchRuntime.swift`, `WatchRuntime+Poll.swift`, `WatchRuntime+Kernel.swift`, `WatchRuntime+Lid.swift`, `WatchRuntime+Questions.swift`, `AppDelegate.swift`; `Apps/Agrypnos/Sources/Power/PowerHygieneCoordinator.swift`; `Apps/Agrypnos/Sources/MenuBar/PopoverController.swift` (quit); `prd/v1-scope.md`; `docs/superpowers/specs/2026-09-29-native-agent-questions-design.md` (question-end paragraphs); Core tests `WatchEngineTests`, `WatchUserOffSleepTests`, `WatchCountdownTests`, `WatchDisarmRollbackTests`, `LastWatchEndTests`, `StickyWatchTests`, `WatchLidHygieneTests`, `WatchIdlePostHoldTests`, `QuestionWatchTests`, `AutoOffEvaluatorTests`, `AgentObservationContinuityTests`, `NotifIdlePostTests`, `TelegramInboundPolishTests`, `SettingsSliceTests`, `PanelPowerModeTests`; Mac `TimedWatchRuntimeTests` (read, not run).

## Product promise

Popover or hotkey off, and inbound `/disarm`, share one lid gate: confirmed closed clears the wake hold and requests `sleepnow`; open or unconfirmed clears the hold and does not sleep. Already off with the lid confirmed closed still requests `sleepnow`. Timer expiry turns Keep awake off, leaves How long alone, and requests sleep unless the lid is known open. Unavailable or unconfirmed closed still requests sleep on that timer path only. Changing How long while armed starts a fresh countdown. Opening the lid does not pause or restart it. The countdown starts when Keep awake turns on. Agents mode disengages with `agentsSettled` only after local busy was seen this arm and the settle wait ends. How long stays Agents. Never-busy this arm does not post and does not disarm. Safety auto-off disengages for its own reason and sleeps only on the existing closed-lid path. Engage does not mean display sleep. Last-end text comes from a real `DisengageReason`. Launch does not arm. A user-forced Low Power Mode watch is not recorded as ended while the hold remains.

## Gates checked

- User-off confirmed closed clears the hold and requests sleep, same decision as inbound `/disarm` | PASS | `Sources/AgrypnosCore/Session/WatchEngine.swift:172-175` calls `userSetEngaged(false)`; `:363-367` appends `requestSleep` when `wasLidClosed`; `Sources/AgrypnosCore/Notif/TelegramInboundPolish.swift:53-55`; live popover/hotkey passes that confirm into the same call `Apps/Agrypnos/Sources/WatchRuntime+Poll.swift:386-387`
- Lid open or unconfirmed user-off clears the hold and does not sleep. Disarm does not always sleep | PASS | `WatchEngine.swift:365` keys off `wasLidClosed`; `Tests/AgrypnosCoreTests/WatchUserOffSleepTests.swift:48-66`; `Tests/AgrypnosCoreTests/TelegramInboundPolishTests.swift:205-217`
- Already off and confirmed closed still requests sleep, without a second sleep rule | PASS | `WatchEngine.swift:177-179` returns `[.requestSleep]` from `TelegramInboundDisarm.shouldRequestSleep`; `WatchRuntime+Poll.swift:386-389` uses `userSetEngaged` while armed and the same confirm flag when already off
- Timer expiry turns Keep awake off and preserves How long | PASS | `WatchEngine.swift:335-337` clears `engaged` and `timerEnd` and does not assign `preferences.duration`; `Tests/AgrypnosCoreTests/WatchCountdownTests.swift:20-23`
- Timer requests sleep unless the lid is known open. Unavailable or unconfirmed closed still requests sleep | PASS | `WatchEngine.swift:364-366` always offers `requestSleep` for `.timerExpired`; `WatchRuntime+Poll.swift:326` removes it only when `rawClosed == false`; `Apps/Agrypnos/Sources/Power/PowerHygieneCoordinator.swift:43` runs `sleepnow` when `readLid() != false`
- Changing duration while armed starts a fresh interval | PASS | `WatchEngine.swift:114-116`; `WatchCountdownTests.swift:43-44`
- Opening the lid does not pause or restart the countdown | PASS | `WatchEngine.swift:246-253` does not write `timerEnd`; `WatchCountdownTests.swift:32-34`
- Countdown starts when Keep awake turns on | PASS | `WatchEngine.swift:284`; `WatchCountdownTests.swift:16-17`
- After busy was seen this arm, settle end disengages `.agentsSettled` and leaves How long on Agents | PASS | `WatchEngine.swift:221-228`; `Tests/AgrypnosCoreTests/WatchEngineTests.swift:109-118`
- Never-busy this arm: no idle POST, no disarm | PASS | `Sources/AgrypnosCore/Agent/AgentSettleTracker.swift:42`; `WatchEngineTests.swift:50-56`; `Sources/AgrypnosCore/Notif/NotifIdlePostPolicy.swift:13`
- Safety auto-off disengages for that reason and keeps the closed-lid sleep path | PASS | `Sources/AgrypnosCore/Power/Safety.swift:63-74`; `WatchEngine.swift:204-213` and `:365`; `WatchUserOffSleepTests.swift:105-116`. Threshold numbers are SF
- Engage does not imply display sleep | PASS | `WatchEngine.swift:285-293` adds lid hygiene only when `lidClosed` is already true; `WatchEngineTests.swift:9-11` expects `[.engage]` with the lid open
- Last-end captions use a real `DisengageReason` | PASS | `WatchEngine.swift:328-332`; `Sources/AgrypnosCore/Copy/AgrypnosCopy.swift:136-146` has one arm per case
- Launch does not auto-arm | PASS | `WatchEngine.swift:35` `engaged = false`; `Apps/Agrypnos/Sources/WatchRuntime.swift:132` only reconciles a leftover kernel hold; `WatchRuntime+Kernel.swift:91-99` adopts only if the clear did not stick
- Forced Low Power Mode watch is not described as ended while the hold remains | PASS | `Safety.swift:70` skips LPM when `userForcedThisSession`; `WatchEngineTests.swift:291-302`; `Tests/AgrypnosCoreTests/LastWatchEndTests.swift:148-153`
- Unanswered question ends Keep awake with `.questionUnanswered`, leaves How long, and uses the confirmed-lid sleep path | FAIL | `WatchEngine.swift:215-228`; `Tests/AgrypnosCoreTests/QuestionWatchTests.swift:34-39`

## Findings

### V1-WE-01 Unanswered question does not turn Keep awake off

- severity: BLOCKER
- confidence: high
- breaks: At an unanswered deadline with fresh observed idle, Keep awake turns off with `DisengageReason.questionUnanswered`. How long stays. Confirmed closed requests sleep. Open or unconfirmed does not. A pending question must not end as `agentsSettled`.
- evidence: `Sources/AgrypnosCore/Session/WatchEngine.swift:215-228`

```swift
        if questionWait.action == .hold || questionWait.action == .deferTimeout {
            if observeAgents, agents.anyBusy(included: preferences.includedAgentKinds) {
                _ = settle.observe(busy: true, now: now)
            } else {
                settle.interruptObservations()
            }
        } else if observeAgents, mode == .untilAgentsSettle {
            let activity = settle.observe(
                busy: agents.anyBusy(included: preferences.includedAgentKinds),
                now: now
            )
            if activity == .settled {
                return disengage(.agentsSettled, at: now)
            }
        }
```

`QuestionWaitPolicy.observe` returns `.endUnanswered` on the first idle sample at the deadline (`Sources/AgrypnosCore/Questions/QuestionWaitPolicy.swift:61-66`). `tick` has no arm for that action. The design says that sample ends the watch with `questionUnanswered`, and that a pending question suppresses Agents idle disengage (`docs/superpowers/specs/2026-09-29-native-agent-questions-design.md:24` and `:73-75`). AGENTS.md does not contradict that end.
- trigger: Keep awake is on, question forwarding is on, and the question wait reaches `.endUnanswered` with an idle observation. Lid may already be confirmed closed. How long may be ∞, 1h, 3h, custom, or Agents.
- expected: `tick` returns `disengage(.questionUnanswered)` before any Agents settle. `preferences.duration` is unchanged. No `postIdleAfterWaitNotif`. `lastWatchEnd.reason` is `.questionUnanswered`. `requestSleep` is included only when the lid flag `disengage` already treats as confirmed closed.
- actual: `.endUnanswered` is not `.hold` and not `.deferTimeout`, so it falls through. ∞ / 1h / 3h / custom never enter the Agents branch, so the watch stays armed and a closed lid does not sleep. `QuestionWatchTests.testUnansweredEndUsesOwnReasonWithoutIdlePostOrChangingMode` locks that miss: lid closed, idle at 600s, and it asserts no `.questionUnanswered`, no `requestSleep`, `engaged == true`, and `lastWatchEnd == nil` (`QuestionWatchTests.swift:32-39`). In Agents mode the same action keeps sampling settle. After a fresh grace, `tick` disengages `.agentsSettled` (`QuestionWatchTests.swift:57-63`), which can send the idle-after-wait POST. The Mac notice and closed-lid sleep in `finishQuestionUnanswered` never run, because nothing emits `.questionUnanswered`.
- fix_files: `Sources/AgrypnosCore/Session/WatchEngine.swift`
- fix: In `tick`, after the safety `disengage` and before the hold / Agents branch, if `questionWait.action == .endUnanswered` return `disengage(.questionUnanswered, at: now)`. Leave `.hold` and `.deferTimeout` as they are. The existing `disengage` sleep gate already requests sleep only when `wasLidClosed` is set.
- test_first: Rewrite `Tests/AgrypnosCoreTests/QuestionWatchTests.swift` `testUnansweredEndUsesOwnReasonWithoutIdlePostOrChangingMode` so an idle `.endUnanswered` tick contains `.disengage(.questionUnanswered)`, does not contain `.postIdleAfterWaitNotif` or `.agentsSettled`, keeps `preferences.duration`, sets `lastWatchEnd.reason` to `.questionUnanswered`, and contains `.requestSleep` when the arm was `lidClosed: true`. Add the same end for `.indefinite` with `lidClosed: false` and assert no `.requestSleep`. Replace `testUnansweredQuestionDoesNotBlockAgentsSettle` so the first `.endUnanswered` tick is `.questionUnanswered`, not a later `.agentsSettled`. Keep `testQuestionHoldSuppressesAgentsSettle` and `testSafetyWinsAndDeferredTimeoutKeepsKernelReassertion`.
- do_not: Do not end on `.hold` or `.deferTimeout`. Do not map this action to `.agentsSettled`. Do not append `postIdleAfterWaitNotif`. Do not change `preferences.duration`. Do not request sleep for an open or unconfirmed lid. Do not run this ahead of battery, thermal, or Low Power Mode. Do not add a new reason or a second sleep helper.

## Handoffs

- MAC | `Apps/Agrypnos/Sources/WatchRuntime+Kernel.swift:59-72` and `Apps/Agrypnos/Sources/MenuBar/PopoverController.swift:508-512` | Quit calls `setEngaged(false)`, which can defer `sleepnow` until the Discord watch-end POST finishes; `applicationWillTerminate` then cancels that task and clears the kernel, so a confirmed-closed Quit while that POST is waiting does not sleep. Popover and hotkey off do not terminate and are unaffected.
- MAC | `Apps/Agrypnos/Sources/WatchRuntime+Poll.swift:326` and `Apps/Agrypnos/Sources/Power/PowerHygieneCoordinator.swift:43` | Timer expiry always offers `requestSleep` from the engine. These two reads drop it only when the live lid is known open, and they still sleep when the read is nil or raw closed.
- SF | `Sources/AgrypnosCore/Power/Safety.swift:63-74` | Battery, thermal, and Low Power Mode thresholds are decided here. The engine disengages when this returns a reason.
- AG | `Sources/AgrypnosCore/Agent/AgentSettleTracker.swift:47-56` | Busy versus idle is an input. The engine disarms only after `observe` returns `.settled`.
- Q | `Apps/Agrypnos/Sources/WatchRuntime+Poll.swift:279-305` | The question notice and the reconfirm-before-sleep path already exist for a `.questionUnanswered` command. The engine never sends that command.

## Needs a Mac

Confirmed-closed popover or hotkey off runs `sleepnow` once. Open or unconfirmed off does not. Timer expiry with the lid known open does not sleep. An unavailable lid reading on timer expiry does. The deadline timer fires without waiting for the 5s poll. Those branches were read and not executed.

## Unproven

`swift test` and `xcodebuild` were not run. No physical lid, `pmset`, or menu-bar pass was done in this audit. The question-end miss is visible in `tick` and in the test that locks the watch staying on; it was not exercised against a live bot.
