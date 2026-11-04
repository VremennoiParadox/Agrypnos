# Telegram

- verdict: NO-SHIP
- blockers: 1
- high: 2
- scope: Telegram inbound, wake-miss, lid-gated `/disarm`, `/status`, `/help`, outbound POST, secrets, `setMyCommands`. Discord-only sleep bodies handed to DC. WatchEngine sleep math checked only where Telegram calls it.

## Product promise

The user's own bot. Same token for outbound and inbound. Commands only from the saved chat id. Inbound off unless turned on, and off unless token and chat id are both set. `/arm` `/disarm` `/status` `/help`. Commands that arrived while the Mac was asleep are not applied; the reply is "Missed while asleep." `/disarm` sleeps the Mac only when lid-close is already confirmed, including when Keep awake is already off. `/status` is live facts. Outbound fires only for timer expiry, or for Agents after busy was seen this arm and the wait ended. That message says it is asking the Mac to sleep when this send will `sleepnow`. Telegram does not post for battery, thermal, Low Power Mode, or manual off. Secrets stay in `notif-secrets.json` mode 0600.

## Gates checked

- Own bot, same token, no shared bot. `NotifOutboundRequestFactory` builds `https://api.telegram.org/bot{token}/…` (`NotifOutboundRequest.swift` 77–91). No second token. Pass.
- One allowlist. `TelegramInboundPolicy.intent` calls `chatMatches` once (`TelegramInbound.swift` 83–97, 104–109). Wrong chat, empty token, empty chat id, and inbound off return `.ignore` (`TelegramInboundTests.swift` 52–130). Pass.
- Inbound default off, separate from Watch-end POST default off (`UserPreferences.swift` 66, 210; `TelegramInboundTests.swift` 6–7; `NotifIdlePostTests.swift` 5–6). Pass.
- Four commands, bare words still parse, `/help` does not arm (`TelegramInbound.swift` 29–44, 202–212; `TelegramInboundPolishTests.swift` 5–34). Pass.
- Lid gate is `TelegramInboundDisarm.shouldRequestSleep`, used inside `WatchEngine.disengage` and the already-off branch of `applyInbound` (`WatchEngine.swift` 172–180, 363–367). Mac `/disarm` calls `disarmWatch` → `userOffLidCloseConfirmed` (`WatchRuntime.swift` 398–418, `WatchEngine.swift` 16–17), not a second sleep stack. Core tests: open and one raw close do not request sleep; confirmed close does, including already off (`TelegramInboundPolishTests.swift` 188–251). Pass in Core. Physical sleep not run tonight.
- `/status` omits unknown battery, skips countdown unless the watch is armed and the mode has minutes (`TelegramStatus.swift` 72–74, 120–126). ∞ and Agents have `minutes == nil` (`DurationOption.swift` 16–18). No ETA, task text, or think-detection in the dump. Pass.
- Outbound requires the POST switch plus token plus chat id (`NotifIdlePostPolicy.swift` 8–28). Never-busy does not emit the post (`NotifIdlePostPolicy.swift` 13; `AgentSettleTracker.swift` 41–42). `telegramBody` is nil for `.user`, `.batteryFloor`, `.thermal`, `.lowPowerMode` (`NotifIdlePoster.swift` 69–77). Pass.
- Timer text is `Agrypnos: your Keep awake timer ended.` It does not gain the sleep sentence. Fail. See V1-TG-03.
- Secrets path is Application Support `notif-secrets.json`, create and `setAttributes` `0o600` (`NotifSecretsStore.swift` 91–111). Not Keychain. Token is not written to `UserDefaults` (cursor offset only, `PreferencesStore.swift` 27–42). `TelegramInboundHTTP.fetch` does not log the URL (`TelegramInboundPoller.swift` 25–44). Pass in code. Live file mode not stat'd.
- `setMyCommands` body is arm, disarm, status, help (`TelegramInboundPolish.swift` 68–77; `TelegramInboundPolishTests.swift` 304–305). Registered when the poller starts (`WatchRuntime+TelegramInbound.swift` 61–65). Pass in code. Live BotFather menu not checked.
- Wake-miss drain exists and the in-flight snap is forced to wake-miss while the stored cursor is still wake-miss (`TelegramInboundPolish.swift` 12–17, 41–44). The poller then clears that flag and keeps polling. Fail. See V1-TG-01.
- Notif toggle help tells a Telegram-only user they are messaged when Agrypnos asks the Mac to sleep. Fail. See V1-TG-02.

