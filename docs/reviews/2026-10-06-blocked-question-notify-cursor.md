# Cursor blocked-state notify — official docs (2026-10-06)

**Not feasible.** Agrypnos cannot reliably notice that the user’s already-open Cursor desktop Agent Chat has paused because it is waiting on a question, a tool approval, a plan approval, or another named blocked state, and tell that apart from “the agent went quiet / the turn ended / work finished.” There is no official hook or event that fires for that wait. The events that do exist mean tool-about-to-run, assistant-message-done, or agent-loop-ended.

ACP `cursor/ask_question` does not help observe the IDE chat. It is a JSON-RPC method on a CLI process Agrypnos would spawn (`agent acp` over stdio). That is a different session. Cursor staff have separately flagged that ACP sessions may not even offer the AskQuestion tool, so the documented method may never arrive even for a client Agrypnos owns.

This is a **notify** question, not an answer path. Quiet file mtimes are already Agrypnos idle. They must not be labeled “stopped because of a question.”

## Finding

The hooks page lists Agent Chat events including `preToolUse` (“fires for all tools”), `beforeShellExecution` / `beforeMCPExecution` (permission allow/deny/ask), `afterAgentResponse`, `stop` (“called when the agent loop ends”), and `sessionEnd`. None of those names is “waiting on the user.” Matcher values named on the page are `Shell`, `Read`, `Write`, `Grep`, `Delete`, `Task`, `MCP:<tool_name>`, plus fixed strings like `Stop` and `AgentResponse`. **AskQuestion is not in that list.**

The Agent overview’s **Ask questions** tool is explicit that a clarifying question is **not** a pause: “While waiting for your response, the agent continues reading files, making edits, or running commands.” So even a future AskQuestion hook would not, by itself, mean the session is blocked.

Cursor staff have confirmed the hook gap as a product bug, not a docs typo. deanrie (19 Feb 2026): `preToolUse` / `postToolUse` “run for all tools, so AskQuestion should be included too.” mohitjain (29 May 2026): “This is a confirmed bug. The AskQuestion tool is not wired to fire `preToolUse`/`postToolUse` hooks in either the IDE or the CLI. No workaround exists for this specific tool at the moment.” Agrypnos’s own 2026-09-30 desktop probe on this Mac’s **Cursor 3.22.12** saw the same: a native A/B questionnaire appeared and a local B click continued the same chat; project `preToolUse` / `postToolUse` observers wrote nothing until a later `Shell` call.

`stop` is the opposite of waiting: status `completed` | `aborted` | `error`, matcher `Stop`. `sessionEnd` is conversation close (`completed` | `aborted` | `error` | `window_close` | `user_close`). Using either as “needs the user” would fire when the turn is over.

A command hook can return immediately (empty stdout, exit 0, fail-open). That only helps if the event fires. For AskQuestion it does not.

## Sources actually opened

Browser, following redirects. Final URL recorded.

| Requested | Final URL |
| --- | --- |
| https://cursor.com/docs/hooks | https://cursor.com/docs/hooks (canonical; markdown twin https://cursor.com/docs/hooks.md) |
| https://cursor.com/docs/agent/chat/commands | **Redirected** to https://cursor.com/help/customization/skills#how-do-i-migrate-commands-to-skills — Skills FAQ, not a hooks/ask-question contract |
| https://cursor.com/docs/cli/acp | https://cursor.com/docs/cli/acp |
| https://cursor.com/docs/llms.txt | https://cursor.com/docs/llms.txt (index; lists `/docs/hooks.md`, `/docs/cli/acp`, `/docs/agent/overview`, `/docs/plugins`, `/docs/sdk/python`, `/docs/sdk/bridge`) |
| https://cursor.com/docs/plugins | https://cursor.com/docs/plugins |
| https://cursor.com/docs/reference/plugins | https://cursor.com/docs/reference/plugins |
| https://cursor.com/docs/reference/third-party-hooks | https://cursor.com/docs/reference/third-party-hooks |
| https://cursor.com/docs/agent/plan-mode | https://cursor.com/docs/agent/plan-mode |
| https://cursor.com/docs/agent/overview | https://cursor.com/docs/agent/overview |
| https://cursor.com/docs/agent/security/run-modes | https://cursor.com/docs/agent/security/run-modes |
| https://cursor.com/docs/sdk/python | https://cursor.com/docs/sdk/python |
| https://cursor.com/docs/sdk/bridge | https://cursor.com/docs/sdk/bridge |
| https://cursor.com/docs/cli/headless | https://cursor.com/docs/cli/headless |
| https://forum.cursor.com/t/askquestion-tool-does-not-trigger-cursor-hooks/152230 | same (staff: deanrie) |
| https://forum.cursor.com/t/cursor-cli-askquestion-tool-skips-pretooluse-and-posttooluse-hooks/161836 | same (staff: mohitjain) |
| https://forum.cursor.com/t/agent-acp-never-offers-the-askquestion-tool-so-cursor-ask-question-is-never-sent/172976 | same (staff: Colin) |
| https://forum.cursor.com/t/cursor-agent-p-askquestion-is-auto-skipped-in-headless-mode-and-only-some-models-get-the-tool/173657 | same URL opened; accessibility snapshot was empty. Treat as first-party URL, not a fully read page. |

