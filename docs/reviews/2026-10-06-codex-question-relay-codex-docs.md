# Codex native questions — official docs and source (2026-10-06)

An external local app can **answer Codex’s native structured question only as an app-server JSON-RPC client on the same already-running server that issued `item/tool/requestUserInput`**, by responding to that original request id. Hooks are **not** a question-answer contract. The default interactive `codex` CLI is **not documented** as exposing a second-client socket; `codex app-server` defaults to stdio, and launching a **new** app-server / `codex exec` / SDK agent is a **different session**. Feasible only if the user’s existing CLI or desktop process already has a listen endpoint (Unix control socket or WebSocket) that Agrypnos can join without starting a replacement Codex.

## Finding

Codex’s structured user question is the built-in `request_user_input` tool. App-server turns that into a server-initiated JSON-RPC method `item/tool/requestUserInput` (API overview also writes `tool/requestUserInput`). The client answers by sending a JSON-RPC **response** to the **same request id**, with `{ "answers": { "<questionId>": { "answers": ["…"] } } }`. Then `serverRequest/resolved` fires with `{ threadId, requestId }`. That notification also fires when the pending request is **cleared** without an answer (turn start, turn completion, or interrupt), so resolved ≠ accepted.

Lifecycle hooks can **observe, deny, or rewrite** a tool call (`PreToolUse`) or **allow/deny a shell or network approval** (`PermissionRequest`). They do **not** document a way to return the selected option into a pending native question. Empty stdout, a slow hook, or a hook crash does not submit answers; for `PreToolUse`, timeout/error/malformed output fails the hook and **the tool still runs**, so the native prompt still appears.

A second local app answering the **already-running** CLI or desktop is **not a documented default**. Official attach paths are: start `codex app-server --listen …` and connect; `codex --remote` (a **new** TUI talking to that server); experimental `codex app-server daemon` / `codex remote-control` (docs say those are **not** a substitute for `--listen` when building a protocol client); CLI source still has `codex app-server proxy` to stdio-proxy a **running control socket**. Default `codex app-server` listen is `stdio://`. Unix default path, when used, is `$CODEX_HOME/app-server-control/app-server-control.sock`. The TUI’s in-process client does not make that socket by itself.

MCP is documented and real, but it only sees questions the model **chooses to send through an Agrypnos MCP tool**, not native `request_user_input`. Official per-tool timeout is **60 seconds** (`tool_timeout_sec`). GitHub source currently defaults that constant to **300 seconds** — docs and source disagree; source is newer.

## Sources actually opened

Start URLs redirected. Final pages read:

| Requested | Final URL |
| --- | --- |
| https://developers.openai.com/codex | https://learn.chatgpt.com/docs |
| https://developers.openai.com/codex/cli | https://learn.chatgpt.com/docs/codex/cli |
| https://developers.openai.com/codex/hooks | https://learn.chatgpt.com/docs/hooks (Markdown twin: https://learn.chatgpt.com/docs/hooks.md) |
| https://developers.openai.com/codex/app-server | https://learn.chatgpt.com/docs/app-server — **still canonical**, did not 404 |
| https://developers.openai.com/codex/config-reference | https://learn.chatgpt.com/docs/config-file/config-reference |
| https://developers.openai.com/codex/mcp | https://learn.chatgpt.com/docs/extend/mcp?surface=cli |
| — | https://learn.chatgpt.com/docs/developer-commands?surface=cli |
| — | https://learn.chatgpt.com/docs/changelog |
| — | https://learn.chatgpt.com/docs/llms.txt |
| https://github.com/openai/codex | https://github.com/openai/codex (default branch HEAD `c0c230e`, 2026-10-06) |

GitHub `docs/*.md` files in the repo are short stubs that point at `developers.openai.com/codex/…` (which then redirect to Learn). Protocol truth also lives in `codex-rs/` on the same repo.

No requested URL 404’d. `CODEX_APP_SERVER_USE_LOCAL_DAEMON` (named in a 2026-09-29 Agrypnos note) is **not present** in current `openai/codex` source search.

## Re-check of the 2026-09-29 Agrypnos claims

