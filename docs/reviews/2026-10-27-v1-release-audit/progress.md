# V1 release audit progress

Merged. Execute `REPORT.md`. Do not re-open the slices except to read a cited line.

Fix 1 (V1-Q-01 / V1-WE-01): complete, review SPEC PASS, quality approved. Not committed.
Fix 2 (V1-TG-01): complete, review SPEC PASS, quality approved. Not committed. The queued-ahead finish is a batch already returned while awake, not a command that arrived during sleep.
Fix 3 (V1-DOC-01): complete. Scope item 4 now matches Power A/B. Dropped the leftover "keyboard must go dark" sentence because the lid-open and confirmed-close sentences already say when the keyboard turns off. Not committed.
Fix 4 (V1-MAC-01): complete. Two delegated reviews stalled. Parent read the flag: it clears on arm, on the deferred sleep, and on every terminate exit. Confirmed-closed quit sleeps once. Open lid does not. Not committed.
Fix 5 (V1-MAC-02): complete. `finishDisengageHygiene` drops the capture only when `sleepnow == .ok`. A failure calls `restoreHygiene`. Power B still wakes the panel only when the lid read is not closed, which is the old nil path. Not committed.
Fix 6 (V1-MAC-03): complete. A nil lid sample does not clear a confirmed close and does not write brightness. Battery, timer, thermal, Low Power Mode, and agents still sleep on nil. User-off still requires a closed read. Not committed. Waiting on the user before Fix 7.

| Slice | File | Status | Verdict | Blockers | High |
|---|---|---|---|---|---|
| Safety | 03-safety.md | done | CLEAR | 0 | 0 |
| Invariants | 00-invariants.md | done | CLEAR | 0 | 0 |
| Watch engine | 01-watch-engine.md | done | BLOCK | 1 | 0 |
| Power / lid | 02-power-lid.md | done | CLEAR | 0 | 0 |
| Agent busy | 04-agent-busy.md | done | CLEAR | 0 | 0 |
| Questions | 05-questions.md | done | BLOCK | 1 | 1 |
| Telegram | 06-telegram.md | done | BLOCK | 1 | 2 |
| Discord | 07-discord.md | done | WARN | 0 | 0 |
| Popover | 08-popover-ui.md | done | WARN | 0 | 2 |
| Mac adapters | 09-mac-runtime.md | done | WARN | 0 | 2 |
| Docs | 10-docs-honesty.md | done | BLOCK | 1 | 1 |
| Ponytail | 11-ponytail.md | done | INFO | 0 | 0 |

## Verified from docs slice

Parent re-read the cited lines. These stay on the fix list. Doc-only. Do not change runtime to match the stale sentences.

- V1-DOC-01 BLOCKER, confirmed. `prd/v1-scope.md:5` and acceptance item 4 (`:18`) say engage requests real display sleep plus the floor. `WatchEngine` engage does not. Fix: replace those sentences with the landed rule (lid open: no display change; confirmed close + Power A: floor; confirmed close + Power B: panel sleep only). Do not call `displaysleepnow` on the toggle.
- V1-DOC-02 HIGH, confirmed. `QuestionSetupChrome.help` says "This works in the CLI and the desktop apps." OpenCode enable copy and `tui.json` are terminal-only. Delete that clause. Do not add a desktop installer.
- V1-DOC-03 MEDIUM, confirmed. `QuestionSetupChrome.policy` says an unanswered question asks the Mac to sleep, with no lid gate. Code sleeps only when the lid is confirmed closed. Replace the sentence so the lid gate is in the card. Do not make open-lid expiry call `sleepnow`.
- Parent add, same file, not in the slice report: `prd/v1-scope.md:21` says "Cursor + Claude Code + Codex only." The bar includes OpenCode. Doc-only. Add OpenCode to that sentence. Do not remove OpenCode from the app.

## Verified from popover slice