Local, read-only, no edits:

| Path / command | What was inspected |
| --- | --- |
| `/Applications/Cursor.app/Contents/Info.plist` | `CFBundleShortVersionString` **3.22.12** |
| `~/.cursor/hooks.json` | Exists. `version` 1. Event keys only: `beforeSubmitPrompt`, `stop`. Did not print command bodies or secrets. |
| `~/.cursor/hooks/` | Script basename `brainrot-state.sh` (executable). Not opened. |
| `which cursor` | **not on PATH** |
| `~/.local/bin/agent --version` | `2026.10.01-14929f9` |
| `agent acp --help` | `Start the Cursor Agent as an ACP (Agent Client Protocol) server` |
| `agent plugin --help` | `marketplace` only — no “add one hook” command |

No requested docs URL 404’d. Guessed forum id `169000` was a different thread (Codex sidebar), not used as evidence.

## 1. Official hook or event for “blocked on the user” in the already-open IDE chat?

**No.** There is no documented hook named AskQuestion, AskUserQuestion, PermissionRequest, Elicitation, Notification, UserInputRequired, or similar. Cursor’s own unknown-type error (quoted on the forum from `hooks.json` validation) lists the valid types: `beforeShellExecution`, `beforeMCPExecution`, `afterShellExecution`, `afterMCPExecution`, `beforeReadFile`, `afterFileEdit`, `beforeTabFileRead`, `afterTabFileEdit`, `stop`, `beforeSubmitPrompt`, `afterAgentResponse`, `afterAgentThought`, `sessionStart`, `sessionEnd`, `preCompact`, `subagentStart`, `subagentStop`, `preToolUse`, `postToolUse`, `postToolUseFailure`, `workspaceOpen`. That list matches the hooks reference headings.

Closest documented events, and why they are not this feature:

| Event | Matcher (docs) | Stdin extras (beyond common schema) | Can it mean “waiting on the user”? |
| --- | --- | --- | --- |
| `preToolUse` | tool type: `Shell`, `Read`, `Write`, `Grep`, `Delete`, `Task`, `MCP:<tool_name>` | `tool_name`, `tool_input`, `tool_use_id`, `cwd`, `agent_message` | Docs say it fires for **all** tools. AskQuestion is **not** a listed matcher. Staff + this Mac’s 3.22.12 probe: it does **not** fire for the native question UI. Output is `permission` allow/deny (`ask` “accepted by the schema but **not enforced** for `preToolUse` today”) plus optional `updated_input`. |
| `postToolUse` / `postToolUseFailure` | same tool-type matchers | result / `failure_type` | After a tool, not during a wait. AskQuestion does not appear here either. |
| `beforeShellExecution` / `beforeMCPExecution` | shell command text, or MCP `tool_name` | command/cwd/sandbox, or MCP name/input/server | Fires **before** the tool runs. Output `permission`: `"allow" \| "deny" \| "ask"`. That is the **hook deciding**, not an observer of the IDE’s own approval UI. Duration on the matching `after*` hook “excludes approval wait time,” which implies a wait can happen **between** before and after, but no event fires **when** the prompt is showing. Under **Run Everything**, nothing prompts. |
| `stop` | value `Stop` | `status`: `completed` \| `aborted` \| `error`; `loop_count` | **Loop ended.** Optional `followup_message` auto-submits another user turn. Not a wait. |
| `afterAgentResponse` | value `AgentResponse` | `text` (assistant final text) | Observe-only. Message completed, not “blocked.” |
| `afterAgentThought` | value `AgentThought` | `text`, `duration_ms` | Observe-only. Thinking block done. |
| `sessionEnd` | (none named) | `reason`: `completed` \| `aborted` \| `error` \| `window_close` \| `user_close` | Fire-and-forget. Conversation ended. |
| `beforeSubmitPrompt` | value `UserPromptSubmit` | `prompt`, `attachments` | User **sent** a prompt. Opposite of waiting. |
| `subagentStart` / `subagentStop` | subagent type | task / status `completed` \| `error` \| `aborted` | Subagent lifecycle, not a parent-chat question. |

