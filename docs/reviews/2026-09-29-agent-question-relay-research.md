# Agent questions through Telegram and Discord

Research checked 2026-09-29 on `codex/agent-question-relay`, branched from main at `e615e007`. This is a feasibility assessment, not an approved design or implementation plan. No application code, provider configuration, secrets, or remote messages changed. No live provider round trip was exercised.

Planning update, 2026-09-29: the user subsequently chose automatic native integrations without a skill, required all four providers before release, and requested a ten-minute unanswered-question wake allowance with busy-agent protection and a specific bot reason. The skill-first recommendation below is historical and superseded. See the proposed [design](../superpowers/specs/2026-09-29-native-agent-questions-design.md) and [implementation plan](../superpowers/plans/2026-09-29-native-agent-questions.md); native desktop capability checks remain outstanding.

## Intended outcome

The user has agreed on forwarding a watched agent's structured question and selecting its options through their own Telegram or Discord bot. The selected answer must reach the original request in the original conversation. Existing local desktop conversations matter; starting a replacement agent is a different workflow. A bundled `/agrypnos` skill was discussed earlier, but the integration approach remains to be chosen.

## Finding

Remote option selection is feasible. There is no verified universal interface for capturing and answering every existing native question across Cursor, Claude Code, Codex, and OpenCode. Receiving a question event, having authority to answer it, and recovering the pending request after a disconnect are three separate requirements.

Two approaches deserve validation: native provider request/response adapters, and an explicit Agrypnos question tool invoked from an opted-in conversation. The second fits the earlier skill idea, but covers only questions actually sent through that tool. Neither implies detection of ordinary prose questions or proof that a task finished.

## Native provider interfaces

| Provider | Evidence | Limitation for the user's desktop workflow |
| --- | --- | --- |
| Cursor | ACP exposes blocking `cursor/ask_question` and selected-option responses. | The documented interface belongs to a CLI ACP connection. Attachment to another running IDE conversation's pending question is unproven. Generic desktop hooks do not establish an answer API. |
| Claude Code | A synchronous `AskUserQuestion` pre-tool hook can return answers in the original tool input. | Timeout/fallback, local dialog behavior, other hooks, and same-run continuation require installed-version validation. |
| Codex | App-server exposes structured user-input requests and matching JSON-RPC responses. | Access to the actual running desktop server and its pending requests must be verified. Launching another server does not answer the existing conversation. |
| OpenCode | Primary generated API schema exposes pending-question listing and reply/reject endpoints. | Requires the active instance, correct project/session routing, and the installed API version. Dev source is not a release compatibility guarantee. |