## Findings

### V1-TG-01

- severity: BLOCKER
- confidence: medium
- breaks: A command that arrived while the Mac was asleep can be applied. `/arm` or `/disarm` in that batch runs. There is no "Missed while asleep." reply for that batch.
- evidence: Sleep handling does not stop the poller. `observeMacSleepWake` hops `noteMacWillSleep` onto a later MainActor task (`WatchRuntime+Kernel.swift` 113–122). `noteMacWillSleep` only saves `startingWakeMiss()` (`WatchRuntime+TelegramInbound.swift` 27–34). It does not call `invalidate` or `stop`. The detached loop keeps issuing `getUpdates` (`TelegramInboundPoller.swift` 129–163). `finishTelegramInboundPoll` uses `TelegramInboundDrain.effective`, which returns wake-miss only when the stored cursor is still wake-miss (`TelegramInboundPolish.swift` 12–17; `WatchRuntime+TelegramInbound.swift` 80–83). It then saves `cursor.acknowledging(updates)`. `acknowledging` sets `seeded: true` (`TelegramInbound.swift` 161–166). `init` forces `wakeMiss` false whenever `seeded` is true (`TelegramInbound.swift` 133–136), so `drain` becomes `.live` (`TelegramInbound.swift` 141–143). The next loop snapshot is live and `TelegramInboundDispatch` applies (`TelegramInboundPolish.swift` 45–46). `noteMacDidWake` → `restartForWakeMiss` does invalidate and set wake-miss again (`TelegramInboundPoller.swift` 82–86), but only if that runs before the live `finish`. `testWakeMissAckSeedsLiveAndClearsMiss` locks the reseed (`TelegramInboundPolishTests.swift` 156–166). `effective` covers one in-flight response. It does not cover the poll that starts after the ack.
- trigger: Inbound is on, token and chat id are set, the poller is in `getUpdates`. The Mac starts sleep. The in-flight request completes or fails during the will-sleep window (lid-close network drop is enough: failure waits 5s then loops, `TelegramInboundPoller.swift` 151–153). The wake-miss batch is acked, the cursor is seeded live, and a new `getUpdates` is in flight when the Mac suspends. On wake that response is finished before `restartForWakeMiss` bumps the generation. Same hole if the deferred will-sleep task has not run yet: the stored cursor is still live, so `effective` does not intervene.
- expected: Stop the poller on will-sleep. Drain the backlog after wake without applying. Reply "Missed while asleep." Do not seed a live poll until that drain has happened.
- actual: Will-sleep leaves the loop running. The wake-miss ack seeds a live cursor. The next `getUpdates` applies.
- fix_files: `Apps/Agrypnos/Sources/WatchRuntime+Kernel.swift`, `Apps/Agrypnos/Sources/Notif/WatchRuntime+TelegramInbound.swift`, `Apps/Agrypnos/Sources/Notif/TelegramInboundPoller.swift`, `Sources/AgrypnosCore/Notif/TelegramInbound.swift`, `Tests/AgrypnosCoreTests/TelegramInboundPolishTests.swift`
- fix: In the will-sleep notification, synchronously `invalidate` the poller and save the wake-miss cursor before returning. Do not start another `getUpdates` until `noteMacDidWake`. `acknowledging` a wake-miss batch must not become `.live` until that post-wake drain is the one being acked. One drain enum. One `chatMatches`.
- test_first: Change `testWakeMissAckSeedsLiveAndClearsMiss` so a wake-miss ack does not apply. Add a cursor test that a stored wake-miss cursor stays wake-miss across ack until an explicit post-wake promotion. Add a runtime test that an in-flight finish whose generation was bumped by will-sleep does not save a seeded cursor and does not call `setEngaged` or `disarmWatch`.
- do_not: Do not apply the backlog on wake. Do not add a second allowlist or a second drain type. Do not treat a poller start after sleep as leftover (silent) drain.

### V1-TG-02

