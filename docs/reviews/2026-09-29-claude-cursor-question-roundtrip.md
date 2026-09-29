# Claude Code and Cursor question round trip

Research checked 2026-09-29. Documentation research only; no provider configuration, secrets, runtime code, or remote messages changed. Installed runtimes have not been validated.

## Result

Selecting an answer through a bot is feasible when Agrypnos owns a supported pending-request response path. Observing a question event alone does not establish that path. Transparent attachment to an arbitrary existing desktop chat remains unproven for Cursor. Claude offers a promising hook interception path, with timeout and UI tradeoffs.

## Claude Code: documented APIs

Hooks run in terminal, IDE, Desktop, and cloud sessions. `PreToolUse` can match `AskUserQuestion`; inputs include `session_id`, `tool_use_id`, and `tool_input`. The question payload includes text, header, choices, and multi-select. A hook can return `permissionDecision: "allow"` and `updatedInput` containing the original questions plus an answers map (question text → selected labels). This handles the original tool call rather than submitting a new conversational prompt. `PermissionRequest` is a separate approval event, not a general question notification. [Hooks reference](https://code.claude.com/docs/en/hooks)

A synchronous command hook could send the question to Agrypnos, wait for a bot answer, and return that answer. Default command/HTTP/MCP hook timeout is 600 seconds. Timeout discards output and falls back to ordinary permission flow; it does not block indefinitely. `async: true` cannot supply a synchronous decision. The documented `defer` alternative works only in non-interactive `-p` mode, only for a single tool-call batch, and requires resuming that process/session later. It is not transparent interactive attachment. Matching hooks run in parallel. [Hooks reference](https://code.claude.com/docs/en/hooks)

For a caller-owned Agent SDK session, `canUseTool` is an explicit request/response interface: the callback receives the question input, can remain pending indefinitely, and returns `behavior: "allow"` with `updatedInput`. TypeScript supplies an abort signal. SDK callbacks require starting the session with these options; this is not an attach API for an arbitrary running Desktop chat. Tool approvals and clarifying questions share the callback but must be distinguished by tool name. The documented SDK question shape allows descriptions and free-text answers; each call supports 1–4 questions, 2–4 choices each. [Agent SDK user input](https://code.claude.com/docs/en/agent-sdk/user-input)

Claude's built-in Remote Control already carries an existing local session to Claude web/mobile, including pending permission and `AskUserQuestion` dialogs. Those two dialogs remain pending until answered. Some other dialogs default to five-minute expiry. Local tools remain on the Mac, which must stay running and network-connected. Remote Control activates explicitly or through opt-in auto-connect. This proves provider-supported remote answering exists, but the docs do not expose its service as an Agrypnos bot API. [Remote Control](https://code.claude.com/docs/en/remote-control)

## Claude-owned channels and an Agrypnos-owned MCP question tool

Claude's Channels research preview already includes Telegram/Discord plugins. They inject messages into the running local session, require explicit startup `--channels` opt-in, and use sender pairing/allowlists. Authentication supports claude.ai/Console, with organization policy gates; Bedrock/Google/Microsoft deployments are excluded. CLI setup requires restarting with the flag; these pages do not verify activation for arbitrary existing Desktop/IDE conversations. In channel `-p` mode, multiple-choice questions and plan approval tools are disabled. [Channels guide](https://code.claude.com/docs/en/channels)

Channel permission relay forwards tool approvals with request IDs and accepts allow/deny for that exact open request. Native and remote dialogs remain live; first answer wins. The relay contract describes Bash/Write/Edit approvals, not an `AskUserQuestion` selected-options response. Ordinary inbound chat text is model context, not a structured answer to a native question tool. Sender identity must be checked, including in groups. A custom Agrypnos channel still needs a development flag or organizational approval during preview. [Channels reference](https://code.claude.com/docs/en/channels-reference)

Inference: channels could support a provider-specific remote conversation/approval feature, but do not establish the requested universal native question bridge. Reusing Agrypnos's bot credentials across independent polling clients would also need coordination rather than a second competing consumer.

An Agrypnos-owned MCP `ask_user` tool can receive structured question parameters and return the selected answer to its caller. This avoids attaching to a different native tool's pending dialog. However, Claude automatically backgrounds main-conversation MCP calls after two minutes (v2.1.212+), letting the agent continue before the answer. Open elicitation dialogs are exempt; a plain server-held call is not documented exempt. Per-server `timeout` in milliseconds is a hard wall-clock limit, and progress does not extend it. [Claude MCP](https://code.claude.com/docs/en/mcp)

The process setting `CLAUDE_CODE_MCP_AUTO_BACKGROUND_MS=0` disables automatic backgrounding. Idle limits default to five minutes for network transports and 30 minutes for stdio. A per-server timeout of at least 1000ms floors that server's idle window on v2.1.203+. `MCP_TOOL_TIMEOUT` defaults to about 28 hours, but that does not prevent backgrounding/idle expiry. [Claude environment reference](https://code.claude.com/docs/en/env-vars)

Inference: a skill can request use of `ask_user`; model compliance is best effort. An actual successful tool invocation creates an explicit Agrypnos-owned request and response contract. It still cannot prove every native/plain-text question was routed through it. Provider timeouts, backgrounding, approval-to-call behavior, cancellation, and session binding need live validation. Do not call a custom tool a guaranteed whole-agent pause.

## Cursor: documented APIs

Cursor CLI ACP is a complete question/answer interface over JSON-RPC stdio through `agent acp`. `cursor/ask_question` blocks until a client responds. Requests contain `toolCallId`, question IDs, prompts, option IDs/labels, and multi-select flags. The JSON-RPC response returns an answered outcome with selected option IDs, or skipped/cancelled. `cursor/create_plan` and `session/request_permission` are distinct approval requests. ACP documents creating/loading conversations; it does not document attaching to the pending RPC of an independently running Cursor desktop chat. No explicit question deadline is specified on this page. [Cursor ACP](https://cursor.com/docs/cli/acp)

Desktop Agent Chat hooks document generic `preToolUse`/`postToolUse`, conversation/generation/tool IDs, and an `updated_input` modification. They do not document a dedicated AskQuestion payload or a supported answer injection schema for its native question UI. Generic “all tools” wording is insufficient to promise this round trip. [Cursor hooks](https://cursor.com/docs/hooks)

The Python SDK exposes runs, custom tools, and file-based hooks. No built-in AskQuestion answer API is documented on its reference page. Using it as a replacement launcher would expand Agrypnos from watching existing agents into hosting them. [Cursor Python SDK](https://cursor.com/docs/sdk/python)

## Primary issue reports, not current-runtime proof

- A February 2026 Cursor IDE report says AskQuestion skipped generic hooks; Cursor support acknowledged the bug. The visible thread contains no confirmed fix. [Cursor support thread](https://forum.cursor.com/t/askquestion-tool-does-not-trigger-cursor-hooks/152230)
- A June 2026 Cursor support response says local SDK AskQuestion events were filtered and automatically declined. It is a dated provider statement, not proof of September behavior. [Cursor SDK support thread](https://forum.cursor.com/t/cursor-python-sdk-use/163238)

No internal developer source was used as a stable contract for these closed-source runtimes.

## Minimal recommendation and validation gates

Recommendation (inference): first validate Claude's synchronous AskUserQuestion hook against an ordinary existing local conversation. It preserves the original pending tool call and avoids a replacement agent launcher. Put a finite deadline on remote ownership; when timeout/native fallback happens, expire the bot controls. Do not offer both a live local dialog and a bot response path without a reliable first-answer-wins mechanism. Hooks may temporarily delay display of the native dialog while awaiting a reply.

For Cursor, distinguish CLI ACP support from native desktop support in the product. Use ACP only if a caller-owned CLI workflow is deliberately in scope. Do not promise native desktop answering or invent a transcript-write/UI-click workaround. A separate Agrypnos MCP question tool could be an opt-in alternative, but it would cover only questions explicitly routed through that tool, not all native questions.

Cursor documents MCP tools in existing editor/CLI conversations with configurable opt-in permissions. A provider support report from December 2025 describes a non-configurable elicitation timeout and a separate long-tool/progress timeout report. That is historical evidence to investigate, not a claim of today's limit. Do not assume periodic progress extends the installed Cursor client's tool deadline. [Cursor MCP](https://cursor.com/docs/mcp), [Cursor timeout report](https://forum.cursor.com/t/custom-mcp-server-timed-out-time-is-extremely-short/145618)

Before writing the implementation plan, a live disposable-session check must establish:

1. Installed versions fire the hook/ACP request with exact question, choices, and stable session/request IDs.
2. Returning a selected answer resolves that exact request and the same run continues once; no replacement run is launched.
3. Multi-question, multi-select, free-text, and cancellation behave correctly.
4. Hook timeout, app exit, provider interruption, and late/duplicate bot answers cannot resolve a stale request.
5. Existing hooks/policy decisions and Claude Remote Control do not compete or produce duplicate questions.
6. Questions and tool/plan approvals remain separate types; answering a preference question never creates general permission rules.

These checks need user-authorized disposable provider conversations/configuration later. No live validation was performed in this research pass.