**Common stdin (all Agent hooks):** `conversation_id`, `generation_id`, `model`, `model_id`, `model_params`, `hook_event_name`, `cursor_version`, `workspace_roots`, `user_email`, `transcript_path` (null if transcripts disabled). Env: `CURSOR_PROJECT_DIR`, `CURSOR_VERSION`, `CURSOR_USER_EMAIL`, `CURSOR_TRANSCRIPT_PATH`, `CURSOR_CODE_REMOTE`, plus `CLAUDE_PROJECT_DIR` alias.

**Can a hook return immediately without answering?** Yes, for events that fire. Command hooks: JSON on stdin, JSON on stdout, exit `0` uses output; exit `2` denies; other exits **fail-open** (`failClosed` default `false`). Empty / crash / timeout does not submit an AskQuestion answer because AskQuestion never calls the hook. Permission hooks (`beforeShellExecution`, `beforeMCPExecution`, `beforeReadFile`, `beforeTabFileRead`, `subagentStart`, `preToolUse`) block on **invalid** JSON even when `failClosed` is false. Observing AskQuestion by returning `{}` immediately is a no-op: the event is not delivered.

Sources: https://cursor.com/docs/hooks ; https://forum.cursor.com/t/askquestion-tool-does-not-trigger-cursor-hooks/152230 ; https://forum.cursor.com/t/cursor-cli-askquestion-tool-skips-pretooluse-and-posttooluse-hooks/161836 ; `docs/reviews/2026-09-29-native-question-compatibility.md` (this Mac, Cursor 3.22.12).

## 2. What means “turn ended” vs “waiting on the user”

**Turn / loop ended (documented):**

- `stop` — “Called when the agent loop ends.” Input `status`: `completed` | `aborted` | `error`. Matcher `Stop`. Optional `followup_message` starts another turn (capped by `loop_limit`, default 5).
- `afterAgentResponse` — “Called after the agent has completed an assistant message.” Observe-only.
- `sessionEnd` — “Called when a composer conversation ends.” Reasons above. Response ignored.
- ACP `session/prompt` result includes `stopReason` in the docs’ minimal client (`console.log(\`[stopReason=${result.stopReason}]\`)`). That is the **ACP session Agrypnos started**, not the IDE chat.
- SDK run `status`: `"running" | "finished" | "error" | "cancelled" | "expired"`. Stream type `turn-ended`. That is an **SDK-owned** run.

**Waiting on the user (what the product actually does, and what hooks see):**

- **Ask questions** (Agent overview): clarifying questions during a task. **The agent keeps working** (reads, edits, commands) until the answer arrives. Not a blocked pause. No hook.
- **Plan Mode**: “asks clarifying questions” then “You review and edit the plan” / “Click to build.” No hook for “plan awaiting Build.” Forum aside (not staff-confirmed as policy): `preToolUse`/`postToolUse` may not run in Plan mode at all.
- **Tool approval**: Run Modes are Auto-review / Allowlist / Run Everything. “Ask Every Time” was deprecated in 3.5 (May 2026). Run Everything: “Every tool call runs automatically” / “zero prompts.” Auto-review may “ask you to approve.” There is **no** hook that fires when that UI is on screen. `beforeShellExecution` fires earlier and may `allow`/`deny`/`ask`; `preToolUse`’s `ask` is **not enforced**.
- ACP (owned CLI only): blocking `cursor/ask_question` and `cursor/create_plan`; `session/request_permission` with `allow-once` / `allow-always` / `reject-once`. “If your client does not answer permission requests, tool execution can block.” That block is **the ACP client’s problem**, not a signal from the desktop chat.