- severity: HIGH
- confidence: high
- breaks: A Telegram-only user is told Watch-end POST messages them when Agrypnos asks the Mac to sleep. Confirmed-closed `/disarm`, battery auto-off, thermal auto-off, and Low Power Mode do not send a Telegram post.
- evidence: The Notif toggle help is on screen (`PopoverController+Notif.swift` 17–23): "Message your Discord bot and/or your Telegram bot when the timer ends, when the wait after agent signals stop ends, or when Agrypnos asks the Mac to sleep." (`AgrypnosCopy.swift` 186–187). `NotifIdlePoster.telegramBody` returns nil for every reason except `.timerExpired` and `.agentsSettled` (`NotifIdlePoster.swift` 69–77). `shouldAwaitWatchEndPost` waits on Telegram only for those two reasons (`WatchRuntime+Poll.swift` 353–355). The bot `/help` text does not make this claim (`TelegramInbound.swift` 185–191). The setup guide's Telegram step does not either (`BotGuideCopy.swift` 179–181). Discord's own card is the accurate one (`AgrypnosCopy.swift` 189–190).
- trigger: Watch-end POST on, Telegram token and chat id set, Discord secrets empty. Lid confirmed closed. `/disarm`, or battery / thermal / Low Power Mode ends the watch and will `sleepnow`.
- expected: The toggle help says Telegram is messaged for timer expiry and for the wait after agent signals stop. It says Discord is also messaged when this disengage will `sleepnow`. It does not say Telegram is messaged for that sleep-only case.
- actual: The shared help lists "when Agrypnos asks the Mac to sleep" as a trigger for Discord and/or Telegram.
- fix_files: `Sources/AgrypnosCore/Copy/AgrypnosCopy.swift`, `Tests/AgrypnosCoreTests/NotifPopoverChromeTests.swift`, `Tests/AgrypnosCoreTests/NotifIdlePostTests.swift`, `Tests/AgrypnosCoreTests/TelegramInboundPopoverChromeTests.swift`
- fix: Split the sentence. Telegram: timer expiry, and the wait after busy was seen. Discord: those, plus when this disengage will `sleepnow`.
- test_first: Assert `notifEnabledHelp` does not say the Telegram bot is messaged when Agrypnos asks the Mac to sleep, and that it still says the timer and the idle-after-wait do message.
- do_not: Do not start Telegram posts for `.user`, `.batteryFloor`, `.thermal`, or `.lowPowerMode` to make the old sentence true.

### V1-TG-03

- severity: HIGH
- confidence: high
- breaks: When the timer post or the idle-after-wait post is the send that will also `sleepnow`, the Telegram text never says "Asking the Mac to sleep." The Mac can sleep after a message that only says the timer ended, or that the wait ended.
- evidence: `requests` takes `willSleep` and Discord uses it (`NotifIdlePoster.swift` 29–48, `DiscordBotOutbound.swift` 8–15). `telegramBody` does not take `willSleep` (`NotifIdlePoster.swift` 50–51, 69–77). Timer text is always `Agrypnos: your Keep awake timer ended.` Idle text is always `AgrypnosCopy.notifIdleBody`. `TimedWatchRuntimeTests.testTimerOutboundUsesExpiryMessageAndAgentsKeepsIdleMessage` asserts the closed-lid Telegram body has no sleep sentence while Discord has one (`TimedWatchRuntimeTests.swift` 239–248). The bodies do not say the Mac slept.
- trigger: Watch-end POST on, Telegram token and chat id set. Armed timer, or Agents with busy seen this arm, and this end will `sleepnow` (lid not known open).
- expected: Same sentence as today, plus ` Asking the Mac to sleep.` when `willSleep` is true. Lid open or unconfirmed: the same timer or idle sentence, with no sleep clause.
- actual: Telegram text ignores `willSleep`.
- fix_files: `Apps/Agrypnos/Sources/Notif/NotifIdlePoster.swift`, `Tests/AgrypnosMacTests/TimedWatchRuntimeTests.swift`
- fix: Pass `willSleep` into `telegramBody`. For `.timerExpired` and `.agentsSettled` only, append ` Asking the Mac to sleep.` when `willSleep` is true.
- test_first: Flip the assertion at `TimedWatchRuntimeTests.swift` 246–248 to expect `Agrypnos: your Keep awake timer ended. Asking the Mac to sleep.` for the closed-lid Telegram body, and the idle body plus the same clause. Keep the open-lid assertion with no clause (`TimedWatchRuntimeTests.swift` 231–237). Assert `.user`, `.batteryFloor`, `.thermal`, and `.lowPowerMode` still produce no Telegram request.
- do_not: Do not say the Mac slept. Do not add Telegram posts for battery, thermal, Low Power Mode, or manual off. Do not change the Discord body in this fix.

