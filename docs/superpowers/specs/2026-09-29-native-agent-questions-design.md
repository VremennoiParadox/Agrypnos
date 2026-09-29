# Automatic agent questions through Agrypnos

Status: execution authorized by the user on 2026-09-29, local commits only; no push. The user will perform live Cursor checks after coding; shared implementation is underway while native compatibility evidence stays outstanding. See [compatibility evidence](../../reviews/2026-09-29-native-question-compatibility.md). Branch: `codex/agent-question-relay`.

## Intent and decisions

The user wants a question from an existing agent conversation to appear automatically on their own Telegram/Discord bot, with selectable answers returned to that same request. Setup happens once. No skill, per-prompt command, injected model instruction, or replacement conversation is required.

The user has requested an implementation plan. This design records the decisions that plan needs; it is not a claim that native support already works. The earlier research's skill/MCP-first recommendation is superseded by the user's native-monitoring preference.

The user requires **all four providers before release** and **ten minutes awake after a question is detected, then watch off with a specific bot notification if unanswered**. All four native capability gates precede release. The user subsequently deferred live Cursor checks until after coding, so shared implementation may proceed while native API contracts remain required for each adapter. Claude Code/OpenCode are useful first experiments, not an acceptable reduced release. Cursor means the existing desktop conversation; starting an ACP conversation elsewhere does not meet the requirement.

The ten-minute hold applies only to an already armed watch; forwarding never silently arms the Mac. The user clarified: **keep watching while other agents are busy; report the unanswered question**. Current local busy evidence is not reliably conversation-specific, so any fresh positive signal from selected providers conservatively protects the watch; unknown observations do too. Do not claim exact per-conversation busy detection.

## Success and scope

- With forwarding enabled, a supported provider's structured choice question arrives automatically. The bot shows provider, session identifier, full question and all option labels/descriptions. A project label is shown only if supplied by the source.
- The authorized person selects options, reviews the complete selection and presses **Send answers**. Only the original live request can receive them. Two concurrent conversations remain separate.
- Support single selection, multiple selection and batches of up to four questions. This first slice supports listed choices. **Answer on Mac** leaves/relinquishes remote handling without selecting a default; free-text-only questions and tool/plan permissions stay local. An optional free-text alternative is represented by **Answer on Mac**, not silently omitted.
- Question detection is evidence of a pending question only. It does not replace existing busy heuristics, prove task completion, or identify ordinary questions in prose.
- Reuse the existing Telegram long poll and Discord Gateway. No second consumer for the same bot, extra AI calls, transcript scans, periodic fake activity or UI automation.
- A confirmed pending question suppresses Agents idle disengagement for **600 seconds** while the watch is armed. It does not change the idle-grace preference, automatically arm, or override manual off/battery/thermal/LPM safety. At an unanswered deadline with fresh observed idle and no other unexpired question, end the watch with the new reason `questionUnanswered`; the original How long selection stays unchanged. Busy or unknown observations defer that end as described below.

## Provider gates

Installed versions must pass a same-conversation experiment before an adapter is enabled. Capture sanitized payloads and exact version numbers. Merely seeing an event is insufficient.

| Provider | Candidate native path | Required proof |
| --- | --- | --- |
| Claude Code | Synchronous `PreToolUse` hook matching `AskUserQuestion`; preserve original input and return selected answers. | The installed desktop/terminal surface actually fires it, the same call consumes its result once, timeout restores native handling, and existing hook decisions are not bypassed. |
| OpenCode | Active local instance's question listing, event stream and reply API. | Endpoint is the instance hosting the user's session; pin its API variant; cancel/local-answer races and reply acceptance are understood. |
| Codex desktop | Documented connection to the desktop's actual app-server and original user-input RPC. | A supported attachment mechanism, correct response ownership, local/remote race behavior and disconnect handling. A newly launched app-server does not pass. |
| Cursor desktop | Documented native question event plus answer path, if present in the installed version. | Existing IDE conversation receives the response. A separately launched ACP/SDK session does not pass. |

First test a harmless question with a deterministic continuation: ask for A/B, choose B through the integration, and have the original session write/print a unique B marker once. Also cancel the native question before submitting its remote answer, and disconnect/reconnect. A failed gate leaves that provider unavailable with a precise reason. Do not invent a Cursor/Codex implementation around private databases, undocumented sockets, transcript edits or Accessibility clicks. If a new supported contract is discovered, add a concrete adapter task to the plan before implementing it.

For Claude, returning hook output proves delivery to the hook, not provider acceptance. If no reliable consumption acknowledgment exists, use the exact status **Answer returned to Claude's question hook**; never show **Answer accepted** merely because stdout was written. Existing explicit denials must still win; if safe coexistence with other hooks cannot be demonstrated, disable this integration for that configuration rather than granting permission broadly.

## Minimal architecture