| 2026-09-29 claim | 2026-10-06 |
| --- | --- |
| App-server JSON-RPC has `item/tool/requestUserInput` | **Still true.** Official app-server page and generated protocol (`ServerRequest.ts`, `common.rs`). Marked experimental. |
| Answer by responding to the original request id | **Still true.** App-server tests send a JSON-RPC **response** (not a new method) with the answers object. |
| `serverRequest/resolved` fires when a request is cleared | **Still true, and broader than “cleared.”** Docs: answered **or** cleared by turn start / completion / interruption. Resolved alone does not prove the answer was applied. |
| Hooks exist but are not a dedicated question-answer contract | **Still true.** Hooks are much more documented now (`PreToolUse`, `PermissionRequest`, stdin/stdout, timeouts). None of that is “return the selected option into `request_user_input`.” |
| MCP tool timeout default 60s | **True in official docs** (MCP page + config reference). **Not what GitHub source currently hard-codes:** `DEFAULT_TOOL_TIMEOUT = Duration::from_secs(300)` in `codex-rs/codex-mcp/src/rmcp_client.rs`. |

## 1. Official structured question vs approvals

**Native structured question:** the model calls the built-in function tool `request_user_input` (1–3 short questions, each with options; `isOther` adds a free-form choice). Spec in source: `REQUEST_USER_INPUT_TOOL_NAME = "request_user_input"`; “Prefer 1 and do not exceed 3”; options are 2–3 mutually exclusive choices; the client adds Other automatically (`is_other` forced true on normalize).

Surfaces:

- App-server **server request** `item/tool/requestUserInput` / overview line `tool/requestUserInput`: “prompt the user with 1-3 short questions for a tool call (experimental); questions can set `isOther` for a free-form option.” Params include `threadId`, `turnId`, `itemId`, `questions[]` (`id`, `header`, `question`, `isOther`, `isSecret`, `options[{label, description}]`), `isBlocking`, deprecated `autoResolutionMs`.
- Core v1 event `EventMsg::RequestUserInput` and op `Op::UserInputAnswer` (`codex-rs/docs/protocol_v1.md`).
- TUI bottom-pane UI for the same event (source, not a second protocol).

That is **distinct** from:

| Thing | Official method / event | What it is |
| --- | --- | --- |
| Shell / command approval | `item/commandExecution/requestApproval` | accept / acceptForSession / decline / cancel / execpolicy amendment |
| File-change approval | `item/fileChange/requestApproval` | accept / acceptForSession / decline / cancel |
| Network or filesystem grant | `item/permissions/requestApproval` | built-in `request_permissions` tool; grant a subset |
| Hook approval interceptor | `PermissionRequest` | “shell escalation or managed-network approval”; allow / deny / decline to decide |
| Plan text | `EventMsg::PlanDelta` / `update_plan` (hooks name `update_plan` as an example local function tool) | plan streaming / plan tool, not the option picker |
| MCP form / URL prompt | `mcpServer/elicitation/request` | MCP server elicitation (`form` / `openai/form` / `url`), not `request_user_input` |
| App-connector side-effect confirm | same `tool/requestUserInput` with Accept / Decline / Cancel | still that RPC, used as an approval-shaped prompt |

Sources: https://learn.chatgpt.com/docs/app-server ; https://github.com/openai/codex/blob/c0c230e6730b3b3c9101b8aff4b9aea4027cea5b/codex-rs/app-server-protocol/schema/typescript/ServerRequest.ts ; https://github.com/openai/codex/blob/c0c230e6730b3b3c9101b8aff4b9aea4027cea5b/codex-rs/core/src/tools/handlers/request_user_input_spec.rs ; https://github.com/openai/codex/blob/c0c230e6730b3b3c9101b8aff4b9aea4027cea5b/codex-rs/docs/protocol_v1.md ; https://learn.chatgpt.com/docs/hooks

## 2. Can a hook intercept and return answers in the same session?

**No dedicated contract.** A hook is the wrong tool for “Telegram picks B, Codex continues this turn with B.”

### Event names that exist