### V1-TG-04

- severity: MEDIUM
- confidence: medium
- breaks: If the process does not survive sleep, the next launch acks commands that arrived while the Mac was asleep and does not reply "Missed while asleep." It does not apply them.
- evidence: The wake-miss bit is stored in `UserDefaults` (`PreferencesStore.swift` 27–42). `noteMacWillSleep` sets it (`WatchRuntime+TelegramInbound.swift` 32–33). A new process calls `inboundPoller.sync()` (`WatchRuntime.swift` 137), which starts a leftover session (`TelegramInboundPoller.swift` 74–79, 121–122). `startingSession` clears `wakeMiss` (`TelegramInbound.swift` 151–154). Leftover dispatch drops the command with no reply (`TelegramInboundPolish.swift` 41–42).
- trigger: Inbound on. Will-sleep saved a wake-miss cursor. Agrypnos is killed before `noteMacDidWake`. Next launch, with the same token and chat id, polls `getUpdates`.
- expected: A cursor that was saved as wake-miss is drained with the missed-while-asleep reply. Ordinary setup, quit, and inbound-off starts stay silent leftover drains.
- actual: Every cold start is a leftover drain, including a stored wake-miss cursor.
- fix_files: `Apps/Agrypnos/Sources/Notif/TelegramInboundPoller.swift`, `Apps/Agrypnos/Sources/Notif/WatchRuntime+TelegramInbound.swift`, `Sources/AgrypnosCore/Notif/TelegramInbound.swift`
- fix: If the loaded cursor is wake-miss, start that session as wake-miss. `startingSession` remains the path for setup, quit, and inbound off.
- test_first: A cursor with `wakeMiss == true` and `seeded == false`, passed through the start-session choice, stays wake-miss and `effect` for `/arm` is `.missedWhileAsleep`. A normal unset cursor stays leftover and does not reply.
- do_not: Do not apply those commands. Do not mark every launch as wake-miss.

## Handoffs

- DC: Discord sleep-only bodies (user-off, battery, thermal, Low Power Mode, already-off) stay in `DiscordBotOutbound.body`. Telegram returns nil for those reasons. Not scored here.
- WE: No defect found in the sleep decision Telegram asks for. `/disarm` calls `disarmWatch`, which sleeps only when `userOffLidCloseConfirmed` is true (`lidCloseConfirmed && rawClosed`). `WatchEngine.disengage` then calls `shouldRequestSleep` on that bool. If a Mac test shows open-lid sleep after a Telegram `/disarm` that passed `confirmed == false`, that bug is in the engine, not a second Telegram gate.
- Questions: callback updates skip the command allowlist and go to `QuestionRelayCoordinator.handleTelegram` (`WatchRuntime+TelegramInbound.swift` 90–92). That path has its own chat check. Not scored.

## Needs a Mac

- Sleep with inbound on. Send `/arm` or `/disarm` from the saved chat while the Mac is asleep. On wake the watch must be unchanged and the chat must get "Missed while asleep." Repeat with the command sent in the will-sleep window, before the display is dark.
- Lid open `/disarm`: Keep awake off, Mac stays awake. One raw close, not yet confirmed: same. Confirmed closed, including Keep awake already off: Mac sleeps. Reply stays "Disarmed." and does not say the Mac slept.
- Watch-end POST, Telegram only, lid confirmed closed: timer message includes "Asking the Mac to sleep." Agents after a real busy signal, same. Never-busy Agents: no message. Battery, thermal, Low Power Mode, and manual off: no Telegram message.
- `ls -l` on `~/Library/Application Support/Agrypnos/notif-secrets.json` is `-rw-------`.
- BotFather menu shows `/arm` `/disarm` `/status` `/help`.

## Unproven

- No `swift test` and no `xcodebuild` in this audit. Core tests were read, not run.
- The wake-miss apply window was not executed on a sleeping Mac. The code path is in the files cited under V1-TG-01. Whether `didWake` usually wins the race is unproven.
- Live `notif-secrets.json` mode was not stat'd.
- Live `setMyCommands` was not sent. `TelegramInboundHTTP.send` ignores the response (`TelegramInboundPoller.swift` 60–62), so a failed menu registration is also unproven on a bot.
- Codex waiting alerts and question notices use this bot token. They are not the Watch-end POST. Not scored.
