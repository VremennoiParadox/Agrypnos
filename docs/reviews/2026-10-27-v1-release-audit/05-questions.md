# Question relay

- verdict: HOLD
- blockers: 0
- high: 2
- scope: Question sources under `Apps/Agrypnos/Sources/Questions/`, `WatchRuntime+Questions.swift`, Core question types, question tests, Notif disclosure layout, and the popover question cards. Transport is in scope only when this slice builds a wrong payload. A transport that drops every bot message is a Telegram/Discord handoff.

## Product promise

With forwarding on, an OpenCode 1.18.32 terminal question or a Claude Code `AskUserQuestion` in that same session is sent to the user’s own Telegram or Discord bot. The user picks the listed choices, reviews, and presses Send answers. That selection goes back to the original request once. Answer on Mac closes the remote controls and does not pick an option. Free text and tool or plan approvals stay on the Mac.

A pending question holds an already-armed watch for up to 10 minutes. It does not arm the watch. If the question is still unanswered, Keep awake turns off with reason `questionUnanswered`, How long stays as the user set it, and a question notice is sent even when the idle-after-wait opt-in is off. Busy or unknown agent evidence delays that end. Confirmed lid-closed sleep uses the existing sleep path after the notice. Lid open does not sleep.

Codex can send a waiting or approval alert. That alert does not answer. Cursor cannot forward a question and cannot send a waiting alert. Full four-provider release stays gated.

Intentionally absent: Cursor forwarding, a Cursor waiting alert, a Codex answer, a second conversation, free-text submission, approval submission, and arming the watch from a question.

## Gates checked

| Gate | Result | Evidence |
|---|---|---|
| Cursor has no forward control and no waiting alert | PASS | Note only, no switch `QuestionSetupChrome.swift:4`, `PopoverController+Questions.swift:123-138`. No Cursor source under `Apps/Agrypnos/Sources/Questions/`. Guide says there is no setup `BotGuideCopy.swift:100-102` |
| Codex alert does not submit an answer | PASS | Notice text only `CodexAlertHook.swift:14-26`. Hook command writes empty stdout `CodexAlertHookProcess.swift:22-29`. `async: true` `CodexAlertHook.swift:57-58`. No reply RPC |
| OpenCode answer goes to the connection that asked, once | PASS | Reply is sent to `record.owner` with that key’s session and request `OpenCodePluginQuestionSource.swift:113-130`. Plugin rejects a second reply `agrypnos-opencode.js:147-153`. Host must be `1.18.32` `agrypnos-opencode.js:47-48` |
| Claude answer is the hook process that asked | PASS | Stdout is written on that connection’s fd `ClaudeQuestionHookSource.swift:62-68`. Key is that stdin’s `session_id` and `tool_use_id` `ClaudeAskUserQuestionPayload.swift:64-88`. Failure stdout is `{}` `ClaudeAskUserQuestionPayload.swift:5`, `:96-103` |
| Timeout does not pick an option | PASS | Expiry calls `returnLocal`, not `submit` `QuestionRelayCoordinator.swift:192-205`. Claude fallback is `{}`. Registry expiry ignores Send `QuestionRegistryTests.swift:84-89` |
| Relay does not start when forwarding is off | PASS | `receive` returns false when disabled `QuestionRelayCoordinator.swift:93-97`. OpenCode and Claude listeners stop unless forwarding, the tool, and a complete bot are on `WatchRuntime+OpenCodeQuestions.swift:32-38`, `WatchRuntime+ClaudeHook.swift:100-109` |
| Two bots cannot both submit | PASS | First Send reserves `.submitting` `QuestionRegistry.swift:115-117`. The other destination is ignored `QuestionRegistryTests.swift:23-34` |
| Wake-miss clicks are not applied | PASS | Telegram and Discord require `drain == .live` `QuestionRelayCoordinator.swift:139-140`, `:150-153` |
| Question cards do not sit on Agents, and Cursor is not an enable button | PASS | Agents cards stay the busy list `PopoverSection.swift:57-58`. Disclosure adds relay, OpenCode, Claude, Codex alerts, then the Cursor note `PopoverSection.swift:65-66`. Nil slots are hidden `PopoverForm.swift:27-29` |

## Findings

### V1-Q-01