1. Provider adapter retains the original response path and emits a normalized question. Core holds an in-memory registry keyed by provider instance, native session and native request; opaque random bot handles avoid exposing these identifiers in callbacks.
2. A small main-actor coordinator owns the registry, provider response closures and bot message IDs. Telegram/Discord format the same question and feed authenticated selections to it. No plugin framework, database, hosted relay or new dependency.
3. Each destination keeps its own draft choices. The first complete **Send answers** reserves the request before any async work. Other destinations cannot combine partial selections or submit concurrently.
4. A definitive source acceptance shows **Answer accepted**. Successful Claude hook return uses the narrower wording above. A lost response shows **Delivery unconfirmed — check the agent app** and disables controls; it never retries an answer blindly.
5. Source cancellation, local completion, expiry, disconnection, forwarding disable, credential/destination changes, clear-secrets, app shutdown and system sleep invalidate handles before awaiting any network cleanup. Stale controls remain harmless even if the bot message cannot be edited. Expiry is passed to watch policy before removing the expired record, so removing it cannot lose the required timeout disengagement.

A complete, authenticated **Send answers** received before the deadline counts as a human answer immediately and clears its unanswered-timeout decision. Provider delivery remains a separate state: if acknowledgment is slow/lost at 600 seconds, report unconfirmed delivery, never **unanswered** or **accepted**. An incomplete draft, unauthorized click or malformed selection does not clear the timeout. **Answer on Mac** relinquishes forwarding and its allowance without selecting anything.

Use injected closures for the two provider implementations and test doubles. Keep native schema parsing in provider-specific files; no generic provider/plugin protocol is needed.

### Limits and deadlines

- Remote window and question wake allowance: **600 seconds** from first observation, shortened by any source deadline. Replayed events, button taps, newer questions and reconnects cannot extend an existing request's deadline. Use a monotonic clock for elapsed time; wall-clock time is only for display and LastWatchEnd. The oldest still-unanswered request reaches its deadline first.
- Claude hook command timeout: **630 seconds**, leaving time for a **600-second** helper deadline. If Agrypnos is unavailable, the helper returns native fallback within **2 seconds**. No output that selects an answer on failure.
- Maximum **4 questions**, **20 options per question**, **32 pending batches**, **256 KiB** provider/hook frame. Reject duplicate identities and ambiguous label-based mappings.
- Each question panel, including full choices/descriptions and context, must fit **1,800 UTF-16 code units** before the fixed footer/controls. If any panel exceeds the limit, leave the whole batch local and state that limitation. Never truncate question meaning or silently drop choices.
- Bot buttons use short numbered labels; the body contains the full numbered choices. For each question: toggle selections, then **Next**; the final review has **Send answers** and **Answer on Mac**. Single-select permits exactly one choice; multi-select requires at least one unless the native schema explicitly permits zero.
- Opaque callback/action strings must fit Telegram's **64-byte** limit and Discord's **100-character** limit. Verify bot, destination, message ID, sender ID, current lifecycle generation and live handle on every action.
- One nearest-deadline timer; no question polling timer. Retry event connections with bounded backoff (**1, 2, 4, 8, 16, 30 seconds**, then 30), resetting after a healthy connection. Respect API rate-limit retry information. Never retry a possibly submitted answer automatically.

### Setup, privacy and wake behavior

**Notif** gains one **Forward agent questions** toggle, default **OFF**, and an answering-user ID for each bot. Existing inbound toggles and credentials must also be enabled/configured for the relevant destination. Outbound idle notifications remain independent. One-time provider setup instructions live in the existing read-only Bot setup guide; connection fields, if needed for OpenCode, stay in the popover. The existing Agents selection limits which providers may forward questions.

Forwarding operates while enabled and the Mac is awake, independently of whether Keep the watch is armed. It never arms the watch. A question detected with the watch off has no wake allowance and no false watch-ended notification. Sleep invalidates all drafts and handles; after wake, queued clicks are drained without applying. Only a source that can reconcile a still-pending request may issue fresh controls, with the original deadline. If its original timing cannot be established after an app restart, leave that request local. A new app instance starts with no recovered actionable bot handles.

While holding for a question, preserve the existing saw-busy fact but interrupt the quiet observation baseline. Once all pending questions are answered/cancelled, normal fresh idle observations resume with the unchanged user grace. A provider closing its request early ends that request's allowance and says **Question no longer available**; it is not a ten-minute unanswered timeout. A valid native local answer counts as answered and releases that allowance.

At each 600-second deadline, invalidate that question's remote controls and report its timeout once. Do not restart the window. If another unexpired question is pending, preserve its existing deadline. Otherwise inspect the selected agents using the existing probe pipeline: timely positive evidence keeps the watch on; only a complete, timely negative proves observed idle. This check is needed even in the remembered ∞/1h/3h/custom modes, which normally skip agent probes. Reuse the existing **5-second** tick while a timeout decision is deferred; stop the extra demand when it is cleared. No new permanently running scan.