Quiet (`afterFileEdit` stopping, no `stop` yet) is mid-run or mid-think. `stop` with `completed` is finished. Neither is “waiting on the user.”

Sources: https://cursor.com/docs/hooks ; https://cursor.com/docs/agent/overview ; https://cursor.com/docs/agent/plan-mode ; https://cursor.com/docs/agent/security/run-modes ; https://cursor.com/docs/cli/acp ; https://cursor.com/docs/sdk/python.

## 3. Can a second process observe a pending question without being the ACP client that owns the chat?

**No, not for the already-open IDE chat.**

ACP docs:

- Start: `agent acp`.
- Transport: **stdio**, JSON-RPC 2.0, newline-delimited JSON. Client writes stdin; Cursor CLI writes stdout.
- Flow: `initialize` → `authenticate` (`cursor_login`) → `session/new` **or** `session/load` → `session/prompt` → `session/update` → `session/request_permission`.
- Blocking extensions: `cursor/ask_question`, `cursor/create_plan`. “The agent waits for a response before continuing. **Your client** must reply with a JSON-RPC response.”
- Building an integration: “**Spawn** `agent acp` as a child process.”
- IDE integrations section: ACP is for **JetBrains, Neovim, Zed, custom editors** — “editors **beyond** the Cursor desktop app.”

`session/load` resumes “an existing conversation.” The page never says that conversation is the desktop Agent Chat already on screen. The flow always starts by spawning `agent acp`.

`cursor/ask_question` request: `toolCallId`, optional `title`, `questions[]` with `id`, `prompt`, `options[{id,label}]`, `allowMultiple`. Response: `answered` / `skipped` / `cancelled`. That RPC is how **the spawned ACP client** is asked. It is not a bus a second process can subscribe to.

Staff (Colin, 25 Sep 2026), first-party forum: under `agent acp` the model’s tool list may **never include AskQuestion**, so clients never receive `cursor/ask_question`. “We were able to trace this on our side. It comes from how ACP sessions are identified on our end.” Flagged to the team. That is a lead that even an Agrypnos-owned ACP process may not see questions. It is still not an attach API for the IDE.

SDK Bridge: spawn `cursor-sdk-bridge`, loopback HTTP, `CreateAgent` / `Send`. “The same agent that runs in the Cursor IDE” in the Python SDK means the same **product**, not attach-to-open-window. Hooks on SDK runs are still file-based `.cursor/hooks.json`. Staff (mohitjain, Jun 2026, SDK thread): clarifying questions are “filtered out of the event stream and automatically declined” in local SDK runs — “by design today.” Stream event `"request"` is documented as `SDKRequestMessage` with `request_id` only, not an AskQuestion payload.

Print/headless CLI (`agent -p`) is a different process again. Headless docs do not document a pending-question observer. A related forum thread (URL opened 2026-10-06; snapshot empty) is titled that `-p` auto-skips AskQuestion.

Sources: https://cursor.com/docs/cli/acp ; https://cursor.com/docs/sdk/bridge ; https://cursor.com/docs/sdk/python ; https://forum.cursor.com/t/agent-acp-never-offers-the-askquestion-tool-so-cursor-ask-question-is-never-sent/172976 ; https://forum.cursor.com/t/cursor-python-sdk-use/163238 (dated staff; lead, not this-build proof).

## 4. One-button install: where config lives, merge without deleting other hooks

**Config locations (official, highest → lowest priority):**

- Enterprise MDM: macOS `/Library/Application Support/Cursor/hooks.json`
- Team (Enterprise dashboard)
- Project: `<project-root>/.cursor/hooks.json` (trusted workspace; also what cloud agents load)
- User: **`~/.cursor/hooks.json`** (this Mac: present)
- Scripts for user hooks run from `~/.cursor/`