Official lifecycle events include `SessionStart`, `SessionEnd`, `SubagentStart`, `SubagentStop`, `UserPromptSubmit`, `PreToolUse`, `PermissionRequest`, `PostToolUse`, `PreCompact`, `PostCompact`, `Stop`, `Interrupt`. There is **no** `AskUser`, `RequestUserInput`, or `Question` hook event.

Closest events:

- **`PreToolUse`** — before a supported tool runs. Matcher is a regex on `tool_name`. Docs: Bash, `apply_patch` (also `Edit`/`Write`), MCP names like `mcp__filesystem__read_file`, and “other local function tools” (example: `update_plan`). Hosted tools (e.g. WebSearch) are **No/No**. “Some specialized tool paths can opt out.” The page **does not name** `request_user_input`. GitHub: `RequestUserInputHandler` is a builtin control tool, and `PreToolUse` **does** run for builtin control tools (a deny is recorded as rejected). That is observe/deny/rewrite, not “here is the user’s choice.”
- **`PermissionRequest`** — when Codex is about to ask for **approval** (shell escalation, managed-network). Matcher: `Bash`, `apply_patch`, MCP tool names. **Does not run** for commands that don’t need approval. Output is allow / deny, not option labels.
- **`PostToolUse`** — after the tool already produced output. Too late to supply the pending answer; the native wait already finished.

### Matcher

Regex string. `"*"`, `""`, or omit matcher = every occurrence of that event. `PreToolUse` / `PermissionRequest` / `PostToolUse` filter `tool_name`. There is **no documented matcher** whose job is “native question.”

### Stdin JSON (command hooks)

One JSON object on stdin. Shared fields: `session_id`, `transcript_path` (nullable; format **not** a stable interface), `cwd`, `hook_event_name`, `model`. Turn-scoped events add `turn_id`. `PreToolUse` also has `tool_name`, `tool_use_id`, `tool_input` (JSON; MCP and other local function tools send their arguments).

### Stdout JSON

- Exit 0 with **no output** = success, Codex continues (common rule). For `PreToolUse` / `PermissionRequest`, **plain text on stdout is ignored**.
- `PreToolUse` JSON can `permissionDecision: "deny"` (or legacy `decision: "block"`), or `permissionDecision: "allow"` plus `updatedInput` to **rewrite arguments**, or `additionalContext`. `permissionDecision: "ask"`, `continue: false`, `stopReason`, `suppressOutput` are parsed but **unsupported**; Codex **marks the hook failed, reports the error, and continues the tool call**.
- `PermissionRequest` JSON is `hookSpecificOutput.decision.behavior` `"allow"` or `"deny"`. Docs: **don’t** return `updatedInput` / `updatedPermissions` / `interrupt` (fail closed). Any deny wins; else allow skips the prompt; if nobody decides, normal approval UI.
- There is **no** `answers` map, no `hookSpecificOutput` field documented as “submit the selected option.”

### Timeout

`timeout` is **seconds**. If omitted: **600 seconds** for most hooks. `SessionEnd` and `Interrupt`: default **1s**, max **3s**. Background (`async: true`) hooks use the same timeout default (600) and **cannot** block, approve, rewrite, or control the triggering operation.

### Empty stdout / slow hook / crash

Official:

- Empty / exit 0: continue.
- Managed/cloud note: “a `PreToolUse` callback **error, timeout, or malformed response** can fail the hook **without blocking the tool**.”
- Matching command hooks for the same event **run concurrently**; one hook cannot prevent another from starting.
- `SessionEnd`: timeout or nonzero exit is reported as a hook failure; output does not steer Codex.
- Unfinished **background** hooks are cancelled when the session ends; their output is discarded.

So a hook that waits on Telegram: at best it **delays** `PreToolUse` up to 600s, then the native `request_user_input` UI still runs unless the hook **denied** the tool (which is not “answer B”). After deny, the model sees a blocked tool, not a chosen option.

Sources: https://learn.chatgpt.com/docs/hooks ; https://github.com/openai/codex/blob/c0c230e6730b3b3c9101b8aff4b9aea4027cea5b/codex-rs/core/src/tools/registry.rs ; https://github.com/openai/codex/blob/c0c230e6730b3b3c9101b8aff4b9aea4027cea5b/codex-rs/core/src/tools/handlers/request_user_input.rs

