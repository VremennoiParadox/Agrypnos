# Blocked-question notify (no answer-back)

Date: 2026-10-06. Tree: `/Users/imightbeoufu/Developer/Agrypnos` on `codex-question-sup`.
Research only. No Swift edits. No commit. No push. No Cursor/Codex protocol invented.

The user may scrap question-forwarding (answer-back) because Cursor and Codex cannot take a remote answer, and setup is heavy. They still want, for Cursor and Codex and for people who leave forwarding off, a notice that the agent is **paused because of a question or another named reason** — and that this must be **different from “the agent stopped work.”**

This note maps what Agrypnos can already tell the user, and what a new “waiting on you” notice would have to avoid. It is not an implementation plan.

## Binding copy (AGENTS.md)

These sentences bind any new notice. They are product rules, not suggestions.

Outbound idle-after-wait is **not** “agent stopped”:

> One-shot POST when Agents mode is armed, local busy signals were **seen this arm**, then stayed quiet through the idle wait (`agentSettleGrace`). Event is **idle after wait**, not “agent stopped / job done / still thinking.” Never-busy this arm is not that event — do not POST. That same settle also turns Keep the watch off. Do not POST for timer, battery, thermal, LPM, or manual off. Outbound body uses the same idle-after-wait honesty (ban “agent stopped” / “job finished” there too). (`AGENTS.md` 121)

Ban on those phrases everywhere Notif talks:

> Ban “we notify your phone”, “agent stopped”, “job finished”, live-asleep replies, “disarm always sleeps”. (`AGENTS.md` 138)

> Ban “agent stopped / job finished / still thinking.” (`AGENTS.md` 123, Telegram inbound; same ban at 155 for Discord inbound)

Idle wait is local process/session quiet, not mind-reading:

> we do **not** know “still thinking” or “agent finished the job.” Ban copy that claims that. (`AGENTS.md` 107)

> Not still thinking — we only see local process and session activity. (`AGENTS.md` 108, 259; product help `AgrypnosCopy.settleGraceHelp` at `Sources/AgrypnosCore/Copy/AgrypnosCopy.swift` 17–18)

Explicit bad outbound copy:

