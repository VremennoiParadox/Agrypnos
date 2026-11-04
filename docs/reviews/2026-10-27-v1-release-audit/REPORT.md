# V1 release fix list

Execute top to bottom. One fix, then its test, then the next fix. Do not batch unrelated edits.

Slice notes live next to this file. This file is the work order. If a slice and this file disagree, this file wins. It was checked against the source lines named below.

## How to execute

1. Read the fix. Read the cited lines. Do not trust a summary you have not opened.
2. Change the named test so it expects the correct behavior. Run it. Watch it fail.
3. Make the smallest code change in the named function. Run that test. Watch it pass.
4. Do not do the `do_not` line. That line is a wrong fix that makes the bug look solved.
5. Leave files you were not told to touch.

Product law is `AGENTS.md`. Do not "fix" the app so it matches a stale sentence in `prd/v1-scope.md`.

## Do not touch

These were checked and match the bar. A fixer who "simplifies" them ships a new bug.

- Lid-close hygiene waits for a stable closed confirm. One `AppleClamshellState` sample applies nothing.
- Brightness floor is written only when armed, lid confirmed closed, and Power A. Nil capture does not write a brightness. Power B does not write the floor.
- Power B `displaysleepnow` is the panel only. It does not turn Keep awake off and it does not `pmset sleepnow`.
- User-off and inbound `/disarm` sleep only when the lid is confirmed closed. Timer expiry still sleeps when the lid is not known open. Those are different rules. Do not merge them.
- Already-off plus confirmed closed still requests `sleepnow`.
- Never-busy this arm does not post and does not disarm. Terminal sessions count as busy only when that preference is on. Default is off. OpenCode is not CPU-busy. Empty agent selection is not saved.
- Safety auto-off, the 5–100% battery slider, thermal default on, and the two-command sudoers grant are correct. `sleepnow` is not a sudoers command.
- Discord wake-miss replay stays unseeded until READY or RESUMED. Do not copy the Telegram poller fix onto Discord.
- Do not delete `Apps/Agrypnos/Resources/grant.sh`. The installed app runs that copy. `Scripts/grant.sh` is only the fallback when the app is launched from the source folder.
- Do not apply the line cuts in `11-ponytail.md` during this fix pass.

## Cleared

| Slice | File | Result |
|---|---|---|
| Danger-call sweep | `00-invariants.md` | No illegal sleep, display sleep, brightness write, secret leak, listen port, or webhook |
| Watch engine, except Fix 1 | `01-watch-engine.md` | Sleep matrix matches the bar |
| Power / lid decisions | `02-power-lid.md` | Floor and panel sleep stay behind a confirmed close |
| Safety | `03-safety.md` | Battery, thermal, leftover Low Power Mode, sudoers |
| Agent busy | `04-agent-busy.md` | Selection, I3 default off, OpenCode, settle grace, never-busy |
| Discord command apply | `07-discord.md` | No webhook, no listen port, no second arm stack. Two mediums are Fix 14 and Fix 15 |

## Work order

| Fix | ID | Grade | One line |
|---|---|---|---|
| 1 | V1-Q-01 | BLOCKER | Unanswered question never turns Keep awake off |
| 2 | V1-TG-01 | BLOCKER | A Telegram command from sleep can still run |
| 3 | V1-DOC-01 | BLOCKER, doc only | Scope doc says arming sleeps the display |
| 4 | V1-MAC-01 | HIGH | Quit cancels a confirmed-closed sleep |
| 5 | V1-MAC-02 | HIGH | A failed `sleepnow` throws away brightness and keyboard |
| 6 | V1-MAC-03 | MEDIUM | A missing lid reading is treated as open |
| 7 | V1-Q-02 | HIGH | Anyone in the saved chat can Send the answer |
| 8 | V1-TG-03 | HIGH | Telegram timer and idle texts omit the sleep clause |
| 9 | V1-TG-02 | HIGH | Notif help says Telegram posts on every sleep |
| 10 | V1-UI-01 | HIGH | Keep awake never says a closed-lid off sleeps the Mac |
| 11 | V1-DOC-03 | HIGH | Question card omits the lid on that sleep sentence |
| 12 | V1-DOC-02 | HIGH | Question help says desktop apps work |
| 13 | V1-TG-04 | MEDIUM | Cold start swallows a stored wake-miss reply |
| 14 | V1-DC-01 | MEDIUM | Discord resume host is rejected |
| 15 | V1-DC-02 | MEDIUM | Wrong-channel slash replies with a blank |
| 16 | V1-Q-03 | MEDIUM | A too-long Discord question is dropped with no notice |
| 17 | V1-UI-03 | MEDIUM | Sleep panel does not say why brightness return is gone |
| 18 | V1-UI-04 | MEDIUM | Inbound switches have no visible name |
| 19 | V1-DOC-04 | MEDIUM, doc only | Scope doc omits OpenCode |