## 3. App-server JSON-RPC path (this is the actual answer path)

### Transport

Official “Supported transports” (https://learn.chatgpt.com/docs/app-server):

- **stdio** (`--listen stdio://`, **default**): newline-delimited JSON (JSONL).
- **websocket** (`--listen ws://IP:PORT`): **experimental and unsupported**; one JSON-RPC message per text frame.
- **Unix socket** (`--listen unix://` or `unix://PATH`): WebSocket over the **default app-server control socket** or a custom path (HTTP Upgrade).
- **off** (`--listen off`): no local transport.

JSON-RPC 2.0, `"jsonrpc":"2.0"` header **omitted** on the wire. Handshake: `initialize` then `initialized`. Requests before that: not initialized.

Default Unix path in source: `$CODEX_HOME/app-server-control/app-server-control.sock` (`APP_SERVER_CONTROL_SOCKET_DIR_NAME` / `FILE_NAME`).

`codex --remote` accepts `ws://`, `wss://`, `unix://`, `unix://PATH` and connects the **terminal UI** to that endpoint. That is a TUI client, not “inject into whatever `codex` is already painted on screen,” unless that painted UI is already that remote client.

In-process TUI/exec (source `codex-rs/app-server-client/README.md`): typed channels inside the process. JSON exists at **external** stdio/websocket boundaries. Default interactive CLI is this in-process path.

### Methods and schemas

**Server → client request** (must reply with the same `id`):

```
method: "item/tool/requestUserInput"
params: {
  threadId, turnId, itemId,
  questions: [{ id, header, question, isOther, isSecret, options: [{ label, description }] | null }],
  isBlocking,
  autoResolutionMs: number | null   // deprecated; use isBlocking
}
```

**Client → server response** (same `id`, not a new method):

```
{ "id": <original>, "result": { "answers": { "<questionId>": { "answers": ["…"] } } } }
```

App-server test (`codex-rs/app-server/tests/suite/v2/request_user_input.rs`) does exactly that, then waits for `serverRequest/resolved` then `turn/completed`.

On client error or disconnect, source submits `Op::UserInputAnswer` with an **empty** answers map (not a documented “timeout UI”).

**Notification:** `serverRequest/resolved` with `{ threadId, requestId }` after answer **or** cleanup.

`codex app-server generate-ts` / `generate-json-schema` emit schemas **for that installed CLI version**.

The method is tagged **EXPERIMENTAL** in protocol source (`/// EXPERIMENTAL - Request input from the user for a tool call.`). Official page: opt in with `initialize.params.capabilities.experimentalApi = true` for experimental methods/fields; otherwise the server rejects with ``<descriptor> requires experimentalApi capability``. Treat `item/tool/requestUserInput` as experimental until a given CLI’s generated schema says otherwise.

### Can a second client attach to an already-running `codex` CLI or desktop?

**Not as the documented default.**

What the docs **do** say:

1. Start **`codex app-server`** (stdio / `ws://…` / `unix://`) and connect a client. That is **starting a server**, then building a product on it. The page is explicitly for “deep integration inside your own product.” Automating jobs / CI: use the **Codex SDK** instead — another process, not the user’s open chat.
2. **`codex --remote <endpoint>`**: run a TUI against an app-server **you already started with a listen URL**. Supported for `codex`, `resume`, `fork`, `archive`, `delete`, `unarchive`. Other subcommands reject remote mode.
3. **`codex app-server` command maturity: Experimental.** “Launch the Codex app server for local development or debugging over stdio, WebSocket, or a Unix socket.” (`developer-commands`, CLI surface.) Interactive `codex` TUI is **Stable**.
4. **`codex remote-control` / app-server daemon: Experimental.** Docs: managed remote-control clients and SSH workflows; “**they aren’t a replacement for `codex app-server --listen` when you’re building a local protocol client.**”
5. CLI **source** (not the developer-commands table): `codex app-server proxy` — “Proxy stdio bytes to the running app-server control socket,” optional `--sock SOCKET_PATH`, defaulting to the control socket under `CODEX_HOME`. **Only works if that socket already exists.**

What the docs **do not** say:

- That a stock `codex` TUI (stable, in-process) opens `app-server-control.sock` for a neighbor process.
- That two JSON-RPC clients both receive the same pending `item/tool/requestUserInput` and that the first response wins.
- That `thread/read` or `thread/resume` on a **new** app-server owns the original pending request. `thread/read` is “read a stored thread without resuming it.” Resume on another server is another conversation handle.

`thread/unsubscribe`: if this was the **last subscriber**, the server unloads the thread after a grace period. That implies multiple subscribers **can** exist **on one app-server**. It does not grant Agrypnos a seat on a TUI that never listened.

**Launching a new `codex app-server` does not count** for “same already-running session.”

Sources: https://learn.chatgpt.com/docs/app-server ; https://learn.chatgpt.com/docs/developer-commands?surface=cli ; https://github.com/openai/codex/blob/c0c230e6730b3b3c9101b8aff4b9aea4027cea5b/codex-rs/app-server-client/README.md ; https://github.com/openai/codex/blob/c0c230e6730b3b3c9101b8aff4b9aea4027cea5b/codex-rs/app-server-daemon/README.md ; https://github.com/openai/codex/blob/c0c230e6730b3b3c9101b8aff4b9aea4027cea5b/codex-rs/cli/src/main.rs (Proxy + `--sock`) ; https://github.com/openai/codex/blob/c0c230e6730b3b3c9101b8aff4b9aea4027cea5b/codex-rs/app-server/tests/suite/v2/request_user_input.rs

## 4. Hook config location and merge

Official discovery (https://learn.chatgpt.com/docs/hooks):

- `hooks.json` **or** inline `[hooks]` tables in `config.toml`, next to active config layers.
- Useful locations: `~/.codex/hooks.json`, `~/.codex/config.toml`, `<repo>/.codex/hooks.json`, `<repo>/.codex/config.toml`.
- User-level config: `~/.codex/config.toml`. Project: `.codex/config.toml` **only when the project is trusted**. Project-local **hooks** also load only when the project `.codex/` layer is trusted; untrusted projects still load user/system hooks.
- If more than one hook **source** exists, Codex **loads all matching hooks**. Higher-precedence layers **do not replace** lower-precedence hooks.
- If **one layer** has both `hooks.json` and inline `[hooks]`, Codex **merges them and warns at startup**. Prefer one representation per layer.
- Non-managed hooks must be **reviewed and trusted** (`/hooks` in the CLI). Changed definitions are skipped until trusted. `--dangerously-bypass-hook-trust` is for already-vetted automation.
- Plugins can bundle `hooks/hooks.json`; enabling a plugin does **not** auto-trust those hooks.
- `allow_managed_hooks_only = true` is **requirements.toml only**; in `config.toml` it does not turn on managed-hooks-only mode (repo `docs/config.md` stub + hooks page).

**Installer merge without deleting other settings:** putting **only** Agrypnos entries in **`~/.codex/hooks.json`** is the documented additive file. It does not wipe unrelated `config.toml` keys (model, MCP servers, etc.). If the user already has `~/.codex/hooks.json`, an installer must **merge JSON** (append a matcher group; do not replace the whole `hooks` object). User `config.toml` `[hooks]` in the same layer still **loads alongside** `hooks.json` (with a startup warning). Replacing entire `config.toml` would delete other keys — the docs never ask you to do that.

App-server `config/value/write` / `config/batchWrite` write the **user** `config.toml`. They are not documented as a safe “insert one hook, preserve everything else” helper. Prefer the `hooks.json` file.

Shape (official example): event name → array of matcher groups → `hooks` array of `{ type: "command"|"mcp_tool", command|server+tool, timeout?, statusMessage?, async? }`. `command` and `mcp_tool` run; `prompt` and `agent` are parsed but skipped.

## 5. Timeouts: human vs hook vs MCP

| Wait | Official number | If late |
| --- | --- | --- |
| Most command / MCP-tool **hooks** | **600s** default | Hook fails; for `PreToolUse`, the **tool still runs** (native UI still asks). |
| `SessionEnd` / `Interrupt` hooks | **1s** default, **3s** max | Failure reported; cannot prevent interrupt / keep the session. |
| Native `request_user_input` human wait | **No Codex-enforced deadline in current tool source.** `auto_resolution_ms` is always `None` in `RequestUserInputHandler`. Schema still has `autoResolutionMs`. Docs: “When present, **host clients can** resolve the prompt automatically after that interval if the user doesn’t answer.” TUI source has an auto-resolution countdown snapshot **when the field is set**. | If the field is null, official docs do **not** say Codex cancels the turn. The host (TUI/desktop) shows the picker until the user answers, the turn is interrupted, or the client errors (empty answers submitted). |
| `isBlocking` | Plan mode: **true**; default mode with `features.default_mode_request_user_input`: **false** (app-server tests). Wire default if omitted: **true**. | Non-blocking means the request should not hold the turn the way Plan mode does; it is **not** “Agrypnos may answer later after the turn moved on.” |
| MCP **server** tool call | Docs: **`tool_timeout_sec` default 60**. `startup_timeout_sec` default **10**. | Tool call fails when that timer fires. Elicitation wait **does not** count against an MCP **hook** timeout (hooks page). |

A late Agrypnos answer on the **JSON-RPC** path: if the pending request was already cleared, `serverRequest/resolved` already fired for cleanup; a late response is not documented as resurrecting the question. If the host auto-resolved because `autoResolutionMs` was set, the native UI may already have picked. Current native tool does not set that field.

Sources: https://learn.chatgpt.com/docs/hooks ; https://learn.chatgpt.com/docs/app-server ; https://learn.chatgpt.com/docs/extend/mcp?surface=cli ; https://learn.chatgpt.com/docs/config-file/config-reference ; https://github.com/openai/codex/blob/c0c230e6730b3b3c9101b8aff4b9aea4027cea5b/codex-rs/core/src/tools/handlers/request_user_input.rs

## 6. MCP-tool alternative

Documented: add a server under `mcp_servers.<id>` (stdio or HTTP), tools become model-visible. The model **may** call them. That is **not** native `request_user_input`. Agrypnos would only see questions the model **chooses** to send through that tool.

Official timeout: **`tool_timeout_sec` default 60 seconds** (MCP guide and config reference, 2026-10-06). GitHub `DEFAULT_TOOL_TIMEOUT` is **300 seconds** as of HEAD `c0c230e` — **docs are not the source of truth for the binary you actually run; generate or read that CLI.**

MCP **hooks** (`type: "mcp_tool"`) call an **already-connected** server on a lifecycle event. They do not start servers, do not request tool approval, do not trigger other hooks. Errors / missing server **do not** block. That is still not native Q&A.

MCP **elicitation** (`mcpServer/elicitation/request`) is a different server-initiated RPC for MCP-driven forms/URLs.

Sources: https://learn.chatgpt.com/docs/extend/mcp?surface=cli ; https://learn.chatgpt.com/docs/config-file/config-reference ; https://github.com/openai/codex/blob/c0c230e6730b3b3c9101b8aff4b9aea4027cea5b/codex-rs/codex-mcp/src/rmcp_client.rs

## 7. Officially the wrong tool

- **`codex exec` / `codex e`:** stable **non-interactive** runner. New process. Alias and JSONL streaming. Repo stub: https://developers.openai.com/codex/noninteractive. Not the open TUI/desktop chat.
- **`codex resume` on another app-server / SDK agent:** another handle. Stored history ≠ pending RPC ownership.
- **Codex SDK:** official alternative when you want to “programmatically control local Codex agents” / CI — not the user’s already-running CLI. https://learn.chatgpt.com/docs/codex-sdk.md (indexed from llms.txt).
- **Starting `codex app-server` yourself** while the user already has a TUI: a second server. Does not own the pending request.
- **`PermissionRequest` / command / file / `request_permissions` approvals** used as if they were option pickers.
- **`PreToolUse` `updatedInput`** as if it were “answers.” It rewrites **tool arguments** (the questions), and only with `permissionDecision: "allow"`.
- **Background hooks (`async: true`)** as a wait-for-Telegram path.
- **Discord/OpenAI Interactions-style public HTTPS callbacks** as Codex inbound. Codex inbound here is local JSON-RPC / stdio / Unix / optional experimental WebSocket. App-server WebSocket auth is local bearer/capability-token, not a public Interactions URL.
- **`CODEX_APP_SERVER_USE_LOCAL_DAEMON`:** not in current source. Do not treat a 2026-09 GitHub issue flag as a supported attach API.
- **Remote-control daemon** as the supported way to build a local protocol client — docs say it is not.

## 8. Version / date; docs vs GitHub

**Docs read 2026-10-06** on learn.chatgpt.com (ChatGPT Learn). Changelog install line on that day: `$ npm install -g @openai/codex@0.160.1` (https://learn.chatgpt.com/docs/changelog). GitHub stable tag `rust-v0.160.1` published 2026-10-05; later alphas exist (`0.161.0-alpha.13.1` on 2026-10-06). Repo HEAD inspected: `c0c230e6730b3b3c9101b8aff4b9aea4027cea5b` (2026-10-06).

Schemas: “Each output is specific to the Codex version you ran.” Do not freeze this note’s TypeScript as forever-wire.

**Disagreements (quote both; GitHub HEAD is newer than the 60s doc line):**

1. **MCP `tool_timeout_sec` default**  
   - Docs (MCP + config-reference): “Override the default **60s** per-tool timeout.”  
   - Source: `pub(crate) const DEFAULT_TOOL_TIMEOUT: Duration = Duration::from_secs(300);`

2. **`autoResolutionMs`**  
   - Docs: request params include it; host **can** auto-resolve when present.  
   - Native tool source: `auto_resolution_ms: None` always. Field is deprecated in schema comments in favor of `isBlocking`.

3. **Default TUI attach**  
   - Docs describe listen URLs and `--remote` for a server you start.  
   - Source: TUI/exec use **in-process** app-server; Unix acceptor starts only for `AppServerTransport::UnixSocket`.

4. **`codex app-server proxy`**  
   - Present in CLI source as of HEAD.  
   - Not listed as its own row in the developer-commands command table (page names `codex app-server`, daemon/remote-control, debug send-message-v2).

5. **Hooks vs `request_user_input` by name**  
   - Docs: “other local function tools” + “specialized paths can opt out”; no `request_user_input` matcher example.  
   - Source: handler is a builtin control tool and still goes through `PreToolUse` for deny/rewrite.

Where they disagree on numbers or attach, **believe the binary’s generated schema and that version’s source**, not this note’s copy of Learn.

## What an implementer must not invent

- A Codex hook event that **returns the selected option** the way Claude `AskUserQuestion` documents `updatedInput.answers`.
- That **`PermissionRequest`** is the structured question.
- That **`serverRequest/resolved`** means Agrypnos’s answer was applied.
- That **`autoResolutionMs` is always 60s / 600s / anything** — current native tool sends `null`.
- That **MCP 60s** is what every installed CLI uses (source may be 300s).
- That default **`codex` TUI** has a public Unix socket Agrypnos can join.
- That **`codex app-server proxy`** works when the control socket file is absent.
- That **`codex exec`**, a new **`codex app-server`**, **SDK**, or **`thread/resume` on another server** is the original session.
- That **`CODEX_APP_SERVER_USE_LOCAL_DAEMON`** is a current supported flag.
- That **remote-control / daemon** is the documented local protocol-client attach (docs say use `--listen`).
- A **public Interactions URL**, listen port on the internet, or Discord-style callback as Codex inbound.
- Watt numbers, competitor names, or “we know the agent is still thinking.”
- Plan-approval, file approval, or shell approval as the option picker.
- Rewriting `config.toml` wholesale, or deleting the user’s other hook matcher groups, to “install one hook.”
- Skipping hook **trust review** in interactive sessions (`/hooks`) unless the user is in an already-vetted `--dangerously-bypass-hook-trust` automation.
- Treating experimental WebSocket app-server as production transport.
- An empty-answers JSON-RPC error path as a successful user choice.
)