- severity: HIGH
- confidence: high
- breaks: The popover says an unanswered question turns Keep awake off and asks the Mac to sleep. That end never runs. On Agents, the same quiet stretch can later end as idle-after-wait instead.
- evidence: Policy text: “After a question is recognized, Agrypnos waits 10 minutes for an answer. If none comes, and Keep awake is already on, Agrypnos asks the Mac to sleep.” `QuestionSetupChrome.swift:11`. The same promise is in the setup guide `BotGuideCopy.swift:132-134`. On an idle deadline the policy returns `.endUnanswered` immediately `QuestionWaitPolicy.swift:61-66`. `WatchEngine.tick` only special-cases `.hold` and `.deferTimeout`. `.endUnanswered` falls through, and only Agents mode can then `disengage(.agentsSettled)` `WatchEngine.swift:215-228`. Nothing emits `.disengage(.questionUnanswered)`. The notice and sleep path is behind that command `WatchRuntime+Poll.swift:210-216`, `:279-293`. The “turned off” notice is also skipped when the action is `.endUnanswered` `WatchRuntime+Questions.swift:90-91`. Core tests lock the miss: no `.questionUnanswered`, no sleep, watch stays engaged `QuestionWatchTests.swift:32-39`, and Agents settle is still allowed during `.endUnanswered` `QuestionWatchTests.swift:42-63`. The Mac test named for closed-lid sleep asserts `sleepRequests == 0`, the watch stays engaged, and the turned-off notice is absent `QuestionTimeoutRuntimeTests.swift:16-26`.
- trigger: Forwarding is on, Keep awake is already on, a real OpenCode or Claude question is recognized, 10 minutes pass, and the agent probe is idle. Repeat with How long set to ∞, 1h, 3h, or custom minutes. Repeat with How long set to Agents.
- expected: Idle at the deadline turns Keep awake off with `questionUnanswered`, leaves How long unchanged, sends “Agrypnos: Keep awake turned off because an agent question went unanswered for 10 minutes.”, and sleeps only if the lid is confirmed closed. Busy or unknown keeps the watch on and sends the stays-on sentence. This is not the idle-after-wait message.
- actual: The watch stays on at the deadline. No question-unanswered notice is sent. ∞, 1h, 3h, and custom never end because of the question. Agents can end later as `agentsSettled` with “Agrypnos: the wait after agent signals stop ended.” `AgrypnosCopy.swift:228-229`. `DiscordBotOutbound` correctly refuses a body for `.questionUnanswered` `DiscordBotOutbound.swift:26-27`, so that reason never gets a substitute sentence either.
- fix_files: `Sources/AgrypnosCore/Session/WatchEngine.swift`, `Tests/AgrypnosCoreTests/QuestionWatchTests.swift`, `Tests/AgrypnosMacTests/QuestionTimeoutRuntimeTests.swift`
- fix: When `questionWait.action == .endUnanswered`, return `disengage(.questionUnanswered)` before the Agents settle branch. Do not observe settle on that tick. Leave the existing `finishQuestionUnanswered` notice and lid re-check in place. Safety auto-off stays ahead of this branch.
- test_first: Change `testUnansweredEndUsesOwnReasonWithoutIdlePostOrChangingMode` so an idle `.endUnanswered` tick disengages `.questionUnanswered`, does not post idle-after-wait, does not change How long, and does not disengage `.agentsSettled`. Change `testUnansweredQuestionDoesNotBlockAgentsSettle` so `.endUnanswered` is not an Agents settle. Change `testVerifiedReleasePrecedesNoticeAndClosedLidSleep` so a closed lid sends the unanswered notice and then one sleep request. Watch those fail, then change `tick`.
- do_not: Do not pick an option or call `submit` on timeout. Do not relabel this end `agentsSettled`. Do not send `notifIdleBody` for it. Do not delete the popover sentence to match the current tests. Do not sleep when the lid is open or unconfirmed. Do not arm the watch.

### V1-Q-02

- severity: HIGH
- confidence: high
- breaks: Send answers is supposed to be the configured person. Any member of the saved Telegram chat or Discord channel can submit, and that submission is delivered to the original OpenCode request or Claude hook.
- evidence: The registry ignores a sender who is not `authorizedUserID` `QuestionRegistry.swift:84-91`, and the core test locks that for `"stranger"` versus `"owner"` `QuestionRegistryTests.swift:51-58`. The coordinator passes the clicker’s own id as both sender and authorized user `QuestionRelayCoordinator.swift:145-146` and `:158-159`. The Mac test then expects sender `"99"` on the saved chat to select `QuestionRelayCoordinatorTests.swift:157-160`. Secrets have token, chat id, bot token, and channel id, and no answering-user id `NotifSecretsPayload.swift:4-8`. A stored `telegramQuestionUserId` is not kept `TelegramQuestionTests.swift:76-79`. `SECURITY.md:65-67` still says the callback check includes the saved answering-user ID. The design requires that id; a shared chat or channel is not enough.
- trigger: Forwarding is on. The saved Discord channel or Telegram chat has a second person. A question is on the bot. The second person selects and presses Send answers.
- expected: The click is ignored. The original request is unchanged. Only the saved answering-user id can change the draft or send.
- actual: The click is applied. Send answers reserves the request and runs the provider `submit` closure for that original session.
- fix_files: `Sources/AgrypnosCore/Notif/NotifSecretsPayload.swift`, `Apps/Agrypnos/Sources/Questions/WatchRuntime+Questions.swift`, `Apps/Agrypnos/Sources/Questions/QuestionRelayCoordinator.swift`, `Apps/Agrypnos/Sources/MenuBar/PopoverController+Notif.swift`, `Tests/AgrypnosMacTests/QuestionRelayCoordinatorTests.swift`
- fix: Store one Telegram user id and one Discord user id with the existing 0600 secrets. A destination is complete only when its answering-user id is present. Pass that id as `authorizedUserID`. Keep the chat id and channel id checks.
- test_first: Change `testSameChatClickSelectsAndWakeMissOrOtherChatDoesNot` so sender `"99"` does not edit and does not submit, and the saved user id still can. Watch it fail, then wire the id.
- do_not: Do not treat “someone in the saved chat” as the user. Do not drop the destination check. Do not make a missing id mean everyone. Do not submit an answer from Agrypnos when the id does not match.