Same bug, one fix: V1-WE-01 is Fix 1. V1-UI-02 is Fix 11. The power-slice name V1-MAC-SLEEP-RESTORE is Fix 5.

---

## Fix 1 — V1-Q-01 Unanswered question never turns Keep awake off

- grade: BLOCKER
- also: V1-WE-01
- breaks: The card says an unanswered question turns Keep awake off. `tick` never does that. On ∞, 1h, 3h, or custom minutes the Mac stays awake. On Agents the same quiet stretch can later end as `agentsSettled` and send the idle-after-wait message.
- evidence: `Sources/AgrypnosCore/Session/WatchEngine.swift:215-228` handles `.hold` and `.deferTimeout` only. `.endUnanswered` falls through. `Tests/AgrypnosCoreTests/QuestionWatchTests.swift:32-39` asserts the watch stays engaged and that `.questionUnanswered` is absent. The notice and the lid re-check already exist and are never asked to run: `Apps/Agrypnos/Sources/WatchRuntime+Poll.swift:279-306`.
- fix: In `WatchEngine.tick`, when `questionWait.action == .endUnanswered`, return `disengage(.questionUnanswered)` before the Agents settle branch. Do not call `settle.observe` on that tick. Safety auto-off stays ahead of this branch. Leave `finishQuestionUnanswered` in place. It already re-checks the lid before `sleepnow`.
- test_first: Change `testUnansweredEndUsesOwnReasonWithoutIdlePostOrChangingMode` so an idle `.endUnanswered` tick disengages `.questionUnanswered`, does not post idle-after-wait, does not change How long, and does not disengage `.agentsSettled`. Change `testUnansweredQuestionDoesNotBlockAgentsSettle` so `.endUnanswered` is not an Agents settle. In `Tests/AgrypnosMacTests/QuestionTimeoutRuntimeTests.swift`, a confirmed-closed idle deadline sends the unanswered notice and then one sleep request. An open lid sends the notice and does not sleep.
- do_not: Do not submit an answer on timeout. Do not relabel the end `agentsSettled`. Do not delete the popover sentence to match the old test. Do not sleep when the lid is open or unconfirmed. Do not arm the watch.

## Fix 2 — V1-TG-01 A Telegram command from sleep can still run