**Also:** Cursor Plugins from **Customize** / Marketplace. A plugin may ship `hooks/hooks.json` (or a `hooks` manifest field). “Install … Select **Install** and choose a project or user scope.” That is the closest official one-click path. It does **not** rewrite `~/.cursor/hooks.json` by itself.

**Merge:** “All matching hooks from every source run.” The `hooks` object maps event names to **arrays** of definitions. Replacing the whole user file deletes every other matcher group in that file. On this Mac that would drop existing `beforeSubmitPrompt` and `stop` entries. An installer that writes user hooks must **append** to the arrays (and keep `version`). There is **no** documented `agent` subcommand that inserts one hook; `agent plugin` only manages **marketplaces**. Cursor watches `hooks.json` and reloads on save.

**Third-party Claude files** (`~/.claude/settings.json`, project `.claude/`) load when “Include Third-Party Plugins, Skills, and Other Configs” is on (default). That is a separate merge layer, not an Agrypnos install button.

A plugin that only adds Agrypnos hook entries is the documented way to add hooks **without** deleting the user’s `~/.cursor/hooks.json`. That still cannot notify on AskQuestion until Cursor fires an event for it.

Sources: https://cursor.com/docs/hooks ; https://cursor.com/docs/plugins ; https://cursor.com/docs/reference/plugins ; https://cursor.com/docs/reference/third-party-hooks ; local `~/.cursor/hooks.json`; `agent plugin --help`.

## 5. What is officially impossible (for this notify)

- Observe the **already-open desktop** Agent Chat’s pending question, permission prompt, or plan “Build” wait via a supported hook, ACP attachment, or SDK subscribe.
- Treat `stop`, `afterAgentResponse`, `sessionEnd`, or “no `afterFileEdit` for N minutes” as “waiting on a question.” Official `stop` is loop end; official Ask questions **keeps working**; Agrypnos already maps quiet to idle.
- Use ACP `cursor/ask_question` as a second-process observer of the IDE. ACP is stdin of a **spawned** `agent acp`. Staff: ACP sessions may not offer AskQuestion at all.
- Name `AskQuestion` / `AskUserQuestion` as a documented `preToolUse` matcher. The matcher table does not include it. Staff: the tool is not wired to those hooks in IDE or CLI; “no workaround.”
- Register `PermissionRequest`, `Elicitation`, or `Notification` hook types. Unknown on the IDE.
- Rely on hook `permission: "ask"` as “the user is now being prompted.” For `preToolUse`, docs say `ask` is **not enforced**. Run Everything means zero prompts.
- Attach SDK Bridge / Python SDK `observe()` to the window the user already has open. Bridge/SDK create or resume **SDK** agents.
- Claim Mac-proven notify on this install. Cursor **3.22.12** still matches the 2026-09-30 probe: native question UI, no hook file until `Shell`.

**Feasible only if** Cursor ships a documented event that (a) fires on the **IDE** question/approval/plan wait, (b) includes a stable conversation id, (c) can exit 0 with empty JSON so Agrypnos only notifies, and (d) is distinct from `stop`. That event is not on the 2026-10-06 hooks page, and staff have said AskQuestion is unwired.

## What an implementer must not invent

- A Telegram/Discord ping from transcript mtime, `CURSOR_TRANSCRIPT_PATH`, session JSONL, or “no writes for N minutes,” labeled as a question or approval. That is idle.
- Window title, Dock badge, Accessibility, screenshots, or clicking the Agent Chat.
- Parsing private Cursor databases, sockets, or `~/Library/Application Support/Cursor/logs/**/cursor.hooks.*.log` as a product API.
- Spawning `agent acp` or `cursor-sdk-bridge` and calling that the user’s open IDE chat.
- Overwriting `~/.cursor/hooks.json` and deleting the user’s other events (`beforeSubmitPrompt`, `stop` on this Mac).
- Teaching `stop` / `afterAgentResponse` as “needs you.” They are completion.
- Teaching Ask questions as “agent paused.” Official copy: it **continues** working.
- Claiming a one-button notify until Cursor documents a wait event that actually fires in desktop Agent Chat.