### V1-Q-03

- severity: MEDIUM
- confidence: high
- breaks: A question that does not fit Discord is left on the Mac with no bot message, including when Telegram could have carried it. The design says to say that it was left local.
- evidence: If Discord is complete and `canRender` fails, `receive` returns false before either bot is offered `QuestionRelayCoordinator.swift:98-100`. Render fails when the escaped body is over 2000 UTF-16 units `DiscordQuestionMessage.swift:116-119`. OpenCode remembers the key and drops the record without `.local` `OpenCodePluginQuestionSource.swift:99-103`. A later `asked` for that same key is ignored `OpenCodePluginQuestionSource.swift:99` and `OpenCodePluginQuestionSourceTests.swift:86-95`.
- trigger: Both bots are saved. OpenCode or Claude raises a choice question whose Discord-escaped text is over 2000 UTF-16 units. The user is away from the Mac.
- expected: The whole batch stays local, and the user is told it did not fit. Telegram is not silenced by a Discord length failure unless the product explicitly refuses both.
- actual: No bot message. No in-app sentence. The question remains only in the agent UI. That request id will not be offered again.
- fix_files: `Apps/Agrypnos/Sources/Questions/QuestionRelayCoordinator.swift`, `Apps/Agrypnos/Sources/Questions/OpenCodePluginQuestionSource.swift`, `Apps/Agrypnos/Sources/Questions/ClaudeQuestionHookSource.swift`
- fix: On `canRender` failure, return the question local and send one plain sentence that it was left on the Mac because it did not fit. Do not drop Telegram solely because Discord overflowed unless that sentence is actually sent.
- test_first: A batch that fails `canRender` with both destinations configured does not publish controls, and the test expects one explicit left-local notice. Watch it fail, then add the notice.
- do_not: Do not truncate choices. Do not invent an answer so the text fits.

## Handoffs

- TG/DC: Normal choice payloads go to the saved chat id or channel id `TelegramQuestionMessage.swift:4-8`, `DiscordQuestionMessage.swift:56-58`. If those HTTP calls fail for every message, that is transport. The missing 10-minute notice is not a dropped send. The runtime never asks for it. See V1-Q-01.
- WE: `tick` has to emit `.questionUnanswered` or V1-Q-01 stays broken. Agent-busy correctly said `.hold` and `.deferTimeout` skip settle `WatchEngine.swift:215-220`. `.endUnanswered` does not, and today it can become `agentsSettled`.
- Codex alerts post through `QuestionNoticeSender.deliver` and do not require the idle opt-in `WatchRuntime+CodexAlert.swift:121-144`. If those posts never leave the machine, that is TG/DC.

## Needs a Mac

- Claude Code, same session: choose B on the bot, the original session continues with B once. Answer on Mac shows the native picker and does not select B. Hook failure or timeout does not select an option.
- OpenCode 1.18.32 terminal: one new choice question arrives once, Send answers continues that session, and a second session does not receive the first answer.
- Codex: the alert says waiting or approval, the native picker stays, and no option is submitted.
- Cursor: the note is the only Cursor row. There is no enable control and no alert.
- Unanswered for 10 minutes with Keep awake already on: idle and lid confirmed closed turns the watch off, sends the unanswered sentence, and sleeps. Lid open turns the watch off and stays awake. Busy at the deadline stays on and sends the stays-on sentence.
- A second person in the saved Discord channel or Telegram chat cannot Send answers.

## Unproven

- This audit did not run the app. Claude hook acceptance by the installed Claude Code build is not re-proven here. The guide already says that path is not Mac-proven `BotGuideCopy.swift:91`.
- Codex alert delivery in the ChatGPT app on this build was not run. The hook source does not answer. Whether empty stdout keeps the picker is the earlier docs claim, not a new live check.
- The OpenCode plugin registers a `tui` entry only `agrypnos-opencode.js:196-198`. Whether the OpenCode desktop app loads that entry was not proven. The card help says 1.18.32 terminals `QuestionSetupChrome.swift:46`.
- Two OpenCode terminals receiving one `question.asked` would create two keys, because instance id is part of the key `OpenCodePluginQuestionSource.swift:65-74`. This audit did not prove the event is broadcast that way. The simultaneous-session matrix is still open in the milestone.
- Cursor forwarding remains absent on purpose. That absence is not a bug.