- grade: BLOCKER
- breaks: Inbound is on. A command that arrives while the Mac is asleep can be applied after the wake-miss batch is acked, because the next poll is live and the poller never stops for sleep.
- evidence: `Sources/AgrypnosCore/Notif/TelegramInbound.swift:136` clears wake-miss whenever `seeded` is true. `:161-166` `acknowledging` always saves `seeded: true` and `wakeMiss: false`. `Apps/Agrypnos/Sources/Notif/WatchRuntime+TelegramInbound.swift:27-34` saves a wake-miss cursor and does not stop the poller. `Apps/Agrypnos/Sources/WatchRuntime+Kernel.swift:120-121` hops will-sleep onto a later `Task`. `finishTelegramInboundPoll` (`WatchRuntime+TelegramInbound.swift:80-83`) drains the batch in hand with the stored cursor, then saves the live ack.
- fix: A wake-miss ack stays `seeded: false` and `wakeMiss: true` until `noteMacDidWake` promotes it. Will-sleep invalidates the poller before `noteMacWillSleep` returns, on the notification queue, not inside a deferred `Task`. Do not start another `getUpdates` until wake. One drain enum. One chat-id check.
- test_first: Change `testWakeMissAckSeedsLiveAndClearsMiss` so a wake-miss ack does not become a live cursor and does not apply. Add a cursor test that a stored wake-miss cursor stays wake-miss across ack until an explicit post-wake promotion. An in-flight finish whose generation was bumped by will-sleep does not save a seeded cursor and does not call `setEngaged` or `disarmWatch`.
- do_not: Do not apply the backlog on wake. Do not add a second allowlist. Do not treat a poller start after sleep as a silent leftover drain. Do not copy this fix onto Discord. Discord replay already stays unseeded until READY or RESUMED (`Sources/AgrypnosCore/Notif/DiscordGatewaySession.swift:50-57`).

## Fix 3 — V1-DOC-01 Scope doc says arming sleeps the display

- grade: BLOCKER, doc only
- breaks: `prd/v1-scope.md` tells a later editor to sleep the display when Keep awake turns on, and to write the floor at the same time.
- evidence: `prd/v1-scope.md:5` "The display must actually sleep." `:18` acceptance item 4, "Engage requests real display sleep, keyboard backlight off, brightness floor." Engage with the lid open emits `.engage` only (`WatchEngine.swift:285-294`). Display sleep requires armed, confirmed close, and Power B (`PanelPowerMode.swift:35-40`).
- fix: Replace those two sentences with the landed rule. Lid open: no display change and no keyboard change. Confirmed close plus Power A: brightness floor, keyboard off, panel stays on. Confirmed close plus Power B: panel sleep only, keyboard off, Keep awake stays on. Never floor and `displaysleepnow` together.
- test_first: None. `PanelPowerMode.shouldSleepDisplay` already locks the gate. Do not add a test that engage requests display sleep.
- do_not: Do not call `displaysleepnow` on the Keep awake toggle or while the lid is open. Do not implement acceptance item 4 as written.

## Fix 4 — V1-MAC-01 Quit cancels a confirmed-closed sleep

- grade: HIGH
- breaks: Lid confirmed closed, Notif on, Discord token and channel id saved. Quit clears the wake hold and restores the screen. `sleepnow` never runs. The Mac stays awake.
- evidence: `Apps/Agrypnos/Sources/MenuBar/PopoverController.swift:508-512` calls `setEngaged(false)` and then `NSApp.terminate`. `shouldAwaitWatchEndPost` is true for a Discord user-off that will sleep (`WatchRuntime+Poll.swift:339-356`, `DiscordBotOutbound.swift:17`). `applyUserOff` schedules `idlePostTask` and returns before `sleepnow` (`WatchRuntime+Poll.swift:391-413`). `prepareForTermination` cancels that task (`WatchRuntime+Kernel.swift:59-61`). The engine is already disengaged, so the fallback at `:70-72` does not run. `:74-75` restores hygiene and does not sleep.
- fix: If the in-flight user-off already decided to sleep, spawn that `sleepnow` after the kernel clear inside `prepareForTermination`. If terminate itself turns a still-armed watch off, pass the live `userOffLidCloseConfirmed` result instead of `lidClosed: false`.
- test_first: Two closed samples, Notif on, Discord token and channel id set, `setEngaged(false)`, then `prepareForTermination()`. Assert one `sleepnow` and a cleared kernel. `lidClosed = false` asserts zero sleep requests.
- do_not: Do not `sleepnow` when the lid is open or unconfirmed. Do not sudo `sleepnow`. Do not skip the Discord send on a quit that is still alive long enough to send it. The confirmed-closed quit still calls `sleepnow` either way.

## Fix 5 — V1-MAC-02 A failed sleepnow throws away brightness and the keyboard