- V1-UI-01 HIGH, confirmed. The lid-gated user-off sentence exists only on the bot `/disarm` line (`BotGuideCopy.swift:245`). Keep awake hints in `AgrypnosCopy.swift` never say it. Copy only. Do not change the sleep gate.
- V1-UI-02 is the same sentence as V1-DOC-03. One fix. Grade it HIGH. Do not edit `QuestionSetupChrome.policy` twice.
- V1-UI-03 MEDIUM. Sleep panel hides brightness return and the visible caption does not say why. Prefer adding that one reason to the existing Sleep panel caption. Do not unhide a second help view unless the caption cannot hold the sentence.
- V1-UI-04 MEDIUM. Discord and Telegram inbound switches have no visible title. Use the existing `switchRow` titles. Default stays off.
- The desktop-apps sentence the popover slice left unproven is V1-DOC-02, already confirmed.

## Verified from Mac slice

- V1-MAC-01 HIGH, confirmed. Quit calls `setEngaged(false)` and then `NSApp.terminate` on the same turn (`PopoverController.swift:508-512`). A Discord watch-end send defers `sleepnow` onto `idlePostTask` (`WatchRuntime+Poll.swift:391-413`). `prepareForTermination` cancels that task (`WatchRuntime+Kernel.swift:59-61`), clears SleepDisabled, and restores brightness. The Mac stays awake. Fix: if that user-off already decided to sleep, spawn `sleepnow` after the kernel clear. Do not sleep when the lid is open or unconfirmed. Do not sudo it.
- V1-MAC-02 is the same bug as V1-MAC-SLEEP-RESTORE. One fix. The Mac slice adds a real trigger: `ProcessRunner` kills `pmset` after 3 seconds and stores that as failure (`ProcessRunner.swift:32-47`). `finishDisengageHygiene` then drops the saved brightness. Restore only when the outcome is `.failed`. Do not restore on a zero exit.
- V1-MAC-03 MEDIUM, confirmed. `pollLid` turns a nil clamshell read into open (`WatchRuntime+Lid.swift:18-20`). One missing sample clears a confirmed close, starts the brightness ramp, and can strip a safety or agents `sleepnow` (`WatchRuntime+Poll.swift:326-327`). Ignore a nil read. Timer expiry must still sleep when the read is nil. User-off must still not sleep on nil.

## Verified from question and Discord slices

- V1-Q-01 BLOCKER, confirmed. The slice called it HIGH. `WatchEngine.tick` handles `.hold` and `.deferTimeout` only (`WatchEngine.swift:215-228`). `.endUnanswered` falls through, so an idle deadline never returns `disengage(.questionUnanswered)`. `QuestionWatchTests.swift:32-39` locks that miss. On ∞, 1h, 3h, or custom, an unanswered question never turns Keep awake off. On Agents it can later end as idle-after-wait instead. Fix: disengage `.questionUnanswered` before the Agents settle branch. Do not submit an answer on timeout. Do not sleep when the lid is open. Change the test that expects the watch to stay on.
- V1-Q-02 HIGH, confirmed. `QuestionRelayCoordinator` passes the clicker's id as `authorizedUserID` (`QuestionRelayCoordinator.swift:145-146` and `:158-159`). The registry check then always matches. Anyone in the saved Telegram chat or Discord channel can Send the answer into the original session. `SECURITY.md:65-67` still requires a saved answering-user id. Fix: store that id and pass it through. A missing id must not mean everyone. A private chat with only you is the low-risk case tonight.
- V1-Q-03 MEDIUM. A question that does not fit Discord is dropped with no notice, including when Telegram could carry it. Keep it. Do not invent an answer.
- Discord does not have Telegram's wake-miss hole. Replay uses `recording`, which keeps the wake-miss flag (`DiscordGatewaySession.swift:53-57`). `acknowledging` runs on READY or RESUMED, after that replay. Do not copy the Telegram poller fix onto Discord.
- V1-DC-01 MEDIUM. Resume drops hosts like `gateway-us-east1-b.discord.gg`, so a wake may never see the queued commands and may never say "Missed while asleep." It does not apply them. Accept Discord resume hosts. Keep rejecting every other host.
- V1-DC-02 MEDIUM. A slash command in the wrong channel does not arm or disarm, and the reply is a blank character. Say it was not applied.