If the first usable observation at the deadline is idle, end immediately. If busy or unknown delayed the decision, require a continuous quiet wait of the existing `agentSettleGrace` before ending with `questionUnanswered`; missing observations reset that quiet baseline and never count as idle. Use wording **Question unanswered for 10 minutes; watch remains on because local busy signals are present.** or **Question unanswered for 10 minutes; watch remains on because agent activity could not be checked.** as applicable. With another live question use **Question unanswered for 10 minutes; watch remains on while another question awaits an answer.** A fresh native answer to an expired request clears that request's deferred end; forwarding disable/manual off/re-arm also clears old pending end decisions. No fake busy observations are inserted to implement this.

On a ten-minute timeout, first invalidate answers and verify the existing kernel release path. Persist `LastWatchEnd(reason: .questionUnanswered)` only as a real successful end, with the existing rollback behavior if release fails. Send **Agrypnos: watch turned off because an agent question went unanswered for 10 minutes.** to configured question destinations (including Telegram), independently of the idle-notification toggle. Include provider/session context but no claim that the agent finished. Attempt delivery for at most **3 seconds**, then use the existing confirmed-lid sleep path; a failed network request must not keep the Mac awake indefinitely. If kernel release fails, report **Agrypnos couldn't turn the watch off after an unanswered question.** instead. Record last-end reason for `/status` and the Watch caption. Delivery before sleep is best effort; an offline bot cannot be guaranteed a message.

Manual off or safety ending the watch first retains that actual reason. Re-arming while a timeout message is in flight cancels the old deferred sleep; it cannot sleep the newly armed Mac. Timeout in an open-lid or unconfirmed-lid state clears the hold without forcing system sleep. Screen lock does not cancel the question timer.

Sender IDs are explicitly configured; a shared chat/channel is not sufficient authorization. Store IDs and any local-provider credentials alongside existing secrets in the mode-0600 Application Support file, keeping old-file decoding compatible. Question content stays in memory and on the opted-in messaging service; no question history or content logs. Disable Discord mentions and bot text markup. Agents never receive bot tokens.

Claude uses a private local Unix socket for the hook helper, not a public TCP endpoint. Parent directory mode **0700**, socket **0600**, same-UID peer check, no replacement of foreign/symlink paths. The existing app executable gets a headless `--claude-question-hook` entry point, avoiding an additional installed runtime/daemon. OpenCode connects only to an explicitly configured loopback endpoint with the selected directory/workspace and credentials; reject redirects to a different origin and do not scan ports or start a replacement server.

## Project constraints

- macOS **14+**; Swift tools **5.9**; Linux-testable Core and existing macOS test target; no third-party dependencies.
- No file over **600 lines**; prefer focused files around **250 lines**. Keep WatchRuntime as lifecycle wiring.
- Menu-bar only; **Watch · Power · Agents · Notif · General**; no separate settings window. Preserve **0.25s ease-in-out** section resizing and Reduce Motion behavior.
- Existing **45s** default session freshness and **2m–15m**, default **2m**, idle wait preferences are unchanged. Question waiting is an explicit **600-second** state, not a fake busy signal.
- Existing manual-off, battery, thermal, LPM and confirmed-lid gates remain authoritative. Screen lock alone must not be treated as system sleep or provider completion.
- User-owned bots only; opt-in network; no telemetry, shared service, Discord Interactions Endpoint URL, or new sudoers grant.
- No measured wattage claims. Compare the same awake workload with forwarding off/on before claiming energy impact.

## Acceptance evidence

Each advertised provider must complete both a Telegram and Discord round trip in the same ordinary local conversation. Cover single/multiple selection, batches, two simultaneous conversations, duplicate and unauthorized clicks, local-vs-remote answers, both bots, cancellation, source deadline, provider/app restart, a dropped answer response, offline/429 behavior, sleep/wake and screen lock. Record versions and what was actually observed.

Run the existing Core/macOS suite and app Debug/Release builds. Optical checks cover setup, message readability and section sizing. A controlled energy check uses the same awake state, workload, display mode and bot configuration for off/on samples; CPU time is reported separately from energy and cannot be converted into watts.

## Evidence

The [research note](../../reviews/2026-09-29-agent-question-relay-research.md) and [Claude/Cursor companion](../../reviews/2026-09-29-claude-cursor-question-roundtrip.md) record the inspected interfaces and limitations. Primary references: [Claude hooks](https://code.claude.com/docs/en/hooks), [OpenCode server](https://opencode.ai/docs/server/), [Codex app-server](https://learn.chatgpt.com/docs/app-server), [Cursor ACP](https://cursor.com/docs/cli/acp), [Telegram API](https://core.telegram.org/bots/api), [Discord components](https://docs.discord.com/developers/components/reference).