- grade: HIGH
- also: V1-MAC-SLEEP-RESTORE
- breaks: `pmset sleepnow` fails, or the runner kills it at 3 seconds. The Mac stays awake. The saved brightness is discarded. The panel stays at the floor. The keyboard stays off.
- evidence: Every exit is stored, including failure (`PowerHygieneCoordinator.swift:44-45`, `PmsetCommandOutcome.swift:10-12`). `ProcessRunner` deadline is 3 seconds and a timeout returns `-2` (`Apps/Agrypnos/Sources/Support/ProcessRunner.swift:5`, `:32-47`). `finishDisengageHygiene` treats any non-nil `sleepnow` as success and calls `dropSavedHygieneWithoutWrite` (`WatchRuntime+Poll.swift:359-361`).
- fix: Call `dropSavedHygieneWithoutWrite` only when `sleepnow == .ok`. On `.failed`, call `restoreHygiene()`. Leave SleepDisabled clear. Do not spawn `sleepnow` again.
- test_first: Set a saved brightness and keyboard, set the floor and keyboard effect flags, and make `runCommand` return exit 1 for `sleepnow`. Drive `finishDisengageHygiene`. Assert the brightness writer received the capture, the keyboard writer received the capture, and the floor was not written again. A zero exit still drops the restore.
- do_not: Do not restore on a zero exit. That turns the panel and keyboard back on as the Mac goes to sleep. Do not write the floor when the capture is nil.

## Fix 6 — V1-MAC-03 A missing lid reading is treated as open

- grade: MEDIUM
- breaks: One nil `AppleClamshellState` sample clears a confirmed close, starts the brightness ramp, wakes the panel under Power B, and can strip a safety or agents `sleepnow`.
- evidence: `pollLid` uses `readLid() == true`, so nil becomes false (`WatchRuntime+Lid.swift:18-20`). `removeSleepIfLidOpen` removes safety and agents sleep when `rawClosed != true` (`WatchRuntime+Poll.swift:326-327`). Timer expiry removes sleep only when `rawClosed == false`. That timer line is correct.
- fix: If `readLid()` is nil, skip `observeLid` and skip the agents-hold re-sample. In `removeSleepIfLidOpen`, remove safety and agents `.requestSleep` only when the read is `false`.
- test_first: Confirm the lid with two closed samples, set the next read to nil, call `pollLid`. Assert the confirmed flag stays true and the brightness writer was not called. A battery disengage that contains `.requestSleep`, with the read still nil, asserts one sleep request. A read of `false` asserts zero.
- do_not: Do not make user-off or inbound `/disarm` sleep on nil. Do not make timer expiry stop sleeping on nil. Do not treat one raw closed sample as a new confirm.

## Fix 7 — V1-Q-02 Anyone in the saved chat can Send the answer

- grade: HIGH
- breaks: The registry checks `authorizedUserID`, then the coordinator passes the clicker's own id as that value. Any member of the saved Telegram chat or Discord channel can submit into the original OpenCode or Claude session.
- evidence: `Apps/Agrypnos/Sources/Questions/QuestionRelayCoordinator.swift:145-146` and `:158-159`. `SECURITY.md:65-67` requires the saved answering-user id. Secrets today have no answering-user field (`NotifSecretsPayload.swift:4-8`).
- fix: Store one Telegram user id and one Discord user id in the existing `notif-secrets.json` (mode 0600). A destination is complete only when its answering-user id is present. Pass that stored id as `authorizedUserID`. Keep the chat id and channel id checks.
- test_first: Change `testSameChatClickSelectsAndWakeMissOrOtherChatDoesNot` so sender `"99"` does not edit and does not submit, and the saved user id still can.
- do_not: Do not treat "someone in the saved chat" as the user. Do not drop the destination check. Do not make a missing id mean everyone. Do not submit an answer when the id does not match. A private chat that contains only the owner is the low-risk case until this lands. Do not ship a second secrets file.

## Fix 8 — V1-TG-03 Telegram timer and idle texts omit the sleep clause