## Verified from Telegram slice

- V1-TG-01 BLOCKER, confirmed. `TelegramInboundCursor.acknowledging` always saves `seeded: true` and `wakeMiss: false` (`TelegramInbound.swift:161-166`). `init` also clears wake-miss whenever seeded (`:136`). Will-sleep only stores a wake-miss cursor (`WatchRuntime+TelegramInbound.swift:32-33`) and does not stop the poller. The sleep observer hops that save onto a later `Task` (`WatchRuntime+Kernel.swift:120-121`). The batch in hand is drained. The next `getUpdates` is live, so a command from sleep can still run. Fix: a wake-miss ack stays wake-miss until `noteMacDidWake`, and will-sleep invalidates the poller before it returns. Do not apply the backlog. The test `testWakeMissAckSeedsLiveAndClearsMiss` currently locks the bug. Change it.
- V1-TG-02 HIGH, confirmed. The shared Notif help says Telegram is messaged when the Mac is asked to sleep. `telegramBody` only returns text for timer expiry and agents settled. Copy fix. Do not add Telegram posts for disarm, battery, thermal, or Low Power Mode.
- V1-TG-03 HIGH, confirmed. Timer and idle Telegram text ignore `willSleep`. Discord already appends "Asking the Mac to sleep." Append that clause on those two Telegram bodies when `willSleep` is true. Do not say the Mac slept. Flip the closed-lid assertion in `TimedWatchRuntimeTests`.
- V1-TG-04 MEDIUM. A cold start treats a stored wake-miss cursor as a silent leftover drain. Keep it. Do not apply those commands.
- Discord's `acknowledging` has the same seeded-live shape (`DiscordInbound.swift:190-200`). If the Discord slice misses it, keep it as the sibling of V1-TG-01.

## Verified from power slice

Core gates pass. One execution bug the slice handed to Mac, confirmed in code:

- V1-MAC-SLEEP-RESTORE HIGH. `finishDisengageHygiene` treats any non-nil `sleepnow` as success and drops the saved brightness (`WatchRuntime+Poll.swift:359-361`). A failed `pmset sleepnow` is still non-nil (`.failed`) (`PmsetCommandOutcome.swift:10-12`, `PowerHygieneCoordinator.swift:44-45`). The Mac stays awake, the panel stays at the floor, and the keyboard stays off. Fix: drop the saved restore only when `sleepnow == .ok`. On `.failed`, call `restoreHygiene()`. Do not sleep again. Dedup if the Mac slice files the same lines.

Display-list skip stays a Mac check, not a code change. Power A floor already passed on this Mac before. Change it only if a confirmed lid close tonight leaves the panel bright.

## Needs a Mac before release

- Agents mode: if one session-folder scan takes longer than 15 seconds, or hits the 4000-visit cap, that scan counts as unknown, not idle (`AgentProbeObservation.swift:21-24`). Keep awake then stays on until a later scan finishes under 15 seconds. Do not change this tonight unless a scan on this Mac actually does that. It is what stops a half-finished scan from looking idle.

## Ponytail appendix

Not a bug list. Do not execute these cuts in the V1 fix pass.

- Do not delete `Apps/Agrypnos/Resources/grant.sh`. `GrantInstaller` loads `Bundle.main` `grant.sh` first (`GrantAndNotify.swift:27-28`). The `Scripts/grant.sh` path is only the unpackaged fallback. Deleting the bundled copy breaks the sudoers install inside the app.
- The other 9 cuts are line savings (about 340). None are release blockers. The 11 `keep:` rows stay, including nil brightness capture and lid confirm.

## Fold into merge

- Safety left this unproven, not a finding: a watch-end bot send can hold SleepDisabled until `NotifIdlePoster` returns (`WatchRuntime+Poll.swift:230-248`). Mac slice should already own it. If that slice misses it, check it before the fix list ships.
- `SECURITY.md:18` still says I2 is not Mac-proven. Docs slice should already own stale proof labels.

The user chose do 7 and finish the list.