> Bad: “We notify your phone.” / “Agent stopped.” / “Job finished.” (Notif outbound is idle after wait; POST to *your* webhook / message *your* Telegram bot. Telegram or Discord `/status` dumps live watch facts, not that the agent stopped. (`AGENTS.md` 295)

Notification Center is **not** an allowed Notif channel:

> Notification Center as the Notif path stays idea-only. Do not unlock. (`AGENTS.md` 144, 185, 195)

Allowed Notif destinations today (user-owned, no new bot): Discord **incoming webhook URL** (outbound POST only) and Telegram **token + chat id** (`sendMessage`). Discord **bot token + channel id** is inbound (and question-forwarding notices), not the idle webhook. (`AGENTS.md` 135)

Native-question design (same honesty, not a watch-end claim):

> Question detection is evidence of a pending question only. It does not replace existing busy heuristics, prove task completion, or identify ordinary questions in prose. (`docs/superpowers/specs/2026-09-29-native-agent-questions-design.md` 22)

---

## 1. The current “agents went quiet” message must not be reused

There are **two** landed quiet-agent strings. Both fire on the same watch-end. Neither means “paused on a question.”

| Surface | Literal text | Type / function | When |
| --- | --- | --- | --- |
| Telegram/Discord outbound body | `Agrypnos: local busy signals went idle after the wait.` | `AgrypnosCopy.notifIdleBody` (`AgrypnosCopy.swift` 216–217) posted by `NotifIdlePoster.postIfNeeded` (`NotifIdlePoster.swift` 19–27) | `WatchCommand.postIdleAfterWaitNotif` |
| Local Mac `osascript` banner | `Agents idle. Watch turned off.` | `AgrypnosCopy.agentsEnded` (`AgrypnosCopy.swift` 60), via `AgrypnosCopy.notification(for: .agentsSettled)` (107–113) and `UserNotify.post(reason:)` (`GrantAndNotify.swift` 18–20) | After kernel clear on `.agentsSettled` (`WatchRuntime+Poll.swift` 273) |
| Last-end caption | `Last watch ended at …, because local busy signals stayed idle after the wait.` | `AgrypnosCopy.lastWatchEndReason(.agentsSettled)` (`AgrypnosCopy.swift` 128, 135–136) | Real `LastWatchEnd` on disengage |

Why reuse is a lie: the idle POST proves **busy was seen this arm, then local heuristics stayed quiet through `agentSettleGrace`**. It does not name a question, an approval, or a pause. A question-paused agent that stops writing session files looks identical to a finished run and to a think-gap. Reusing that body as “stopped because of a question” would claim a reason Agrypnos did not observe.

Tests already lock the idle body away from job-finished language (`NotifCopyTests.testIdleBodyAndHelpAreIdleAfterWaitNotJobFinished`, `Tests/AgrypnosCoreTests/NotifIdlePostTests.swift` 445–500).

`/status` can also say `Waiting after local busy signals stop.` (`TelegramStatus.agentLines`, `Sources/AgrypnosCore/Notif/TelegramStatus.swift` 108–110). That is settle grace, not “waiting on you.” Do not reuse it as a question notice.

---

## Idle-after-wait POST (when it fires)

**Command:** `WatchCommand.postIdleAfterWaitNotif` (`Sources/AgrypnosCore/Session/WatchTypes.swift` 16–17).

**Engine:** `WatchEngine.disengage` (`Sources/AgrypnosCore/Session/WatchEngine.swift` 308–343) appends that command when:

```
!postedThisUserArm && NotifIdlePostPolicy.shouldPost(
    enabled: preferences.notifEnabled,
    reason: reason,
    sawBusy: settle.sawBusy
)
```

**Policy:** `NotifIdlePostPolicy.shouldPost` (`Sources/AgrypnosCore/Notif/NotifIdlePostPolicy.swift` 8–14) is true only when:

- outbound opt-in `notifEnabled` is on (default **false**, `UserPreferences.swift` 64, 85)
- `reason == .agentsSettled`
- `sawBusy == true` (`AgentSettleTracker.sawBusy`, set only when a busy observation was recorded this arm — `AgentSettleTracker.swift` 15, 47–50)

**Settle:** `WatchEngine.tick` in `.untilAgentsSettle` mode calls `settle.observe(...)`; `.settled` means busy was seen, then quiet continuously for `agentSettleGrace` (clamped **120–900 s**, default **120 s**) (`WatchEngine.swift` 216–222; `UserPreferences.swift` 9–10). Missing observations are not idle (`AgentSettleTracker.maximumObservationGap` 15 s, `AgentSettleTracker.swift` 11–12, 52–53).

**Mac POST:** `WatchRuntime` tick sees `.postIdleAfterWaitNotif` and calls `postIdle(enabled)` → `NotifIdlePoster.postIfNeeded` (`WatchRuntime.swift` 98; `WatchRuntime+Poll.swift` 191–197). Destinations from secrets: Discord webhook and/or Telegram token+chat (`NotifIdlePostPolicy.destinations`, `NotifIdlePostPolicy.swift` 16–28). Factory: `NotifOutboundRequestFactory.discord` / `.telegram` (`NotifOutboundRequest.swift` 17–43). Bounded 3 s so lid-closed sleepnow is not blocked (`NotifIdlePoster.waitBound` = 3).

**Does not fire** for timer, battery, thermal, LPM, user-off, or `.questionUnanswered` (`shouldPost` requires `.agentsSettled`; `QuestionWatchTests` asserts no idle POST on unanswered timeout). Never-busy this arm: no POST (`AGENTS.md` 121; `shouldPost` `sawBusy`).

Independent of `forwardAgentQuestions`. Forwarding off does not stop this POST. That is the collision: a Cursor/Codex (or OpenCode/Claude) session that goes quiet because it is waiting on the human still looks like idle-after-wait.

---

## 2. Who has a positive question/approval event in this tree

| Provider | Positive question event today | Approval / other named pause | Answer path |
| --- | --- | --- | --- |
| **OpenCode** | Yes. Plugin `api.event.on("question.asked", …)` (`Apps/Agrypnos/Resources/agrypnos-opencode.js` 163–171) → bridge `asked` (`OpenCodeBridgeMessage.swift` 8) → `QuestionRelayCoordinator.receive`. Also HTTP `OpenCodeQuestionSource` for the manual server fallback. Schema is listed choices, 1–4 questions (`validQuestion` in the plugin, lines 12–17). | **None.** Plugin does not subscribe to permission/plan events. Design: free text and tool/plan permissions stay on Mac (`QuestionSetupChrome.help` line 2; `BotGuideCopy.swift` 57). | Yes, when forwarding is on: `question.reply` |
| **Claude Code** | Yes. `PreToolUse` matcher **`AskUserQuestion` only** (`ClaudeHookSettingsMerge.enable`, `ClaudeHookSettingsMerge.swift` 12–18). Payload requires `tool_name == "AskUserQuestion"` (`ClaudeAskUserQuestionPayload.swift` 63). | **None wired.** `PermissionRequest` is documented as a separate event in research (`docs/reviews/2026-09-29-claude-cursor-question-roundtrip.md` 11) and is not a matcher in this tree. | Yes, when forwarding is on: hook stdout with `updatedInput.answers` |
| **Cursor** | **None.** No `CursorQuestion*` source under `Apps/Agrypnos/Sources/Questions/` or `Sources/AgrypnosCore/Questions/`. Busy only: process + session/transcript mtimes (`AgentKind.cursor`, `AgentKind.swift` 2). | None. | None. Do not invent a desktop AskQuestion contract. Historical docs research: ACP is a *separate* CLI session, not the installed desktop chat (`2026-09-29-claude-cursor-question-roundtrip.md` 35–37). |
| **Codex** | **None.** No `CodexQuestion*` source in this tree. Busy only: process + session/transcript mtimes; may also use CPU (`AGENTS.md` 116). | None. | None. Do not invent an app-server/RPC here. |

`AgentKind` still lists all four for **busy heuristics** (`AgentKind.swift` 1–14). That is not a question event.

Popover copy already says Cursor and Codex are unavailable for forwarding (`QuestionSetupChrome.help`, `QuestionSetupChrome.swift` 2).

---

## 3. Smallest existing pipe a notify-only signal could reuse

Do not design a new bot. Two outbound pipes already exist. Only one works with **forwarding off**.

### Reuse this: idle outbound POST (forwarding-independent)

`NotifIdlePoster.postIfNeeded` + `NotifOutboundRequestFactory` (`NotifIdlePoster.swift` 19–54; `NotifOutboundRequest.swift` 17–43).

- One POST per configured destination.
- Discord: **webhook URL** (outbound-only; never inbound).
- Telegram: **same bot token + chat id** as outbound/inbound (`sendMessage`).
- Does **not** read `forwardAgentQuestions`.
- Does **not** need answering-user IDs or inbound on.
- Does need outbound opt-in `notifEnabled` **as written today** (`postIfNeeded(enabled:)`, `NotifIdlePoster.swift` 19–20). A notify-only signal that reused this factory would still have to decide whether it shares that opt-in; that is a product choice, not a new bot.

**Do not reuse the idle body or `NotifIdlePostPolicy.shouldPost`.** Those are the quiet-after-wait watch-end event. A waiting notice would be a different string on the same HTTP factory.

### Do not reuse this for forwarding-off: `QuestionNoticeSender`

`QuestionNoticeSender.send` (`Apps/Agrypnos/Sources/Questions/QuestionNoticeSender.swift` 9–31) already POSTs a caller-supplied string through the **same user bots**, but:

```
guard preferences.forwardAgentQuestions else { return }
```

and then requires Telegram inbound + answering user ID, or Discord inbound + answering user ID. Discord here is `DiscordQuestionMessage.notice` (bot token + channel), **not** the webhook (`QuestionNoticeSender.swift` 21–25; `DiscordQuestionMessage.swift` 37–40).

That pipe is the unanswered-question watch-end / hold messages (`WatchRuntime+Questions.swift` 101–114; `WatchRuntime+Poll.swift` 237–241). It is answer-path adjacent. With forwarding off it is a no-op.

### Parked: Notification Center as the Notif path

`UserNotify.post` uses `osascript` `display notification` (`GrantAndNotify.swift` 8–15). That is a local Mac banner (used for POST failures, setup, and watch-end except `.user`). **AGENTS.md parks Notification Center as the Notif path** (`AGENTS.md` 185). A new “waiting on you” product notice must use the **already allowed** Telegram/Discord outbound (webhook + Telegram `sendMessage`), not NC as the Notif channel.

---

## Forwarding entry points and what happens when buttons are OFF

Master switch: `forwardAgentQuestions` (default **false**, `UserPreferences.swift` 38, 67). Popover: `QuestionSetupChrome.title` = “Forward agent questions” (`QuestionSetupChrome.swift` 1; `PopoverController+Questions.swift` 43–45, 161–166).

`WatchRuntime.questionRelaySettings()` sets `QuestionRelaySettings(enabled: engine.preferences.forwardAgentQuestions, …)` (`WatchRuntime+Questions.swift` 32–33).

`QuestionRelayCoordinator.receive` returns **false** unless enabled, the provider is in `includedAgentKinds`, and a complete Telegram or Discord destination exists (`QuestionRelayCoordinator.swift` 92–99). False means: no bot panel, no `onChange(.observed)`, no watch hold.

### OpenCode plugin

- Enable: `WatchRuntime.enableOpenCodeForwarding` installs `agrypnos-opencode.js`, sets `openCodePluginEnabled` and `forwardAgentQuestions` true (`WatchRuntime+OpenCodePlugin.swift` 32–55).
- Disable forwarding: `disableOpenCodeForwarding` → `setForwardAgentQuestions(false)` + `stopQuestionSources()` (74–77).
- `syncOpenCodeQuestionSources` **stops** plugin/HTTP sources unless `relay.enabled` (`WatchRuntime+OpenCodeQuestions.swift` 32–38). `stopOpenCodePlugin` writes `{"active":false,...}` (`WatchRuntime+OpenCodePlugin.swift` 128–136).
- Plugin `readManifest`: `if (manifest.active !== true) return null` (`agrypnos-opencode.js` 36). `question.asked` handler then no-ops because `!ready` (163–164). Questions stay in the OpenCode TUI. **Agrypnos does not see them. There is no pending-question notice.**

Caption when the master switch is off: `OpenCode: forwarding off.` (`WatchRuntime+OpenCodeQuestions.swift` 10).

### Claude hook

- Enable: merge `PreToolUse` / `AskUserQuestion` into `~/.claude/settings.json` (`WatchRuntime+ClaudeHook.swift` 54–71).
- `syncClaudeQuestionHook` starts the unix listener only when `relay.enabled` **and** `claudeQuestionHookEnabled` (`WatchRuntime+ClaudeHook.swift` 100–109). Forwarding off → `stopClaudeQuestionHook()`.
- If the hook line remains in settings (Disable Claude was not clicked) but the listener is down: helper `ClaudeQuestionHookProcess` fails connect in **2 s** and writes native fallback `{}` (`ClaudeAskUserQuestionPayload.helperStdout` 96–103; `unavailableFallbackSeconds` = 2). Native AskUserQuestion stays on Mac. **Agrypnos does not receive the batch. There is no pending-question notice.**

Caption when the master switch is off: `Claude Code: forwarding off.` (`WatchRuntime+ClaudeHook.swift` 12).

### Existing “question is pending” notices that do not require the answer path?

**None.** Every bot question notice in this tree goes through forwarding:

- Live question panels (`QuestionRelayCoordinator.receive` → Telegram/Discord question messages) require forwarding + destinations.
- Unanswered-10-minute texts (`WatchRuntime+Questions.swift` 104–109; poll 237) go through `attemptQuestionNotice` → `QuestionNoticeSender`, which **returns immediately if forwarding is off**.

There is no notify-only observer for `question.asked` / `AskUserQuestion` that posts without offering Send answers.

---

## 4. Honest copy vs a lie

### Honest if Agrypnos only knows “a question tool started”

Only OpenCode (`question.asked` with valid listed-choice payload) and Claude (`AskUserQuestion` PreToolUse) can support this, **and only while their sources are actually running**. Honest shape (examples, not shipped copy):

- Name the provider that emitted the event: OpenCode or Claude Code.
- Say a **structured choice** appeared (that is the event).
- Say to answer **in the agent app** if there is no answer-back.
- Do not say the watch ended.
- Do not say the agent stopped, finished, or is still thinking.

OpenCode plugin honesty limit: `validQuestion` rejects empty option lists and >4 questions (`agrypnos-opencode.js` 12–17). A free-text-only or permission dialog is **not** this event. Claiming “OpenCode is waiting on you” for those would be a lie even with the plugin on.

Claude honesty limit: matcher is `AskUserQuestion` only. A `PermissionRequest` / plan approval is **not** observed. Claiming “Claude is waiting for approval” from this hook would be a lie.

### A lie (do not ship)

- Reusing `notifIdleBody` or `agentsEnded` as a question/pause reason.
- “Agent stopped.” / “Job finished.” / “Still thinking.” / “When the job is done.” (`AGENTS.md` 121, 138, 289, 295).
- “Cursor is asking a question” or “Codex is waiting on you” — **no event in this tree**. Quiet busy signals are not a named reason.
- Inferring a question from idle-after-wait: quiet after `agentSettleGrace` is not a question tool.
- “Watch turned off because of a question” for a waiting notice — that is `.questionUnanswered` watch-end copy (`AgrypnosCopy.swift` 114, 129; poll 237), a different event, and it currently requires forwarding to send.
- `/status` “Waiting after local busy signals stop.” as “waiting on a question.”
- Any finish ETA or task text (enriched-status B, scrapped, `AGENTS.md` 189–191).

For Cursor and Codex, Agrypnos can already tell the user only: selected tools, busy-seen-this-arm, settling, last **watch** end. That is `/status` (`TelegramStatus.swift` 93–111) and the Watch last-end caption. It cannot name a pause reason.

---

## 5. A waiting notice is not a watch-end

Do **not** invent a new `DisengageReason` in this note.

Current reasons (`Sources/AgrypnosCore/Power/Safety.swift` 22–31): `user`, `timerExpired`, `batteryFloor`, `thermal`, `agentsSettled`, `questionUnanswered`, `lowPowerMode`, `wakeHoldFailed`.

Last-end honesty is caption-only from a real `LastWatchEnd` (`AgrypnosCopy.lastWatchEndCaption`, 151–156; Watch card `PopoverController.swift` 162–165). `questionUnanswered` **is** a watch-end: “a question went unanswered for 10 minutes” (129) and it **turns the watch off** (`turnsWatchOff`, `Safety.swift` 35–36). It is not a “still waiting” notice.

A “waiting on you” notice, if it existed, would be **while the watch may still be on** (or even off — forwarding already operates with the watch off; design: forwarding never arms). It must not write `preferences.lastWatchEnd`, must not call `disengage`, must not POST `notifIdleBody`, and must not show `Agents idle. Watch turned off.`

Today, if How long is Agents and a question-paused run goes quiet, the watch **does** end with `.agentsSettled`. Last-end then says idle-after-wait. That is the false “stopped work” story for forwarding-off Cursor/Codex (and for OpenCode/Claude when sources are stopped).

---

## File-size files that must not grow

`AGENTS.md` 40: no file over 600 lines; prefer ~250. Split before the wall.

`wc -l` on this tree, 2026-10-06:

| File | Lines |
| --- | ---: |
| `Apps/Agrypnos/Sources/WatchRuntime.swift` | **513** |
| `Apps/Agrypnos/Sources/MenuBar/PopoverController.swift` | **511** |

Question UI already lives in `PopoverController+Questions.swift`. Runtime question work already lives in `WatchRuntime+Questions.swift`, `WatchRuntime+OpenCodePlugin.swift`, `WatchRuntime+ClaudeHook.swift`. A notify-only slice must not add lines to those two 500+ files.

---

## Map: what Agrypnos can already tell the user

| Fact | Source | Channel |
| --- | --- | --- |
| Local busy signals went quiet after the wait (Agents mode, busy seen this arm) | `.agentsSettled` + `notifIdleBody` | Telegram `sendMessage` + Discord webhook; also local `UserNotify` `agentsEnded` |
| Watch ended, named reason | `DisengageReason` / last-end caption | Watch popover; `/status` |
| Structured OpenCode choice pending | `question.asked` while plugin/HTTP source is live | Bot question panel only if forwarding on |
| Claude `AskUserQuestion` pending | PreToolUse hook while listener is live | Bot question panel only if forwarding on |
| Unanswered 10 minutes, watch still on because busy/unknown/another question | `QuestionWaitPolicy` notices | `QuestionNoticeSender` only if forwarding on |
| Unanswered 10 minutes, watch off | `.questionUnanswered` | last-end + `QuestionNoticeSender` if forwarding on |
| Cursor/Codex question or approval | — | **Nothing named** |
| Permission / plan approval (any provider) | — | **Nothing named** |
| “Waiting after local busy signals stop” | settle grace | `/status` only |

Codegraph: used with `projectPath` `/Users/imightbeoufu/Developer/Agrypnos` after a workspace-root miss. Line numbers above are from `Read` / `wc -l`.