- grade: HIGH
- breaks: When the timer post or the idle-after-wait post is also the send that will `sleepnow`, Telegram never says "Asking the Mac to sleep."
- evidence: `NotifIdlePoster.requests` takes `willSleep`. Discord uses it (`NotifIdlePoster.swift:29-48`). `telegramBody` does not (`:69-77`). `TimedWatchRuntimeTests.swift:239-248` asserts the closed-lid Telegram body has no sleep sentence.
- fix: Pass `willSleep` into `telegramBody`. For `.timerExpired` and `.agentsSettled` only, append ` Asking the Mac to sleep.` when `willSleep` is true.
- test_first: Flip the closed-lid assertion to expect `Agrypnos: your Keep awake timer ended. Asking the Mac to sleep.` and the idle body plus the same clause. Keep the open-lid assertion with no clause (`TimedWatchRuntimeTests.swift:231-237`). Assert `.user`, `.batteryFloor`, `.thermal`, and `.lowPowerMode` still produce no Telegram request.
- do_not: Do not say the Mac slept. Do not add Telegram posts for battery, thermal, Low Power Mode, or manual off. Do not change the Discord body in this fix.

## Fix 9 — V1-TG-02 Notif help says Telegram posts on every sleep

- grade: HIGH
- breaks: The Watch-end POST switch says Telegram is messaged when Agrypnos asks the Mac to sleep. Confirmed-closed `/disarm`, battery, thermal, and Low Power Mode do not send a Telegram post.
- evidence: `Sources/AgrypnosCore/Copy/AgrypnosCopy.swift:186-187`. `telegramBody` returns nil for every reason except `.timerExpired` and `.agentsSettled` (`NotifIdlePoster.swift:69-77`). Discord's own card is the accurate one (`AgrypnosCopy.swift:189-190`).
- fix: Split the sentence. Telegram: timer expiry, and the wait after busy was seen. Discord: those, plus when this disengage will `sleepnow`.
- test_first: Assert `notifEnabledHelp` does not say the Telegram bot is messaged when Agrypnos asks the Mac to sleep, and that it still says the timer and the idle-after-wait do message.
- do_not: Do not start Telegram posts for `.user`, `.batteryFloor`, `.thermal`, or `.lowPowerMode` to make the old sentence true.

## Fix 10 — V1-UI-01 Keep awake never says a closed-lid off sleeps the Mac

- grade: HIGH
- breaks: Turning Keep awake off with the lid confirmed closed sends the Mac to sleep. The popover never says that. The sentence exists only on the bot `/disarm` line.
- evidence: Infinity hint is "Stays on until you turn it off (battery / thermal still apply)." `AgrypnosCopy.swift:37-38`. The lid sentence is `BotGuideCopy.swift:245`. The popover shows `durationHint` (`PopoverController.swift:314-320`). The sleep itself is `WatchRuntime+Poll.swift:374-389`.
- fix: Add one sentence on the Keep awake path the popover already shows. Turning it off with the lid confirmed closed sends the Mac to sleep. With the lid open or unconfirmed it turns Keep awake off and does not sleep the Mac. Keep the timer-expiry hint as the timer sentence.
- test_first: Extend `Tests/AgrypnosCoreTests/AgrypnosCopyTests.swift` so infinity, Agents, and the off state include that lid sentence, and so none of them say disarm always sleeps.
- do_not: Do not change `applyUserOff` or the lid gate. Do not say the Mac already slept. Do not add a second sleep path.

## Fix 11 — V1-DOC-03 Question card omits the lid

- grade: HIGH
- also: V1-UI-02
- breaks: After Fix 1, the card's sleep sentence is true only when the lid is confirmed closed. Today it states the sleep with no lid condition.
- evidence: `QuestionSetupChrome.swift:11`. Sleep for that end is gated again at `WatchRuntime+Poll.swift:279-305`.
- fix: One sentence. Keep awake turns off. The Mac is asked to sleep only when the lid is confirmed closed. Keep the 10-minute wait and the busy-agent delay.
- test_first: Assert `QuestionSetupChrome.policy` says the sleep happens when the lid is confirmed closed, and that it does not say the Mac always sleeps.
- do_not: Edit this string once. Do not also apply a second patch from the popover slice. Do not make open-lid expiry call `sleepnow`. Do this after Fix 1 so the sentence matches the code.