Cursor and Claude details, including primary support reports and alternative interfaces, are in the [companion research note](2026-09-29-claude-cursor-question-roundtrip.md). [Cursor ACP](https://cursor.com/docs/cli/acp), [Claude hooks](https://code.claude.com/docs/en/hooks)

### Codex

App-server uses bidirectional JSON-RPC. `item/tool/requestUserInput` is answered by responding to the original request ID; `serverRequest/resolved` also fires when a request is cleared by interruption or turn changes. A resolved event alone does not prove an answer was applied. Requests may include an automatic-resolution timeout. Command/file/permission approvals have different response schemas. Unix-socket transport is documented, while the app-server command and TCP WebSocket transport carry experimental limitations. An installed desktop attachment path, pending-request recovery, and behavior when two clients answer were not established by the inspected documentation. [Official app-server documentation](https://learn.chatgpt.com/docs/app-server)

The hook reference documents permission interception and generic tool paths, with exceptions for specialized tools. It does not establish a dedicated native user-question answer contract. Hook presence alone is therefore insufficient evidence for this feature. [Official hook documentation](https://learn.chatgpt.com/docs/hooks)

### OpenCode

The primary dev OpenAPI schema includes `GET /question`, `POST /question/{requestID}/reply`, and rejection, with optional directory/workspace routing. Reply bodies contain ordered arrays of selected labels. It also includes newer session-scoped `/api/session/{sessionID}/question` routes and `question.v2.*` events. Version selection must be explicit rather than mixing schemas. [Generated API schema](https://github.com/anomalyco/opencode/blob/dev/packages/sdk/openapi.json)

The inspected question runtime publishes asked/replied/rejected events and holds pending requests while awaiting answers. [Question runtime](https://github.com/anomalyco/opencode/blob/dev/packages/opencode/src/question/index.ts)

The server documentation describes event streams, authentication, and the TUI's random server port unless configured. Reaching the active instance is essential. A new `serve` process is not evidence of access to an existing instance. Reconnect should reconcile pending requests, not infer replay or idle from a missing stream event. [Server documentation](https://opencode.ai/docs/server/)

## Explicit Agrypnos question tool

An opt-in skill could tell the agent to call an Agrypnos MCP tool with the question and choices. The local bridge sends bot controls and returns the human's answer as the result of that same call. This avoids needing an undocumented native-question interception API. It also makes Agrypnos the owner of the pending question's lifecycle.

Local MCP tools are documented for [Cursor](https://cursor.com/docs/mcp), [Codex desktop/CLI/IDE](https://learn.chatgpt.com/docs/extend/mcp), [Claude Code](https://code.claude.com/docs/en/mcp), and [OpenCode](https://opencode.ai/docs/mcp-servers/). This establishes an integration mechanism, not tested compatibility with the proposed tool.

Important boundaries:

- A skill is model guidance. It cannot guarantee that every native or prose question is routed through Agrypnos. Once an actual tool call arrives, that particular request is explicit.
- MCP request IDs belong to their transport connection, not globally to a conversation. Standard tool calls do not guarantee a native conversation ID. Preserve connection identity plus the original call ID for answers; do not present an agent-supplied task label as a verified provider conversation ID.
- A broker-generated binding handle can group questions from an opted-in task. The provider still correlates each tool response to its original caller. Binding does not establish lifecycle truth for questions or work the bridge never receives.
- The provider may ask for tool consent before the bridge runs. Setup must authorize the narrowly scoped question tool; changing all tool permissions is unnecessary.
- A hanging tool is not automatically a paused conversation. Provider timeouts, cancellation, and backgrounding determine behavior. A response cannot be delivered into a call that has already expired.

Codex documents a configurable per-server tool timeout, default 60 seconds. [MCP configuration](https://learn.chatgpt.com/docs/extend/mcp)

Claude's documented MCP behavior can background a main-conversation call after two minutes, letting the agent continue; per-server hard deadlines and idle limits also apply. This requires a provider-specific decision before claiming the agent waits for a remote answer. See the companion note. [Claude MCP behavior](https://code.claude.com/docs/en/mcp)

MCP defines cancellation and recommends finite request deadlines; progress notifications do not guarantee that a client extends them. Do not manufacture progress or file writes to keep an unanswered request alive. [Lifecycle/timeouts](https://modelcontextprotocol.io/specification/2025-11-25/basic/lifecycle), [cancellation](https://modelcontextprotocol.io/specification/2025-11-25/basic/utilities/cancellation)

## Bot transport

Telegram supports inline keyboard callbacks. `callback_data` is limited to 64 bytes; use an opaque short handle, with the full question mapping kept locally. Callback events include sender/message identity, and `answerCallbackQuery` acknowledges the tap. This acknowledgment does not mean the provider accepted the answer. Extend the existing `getUpdates` consumer to receive callbacks rather than introducing another poller for the same bot. [Telegram Bot API](https://core.telegram.org/bots/api)

Discord buttons/selects return a `custom_id` through message-component interactions. Receive them through the existing Gateway path; send interactive questions with the configured bot, keeping the incoming webhook's current outbound role. Components have label/count limits, so the adapter must preserve full question text separately from button labels. [Component reference](https://docs.discord.com/developers/components/reference)

Discord interactions need an initial response within three seconds; defer promptly while validating/submitting the answer. Interaction tokens have a 15-minute follow-up lifetime, which is not a deadline for a question posted as an ordinary bot message. Gateway and HTTP interaction delivery are alternatives; no public endpoint is needed for the existing Gateway approach. [Interaction delivery](https://docs.discord.com/developers/interactions/receiving-and-responding)

## Existing code that can be reused

CodeGraph tools are not callable in this session. A focused native read established these implementation boundaries:

- `Apps/Agrypnos/Sources/Notif/TelegramInboundPoller.swift`: one long-poll consumer, generations, cancellation, wake-miss restart. Reuse the consumer and request machinery.
- `Sources/AgrypnosCore/Notif/TelegramInbound.swift`: update model/parser currently carries message text and chat ID, not callback payload/sender identity.
- `Apps/Agrypnos/Sources/Notif/DiscordInboundGatewayClient.swift`: existing authenticated Gateway connection and runtime dispatch.
- `Sources/AgrypnosCore/Notif/DiscordInboundGateway.swift`: current interaction parser accepts slash-command type 2; component type 3 needs its own path. Current model does not preserve the answering user.
- `Sources/AgrypnosCore/Notif/TelegramInboundPolish.swift` and existing Discord cursor/epoch logic: retain stale-generation and missed-while-asleep protection for answers.

Question requests need separate state from watch commands and the existing one-shot idle notification. An answer must never accidentally become `/arm`, `/disarm`, or a generic permission grant.

## Proposed correctness requirements

These are deductions from the requested behavior, not implemented guarantees:

1. Each request retains provider/connection, task or native session identity where available, question batch, original option identities, cancellation/deadline, and bot-message identities. One task cannot answer another task's question.
2. Verify the answering person's configured user ID as well as destination and message identity. A shared channel/chat allowlist alone does not identify the intended person. Keep bot credentials inside Agrypnos; the agent should not receive them.
3. Preserve question meaning, all choices, descriptions, and single/multiple selection. Collect the complete answer batch before submitting. Unsupported shapes fall back visibly rather than dropping choices or silently choosing a default.
4. Serialize competing answers. A choice in one channel invalidates the other channel's controls. Native local answers, provider cancellation, expiry, and interruption also expire the remote controls.
5. Only report applied/accepted after provider confirmation. If submission succeeded but its reply was lost, reconcile before retrying; do not blindly replay the answer into another request.
6. App/provider restart loses an in-flight MCP return path. Recovered records must stay unusable until the source confirms a live matching request. Native pending-list APIs may permit reconciliation; that capability cannot be assumed for every adapter.
7. Question selection, plan approval, and tool permissions remain distinct. Answering a preference question never installs broad permission rules. Initially unsupported approval types should remain in their provider UI.
8. Forward only explicitly opted-in question content. Keep question text out of routine logs; treat labels/text as untrusted display content and suppress unintended Discord mentions.

## Sleep and battery need an explicit decision

The current Agents mode can disengage after its existing idle wait. A pending remote question may have no local busy writes, so the Mac could sleep while the person is choosing an answer. Neither bots nor a local bridge can receive/apply answers while the Mac is asleep.

Before a design is approved, decide whether a confirmed pending question gets a finite wake allowance or whether the current sleep policy remains and the message warns that answers require an awake Mac. This research does not change the idle wait or introduce an infinite hold. Manual off, battery, thermal, and existing safety behavior must remain effective. Preserve the current wake-miss rule: answers arriving during sleep are not automatically applied on wake; revalidate and ask for a fresh action if needed.

Reuse existing long-poll/Gateway connections and block on local IPC/events; avoid extra transcript scans or repeated model prompts. No power measurements were made, so no wattage claim follows from this proposal.

## Recommendation before planning

For the existing desktop workflow, validate the explicit `/agrypnos` plus MCP question route first, beginning with Cursor. It has a clear answer-return path for calls it owns, subject to actual client timeout/cancellation behavior. Use native adapters where the running provider demonstrably exposes the pending request and accepts its response. Claude's hook and OpenCode's server are promising native candidates. Cursor ACP is a separate caller-owned CLI workflow; Codex desktop server attachment is still a verification gate.

A native-only four-provider implementation is not justified by the evidence yet. The explicit tool route trades universal automatic capture for a clearly opted-in flow; the user must understand that tradeoff before choosing it. Do not fall back to transcript mutation, simulated UI clicks, question-mark parsing, or spawning a replacement conversation.

The next feasibility check must demonstrate an actual question, bot selection, and acceptance by the same running conversation, including an answer delayed beyond normal timeout/background thresholds. Also exercise local-vs-remote races, two simultaneous tasks, both bots, cancellation, app/provider restart, and sleep/wake. Select the integration approach and waiting policy before writing the implementation plan. No such probe was run during this documentation-only research.