## Fix 12 — V1-DOC-02 Question help says desktop apps work

- grade: HIGH
- breaks: `QuestionSetupChrome.help` says "This works in the CLI and the desktop apps." OpenCode setup registers `tui.json` and the enable line says terminals.
- evidence: `QuestionSetupChrome.swift:10` and `:46`. `OpenCodePluginInstaller.swift:16`. `README.md:289-290` already says desktop clients are not verified.
- fix: Delete the clause "This works in the CLI and the desktop apps."
- test_first: Assert `QuestionSetupChrome.help` does not contain "desktop apps".
- do_not: Do not add a desktop OpenCode installer to make the sentence true.

## Fix 13 — V1-TG-04 Cold start swallows a stored wake-miss reply

- grade: MEDIUM
- breaks: If the process dies during sleep, the next launch acks commands that arrived while asleep and does not reply "Missed while asleep." It does not apply them.
- evidence: `noteMacWillSleep` sets the wake-miss bit. A new process calls `startingSession`, which clears `wakeMiss` (`TelegramInbound.swift:151-154`). Leftover dispatch drops the command with no reply (`TelegramInboundPolish.swift:41-42`).
- fix: If the loaded cursor is wake-miss, start that session as wake-miss. `startingSession` remains the path for setup, quit, and inbound off.
- test_first: A cursor with `wakeMiss == true` and `seeded == false` stays wake-miss, and `/arm` effects `.missedWhileAsleep`. A normal unset cursor stays leftover and does not reply.
- do_not: Do not apply those commands. Do not mark every launch as wake-miss.

## Fix 14 — V1-DC-01 Discord resume host is rejected

- grade: MEDIUM
- breaks: After sleep or a dropped socket, Agrypnos discards Discord's regional resume host. The missed-command reply may never be sent. The commands are not applied, and channel history is not scraped.
- evidence: `resumeURL` keeps a host only when it `hasSuffix("gateway.discord.gg")` (`DiscordInboundRequest.swift:190-191`). Discord's live host looks like `wss://gateway-us-east1-b.discord.gg`, which does not match. Tests only round-trip `wss://us-east.gateway.discord.gg`.
- fix: Accept `wss` hosts that are `gateway.discord.gg`, end with `.gateway.discord.gg`, or are `gateway-` plus `.discord.gg`. Reject every other host.
- test_first: `resumeURL(from: "wss://gateway-us-east1-b.discord.gg")` returns that host. `wss://evil.example` and `wss://gateway.discord.gg.evil.com` stay nil.
- do_not: Do not resume to an arbitrary URL. Do not scrape channel history when resume fails. Do not open a listen port or set an Interactions Endpoint URL.

## Fix 15 — V1-DC-02 Wrong-channel slash replies with a blank

- grade: MEDIUM
- breaks: `/arm` or `/disarm` outside the saved channel does not change the watch. The slash interaction completes as a zero-width space, so Discord shows neither "Armed." nor a failure.
- evidence: Ignore replies with U+200B (`WatchRuntime+DiscordInbound.swift:179-180`). Wrong-channel intent is `.ignore` (`DiscordInbound.swift:50-52`).
- fix: For a slash ignore, edit the deferred reply to one sentence that the command was not applied.
- test_first: A slash update whose channel id is not the saved id produces a non-empty reply and does not arm or disarm. A matching channel still applies.
- do_not: Do not apply the foreign-channel command. Do not drop the deferred ack and leave the interaction failed.

## Fix 16 — V1-Q-03 A too-long Discord question is dropped with no notice

- grade: MEDIUM
- breaks: If Discord cannot render the question, neither bot is offered it, and the user is not told it stayed on the Mac. That request id is not offered again.
- evidence: `QuestionRelayCoordinator.swift:98-100` returns before Telegram when `canRender` fails. Render fails over 2000 UTF-16 units (`DiscordQuestionMessage.swift:116-119`).
- fix: On `canRender` failure, leave the question local and send one plain sentence that it did not fit. Do not drop Telegram solely because Discord overflowed unless that sentence is actually sent.
- test_first: A batch that fails `canRender` with both destinations configured does not publish controls, and the test expects one explicit left-local notice.
- do_not: Do not truncate choices. Do not invent an answer so the text fits.

## Fix 17 — V1-UI-03 Sleep panel does not say why brightness return is gone

- grade: MEDIUM
- breaks: Power B hides the ramp. The visible caption does not say the ramp only applies when restoring from the floor path.
- evidence: The ramp card is omitted (`PopoverStackLayout.swift:280-282`). B help is created and then hidden (`PopoverController+Cards.swift:228-241`).
- fix: Add that one reason to the existing Sleep panel caption. Do not unhide a second help view unless the caption cannot hold the sentence. Do not show the ramp slider under B.
- test_first: Assert the B caption contains the floor-path reason. Assert A still does not say display asleep or screen off.
- do_not: Do not rewrite the A/B captions into marketing. Do not add a watt claim.

## Fix 18 — V1-UI-04 Inbound switches have no visible name

- grade: MEDIUM
- breaks: The Discord and Telegram inbound rows are a switch with no title. Telegram VoiceOver says "Telegram", which is the card title.
- evidence: `switchControl` draws no title (`PopoverController+Notif.swift:83-95` and `:142-153`). The strings already exist (`AgrypnosCopy.swift:200-205`).
- fix: Use `switchRow` with `AgrypnosCopy.notifDiscordInbound` and `AgrypnosCopy.notifTelegramInbound`. Set the Telegram accessibility label to "Telegram inbound".
- test_first: The existing copy tests already lock the title strings. No new Core test will see an AppKit label. After the card builder uses `switchRow`, read those two call sites.
- do_not: Do not add a second inbound card or a webhook field. Do not change the default. It is off (`UserPreferences.swift:66-67`).

## Fix 19 — V1-DOC-04 Scope doc omits OpenCode

- grade: MEDIUM, doc only
- breaks: `prd/v1-scope.md:21` says "Cursor + Claude Code + Codex only." The app includes OpenCode.
- fix: Add OpenCode to that sentence. Local process and session files only. Not CPU.
- test_first: None.
- do_not: Do not remove OpenCode from the app to match the old sentence.

---

## After the code fixes, check on this Mac

Do not write code for these unless the check fails.

1. Arm with the lid open. The panel does not sleep and the keyboard stays as it was.
2. Power A, confirmed close: panel goes to the floor, keyboard off, panel still on. Reopen: brightness returns. Turn Keep awake off with the lid open and use the Mac. It must not dim to the floor by itself.
3. Power B, confirmed close: the panel sleeps, Keep awake stays on. Open the lid. The panel comes back.
4. Confirmed-closed Quit, with Discord watch-end on: the Mac sleeps. Lid open Quit: Keep awake off, Mac stays awake.
5. If `pmset sleepnow` fails or is killed at 3 seconds: the screen and keyboard come back. They do not stay at the floor.
6. Telegram inbound on. Send `/arm` while the Mac is asleep. On wake the watch is unchanged and the chat gets "Missed while asleep."
7. Question forwarding on, Keep awake on, one real question, no answer for 10 minutes. Idle: Keep awake turns off. Lid open: the Mac stays awake. Lid confirmed closed: the Mac is asked to sleep. No answer is submitted.
8. Agents mode: a session-folder scan longer than 15 seconds, or a walk that hits the 4000-visit cap, counts as unknown, not idle (`AgentProbeObservation.swift:21-24`). Leave that alone unless a scan on this Mac actually does it. It is what stops a half-finished scan from looking finished.

## Stale proof labels

`README.md`, `SECURITY.md:18`, and the bot setup still say some Discord, I2, Claude, and Codex checks are not done. `AGENTS.md` records those as user-confirmed on 2026-10-11. They underclaim. They do not teach a wrong action. Do not edit them in this pass unless you are already touching that sentence for a fix above.
